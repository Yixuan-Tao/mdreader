import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingPicker = false
    @State private var showingSettings = false
    @State private var didHandleStartup = false

    private let startupResumeWindow: TimeInterval = 30 * 60

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactContent
            } else {
                splitContent
            }
        }
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { url in
                showingPicker = false
                store.open(url: url)
            } onCancel: {
                showingPicker = false
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Document Error", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert("Remove Recent File?", isPresented: Binding(
            get: { store.unavailableRecentDocument != nil },
            set: { if !$0 { store.unavailableRecentDocument = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let document = store.unavailableRecentDocument {
                    store.removeRecentDocument(document)
                }
            }
            Button("Keep", role: .cancel) {
                store.unavailableRecentDocument = nil
            }
        } message: {
            Text("\(store.unavailableRecentDocument?.fileName ?? "This file") could not be opened. You can remove it from Recent.")
        }
        .task {
            handleStartupIfNeeded()
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .background || newValue == .inactive {
                store.markAppActive()
            }
        }
    }

    private func handleStartupIfNeeded() {
        guard !didHandleStartup else { return }
        didHandleStartup = true

        if let sampleArgument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--sample=") }) {
            store.openSample(id: String(sampleArgument.dropFirst("--sample=".count)))
        } else {
            store.restoreMostRecentDocumentIfRecentlyActive(maxIdleInterval: startupResumeWindow)
        }

        store.markAppActive()
    }

    @ViewBuilder
    private var compactContent: some View {
        if let document = store.currentDocument {
            NavigationStack {
                EditorView(document: document)
                    .id(document.id)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                store.currentDocument = nil
                            } label: {
                                Label("Documents", systemImage: "chevron.left")
                            }
                        }
                    }
            }
        } else {
            NavigationStack {
                documentList
            }
        }
    }

    private var splitContent: some View {
        NavigationSplitView {
            documentList
        } detail: {
            if let document = store.currentDocument {
                EditorView(document: document)
                    .id(document.id)
            } else {
                ContentUnavailableView(
                    "No Document Open",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Open a Markdown, HTML, or text file from Files.")
                )
            }
        }
    }

    private var documentList: some View {
        List {
            Section {
                Button {
                    showingPicker = true
                } label: {
                    Label("Open Markdown, HTML, or Text", systemImage: "folder")
                }
                .buttonStyle(.borderless)

                Menu {
                    Button {
                        store.createNewDocument(kind: .markdown)
                    } label: {
                        Label("Markdown", systemImage: "doc.badge.plus")
                    }

                    Button {
                        store.createNewDocument(kind: .html)
                    } label: {
                        Label("HTML", systemImage: "chevron.left.forwardslash.chevron.right")
                    }

                    Button {
                        store.createNewDocument(kind: .text)
                    } label: {
                        Label("Text", systemImage: "doc.text")
                    }
                } label: {
                    Label("New Document", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }

            if !store.recentDocuments.isEmpty {
                Section("Recent") {
                    ForEach(store.recentDocuments) { document in
                        Button {
                            store.reopen(document)
                        } label: {
                            RecentDocumentRow(document: document)
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button(role: .destructive) {
                                store.removeRecentDocument(document)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                store.removeRecentDocument(document)
                            } label: {
                                Label("Remove from Recent", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("mdreader")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }
}

private struct RecentDocumentRow: View {
    let document: RecentDocument

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .frame(width: 28, height: 28)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 3) {
                Text(document.fileName)
                    .lineLimit(1)

                Text(document.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(document.lastOpenedDescription)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch document.kind {
        case .markdown:
            return "doc.plaintext"
        case .html:
            return "curlybraces"
        case .text:
            return "doc.text"
        }
    }
}
