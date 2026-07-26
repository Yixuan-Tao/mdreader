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
    @State private var isSearchVisible = false
    @State private var searchQuery = ""
    @State private var isTableOfContentsVisible = false
    @State private var targetAnchor: String?
    @State private var regularDisplayMode = RegularEditorDisplayMode.split

    let document: EditableDocument
    var onFocusModeChanged: ((Bool) -> Void)?

    init(document: EditableDocument, onFocusModeChanged: ((Bool) -> Void)? = nil) {
        self.document = document
        self.onFocusModeChanged = onFocusModeChanged
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactEditor
            } else {
                regularEditor
            }
        }
        .navigationTitle(horizontalSizeClass == .compact ? document.fileName : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if horizontalSizeClass == .compact {
                ToolbarItem(placement: .principal) {
                    saveStatusLabel
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    saveStatusLabel
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Export HTML", action: exportHTML)
                        .keyboardShortcut("e", modifiers: [.command, .shift])
                    Button("Export PDF", action: exportPDF)
                        .keyboardShortcut("p", modifiers: [.command])
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }

            if isCurrentDocumentReadOnly {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.setCurrentDocumentReadOnly(false)
                    } label: {
                        Label("Unlock Editing", systemImage: "lock.open")
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSearchVisible.toggle()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: [.command])
            }

            if document.kind == .markdown {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isTableOfContentsVisible = true
                    } label: {
                        Label("Table of Contents", systemImage: "list.bullet.indent")
                    }
                }
            }

            if horizontalSizeClass != .compact {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(RegularEditorDisplayMode.allCases) { mode in
                            Button {
                                regularDisplayMode = mode
                                onFocusModeChanged?(mode.isFocused)
                            } label: {
                                Label(mode.title, systemImage: mode.systemImage)
                            }
                        }
                    } label: {
                        Label(regularDisplayMode.title, systemImage: regularDisplayMode.systemImage)
                    }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                }
            }
        }
        .onAppear {
            previewText = document.text
            applyDefaultModeIfNeeded()
            if horizontalSizeClass != .compact {
                onFocusModeChanged?(regularDisplayMode.isFocused)
            }
        }
        .onDisappear {
            onFocusModeChanged?(false)
        }
        .onChange(of: document.text) { _, newValue in
            schedulePreviewRefresh(newValue)
        }
        .onChange(of: horizontalSizeClass) { _, newValue in
            if newValue == .compact {
                onFocusModeChanged?(false)
            } else {
                onFocusModeChanged?(regularDisplayMode.isFocused)
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(isPresented: $isTableOfContentsVisible) {
            NavigationStack {
                TableOfContentsView(headings: markdownHeadings) { heading in
                    targetAnchor = heading.anchor
                    showPreview()
                    isTableOfContentsVisible = false
                }
            }
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

    private var saveStatusLabel: some View {
        Text(store.saveState.label)
            .font(.caption)
            .foregroundStyle(statusColor)
            .lineLimit(1)
            .fixedSize()
    }

    private var compactEditor: some View {
        VStack(spacing: 0) {
            searchBar

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
        VStack(spacing: 0) {
            documentHeader

            searchBar

            switch regularDisplayMode {
            case .split:
                HStack(spacing: 0) {
                    sourceEditor
                        .frame(maxWidth: .infinity)

                    Divider()

                    preview
                        .frame(maxWidth: .infinity)
                }
            case .editOnly:
                sourceEditor
                    .frame(maxWidth: .infinity)
            case .previewOnly:
                preview
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var documentHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: document.kind.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(document.fileName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(document.fileName)
    }

    private var sourceEditor: some View {
        ZStack(alignment: .topTrailing) {
            TextEditor(text: Binding(
                get: { store.currentDocument?.text ?? document.text },
                set: { store.updateText($0) }
            ))
            .font(.system(size: settingsStore.settings.editorFontSize, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .disabled(isCurrentDocumentReadOnly)

            if isSearchActive {
                Text("\(searchMatchCount) matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    .padding(12)
            }

            if isCurrentDocumentReadOnly {
                VStack(spacing: 8) {
                    Label("Read Only", systemImage: "lock")
                        .font(.caption.weight(.semibold))

                    Text("Unlock editing before changing this external file.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        store.setCurrentDocumentReadOnly(false)
                    } label: {
                        Label("Unlock Editing", systemImage: "lock.open")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        if isSearchVisible {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Find in document", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if isSearchActive {
                    Text("\(searchMatchCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Button {
                    searchQuery = ""
                    isSearchVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))

            Divider()
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch document.kind {
        case .markdown:
            MarkdownPreview(
                markdown: previewText,
                fontSize: settingsStore.settings.previewFontSize,
                baseURL: document.url.deletingLastPathComponent(),
                searchQuery: searchQuery,
                targetAnchor: targetAnchor,
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

    private var currentText: String {
        store.currentDocument?.text ?? document.text
    }

    private var markdownHeadings: [MarkdownHeading] {
        guard document.kind == .markdown else { return [] }
        return MarkdownHTMLRenderer.tableOfContents(from: currentText)
    }

    private var isSearchActive: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private var searchMatchCount: Int {
        guard isSearchActive else { return 0 }
        return MarkdownHTMLRenderer.searchMatchCount(in: currentText, query: searchQuery)
    }

    private var isCurrentDocumentReadOnly: Bool {
        store.currentDocument?.isReadOnly ?? document.isReadOnly
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

    private func showPreview() {
        if horizontalSizeClass == .compact {
            selectedMode = .preview
        } else if regularDisplayMode == .editOnly {
            regularDisplayMode = .previewOnly
            onFocusModeChanged?(true)
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

private struct TableOfContentsView: View {
    let headings: [MarkdownHeading]
    let onSelect: (MarkdownHeading) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if headings.isEmpty {
                ContentUnavailableView(
                    "No Headings",
                    systemImage: "list.bullet.indent",
                    description: Text("Add Markdown headings with #, ##, or ###.")
                )
            } else {
                ForEach(headings) { heading in
                    Button {
                        onSelect(heading)
                    } label: {
                        HStack(spacing: 10) {
                            Text(String(repeating: " ", count: max(0, heading.level - 1) * 2))
                                .monospaced()

                            Text(heading.title)
                                .lineLimit(2)

                            Spacer()

                            Text("H\(heading.level)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Contents")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
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

private enum RegularEditorDisplayMode: String, CaseIterable, Identifiable {
    case split
    case editOnly
    case previewOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .split: "Split"
        case .editOnly: "Edit Only"
        case .previewOnly: "Preview Only"
        }
    }

    var systemImage: String {
        switch self {
        case .split: "rectangle.split.2x1"
        case .editOnly: "pencil"
        case .previewOnly: "doc.richtext"
        }
    }

    var isFocused: Bool {
        switch self {
        case .split: false
        case .editOnly, .previewOnly: true
        }
    }
}
