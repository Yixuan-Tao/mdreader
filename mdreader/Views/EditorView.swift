import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var settingsStore: SettingsStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedMode = EditorMode.edit
    @State private var didApplyDefaultMode = false
    @State private var previewText = ""
    @State private var previewTask: Task<Void, Never>?
    @State private var shareItem: ShareItem?
    @State private var pendingExternalURL: URL?

    let document: EditableDocument

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactEditor
            } else {
                regularEditor
            }
        }
        .navigationTitle(document.fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(store.saveState.label)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Export HTML", action: exportHTML)
                    Button("Export PDF", action: exportPDF)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
        .onAppear {
            previewText = document.text
            applyDefaultModeIfNeeded()
        }
        .onChange(of: document.text) { _, newValue in
            schedulePreviewRefresh(newValue)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Open in Browser?", isPresented: Binding(
            get: { pendingExternalURL != nil },
            set: { if !$0 { pendingExternalURL = nil } }
        )) {
            Button("Open") {
                if let url = pendingExternalURL {
                    UIApplication.shared.open(url)
                }
                pendingExternalURL = nil
            }
            Button("Cancel", role: .cancel) {
                pendingExternalURL = nil
            }
        } message: {
            Text(pendingExternalURL?.absoluteString ?? "")
        }
    }

    private var compactEditor: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $selectedMode) {
                ForEach(EditorMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            Divider()

            if selectedMode == .edit {
                sourceEditor
            } else {
                preview
            }
        }
    }

    private var regularEditor: some View {
        HStack(spacing: 0) {
            sourceEditor
                .frame(maxWidth: .infinity)

            Divider()

            preview
                .frame(maxWidth: .infinity)
        }
    }

    private var sourceEditor: some View {
        TextEditor(text: Binding(
            get: { store.currentDocument?.text ?? document.text },
            set: { store.updateText($0) }
        ))
        .font(.system(size: settingsStore.settings.editorFontSize, design: .monospaced))
        .scrollContentBackground(.hidden)
        .padding(12)
        .background(Color(.secondarySystemBackground))
    }

    @ViewBuilder
    private var preview: some View {
        switch document.kind {
        case .markdown:
            MarkdownPreview(
                markdown: previewText,
                fontSize: settingsStore.settings.previewFontSize,
                baseURL: document.url.deletingLastPathComponent(),
                onExternalLinkTapped: { url in
                    pendingExternalURL = url
                }
            )
        case .html:
            HTMLPreview(
                html: previewText,
                baseURL: document.url.deletingLastPathComponent(),
                onExternalLinkTapped: { url in
                    pendingExternalURL = url
                }
            )
        case .text:
            PlainTextPreview(
                text: previewText,
                fontSize: settingsStore.settings.previewFontSize
            )
        }
    }

    private var statusColor: Color {
        if case .failed = store.saveState {
            return .red
        }

        if case .saved = store.saveState {
            return .green
        }

        return .secondary
    }

    private func schedulePreviewRefresh(_ text: String) {
        previewTask?.cancel()
        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                previewText = text
            }
        }
    }

    private func applyDefaultModeIfNeeded() {
        guard !didApplyDefaultMode else { return }
        didApplyDefaultMode = true

        switch settingsStore.settings.defaultEditorMode {
        case .edit:
            selectedMode = .edit
        case .preview:
            selectedMode = .preview
        }
    }

    private func exportHTML() {
        guard let document = store.currentDocument else { return }

        do {
            shareItem = ShareItem(url: try ExportService.htmlExportURL(for: document))
        } catch {
            store.errorMessage = "Could not export HTML: \(error.localizedDescription)"
        }
    }

    private func exportPDF() {
        guard let document = store.currentDocument else { return }

        do {
            shareItem = ShareItem(url: try ExportService.pdfExportURL(for: document))
        } catch {
            store.errorMessage = "Could not export PDF: \(error.localizedDescription)"
        }
    }
}

private struct ShareItem: Identifiable {
    let url: URL

    var id: URL { url }
}

private enum EditorMode: String, CaseIterable, Identifiable {
    case edit
    case preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit: "Edit"
        case .preview: "Preview"
        }
    }

    var systemImage: String {
        switch self {
        case .edit: "pencil"
        case .preview: "doc.richtext"
        }
    }
}
