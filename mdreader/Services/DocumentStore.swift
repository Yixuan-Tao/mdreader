import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class DocumentStore: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case pending
        case saving
        case saved(Date)
        case failed(String)

        var label: String {
            switch self {
            case .idle:
                return "Ready"
            case .pending:
                return "Waiting"
            case .saving:
                return "Saving..."
            case .saved:
                return "Saved"
            case .failed:
                return "Save failed"
            }
        }
    }

    @Published var currentDocument: EditableDocument?
    @Published var recentDocuments: [RecentDocument] = []
    @Published var saveState: SaveState = .idle
    @Published var errorMessage: String?
    @Published var unavailableRecentDocument: RecentDocument?

    private let recentDocumentsKey = "recentDocuments"
    private let lastActiveAtKey = "lastActiveAt"
    private let userDefaults: UserDefaults
    private var saveTask: Task<Void, Never>?
    private var activeSecurityURL: URL?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadRecentDocuments()
    }

    deinit {
        activeSecurityURL?.stopAccessingSecurityScopedResource()
        saveTask?.cancel()
    }

    func open(url: URL) {
        saveTask?.cancel()
        activeSecurityURL?.stopAccessingSecurityScopedResource()
        activeSecurityURL = nil

        guard let kind = DocumentKind.kind(for: url) else {
            errorMessage = "Unsupported file type. Choose .md, .markdown, .html, .htm, or .txt."
            return
        }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        if didStartAccessing {
            activeSecurityURL = url
        }

        do {
            currentDocument = try loadDocument(url: url, kind: kind)
            saveState = .saved(.now)
            remember(url: url, kind: kind)
        } catch {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
                activeSecurityURL = nil
            }
            errorMessage = "Could not open \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }

    func reopen(_ recentDocument: RecentDocument, showsUnavailableAlert: Bool = true) {
        var isStale = false

        do {
            let url = try URL(
                resolvingBookmarkData: recentDocument.bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard let kind = DocumentKind.kind(for: url) else {
                throw CocoaError(.fileReadUnsupportedScheme)
            }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            if didStartAccessing {
                activeSecurityURL?.stopAccessingSecurityScopedResource()
                activeSecurityURL = url
            }

            currentDocument = try loadDocument(url: url, kind: kind)
            saveState = .saved(.now)
            remember(url: url, kind: kind)
        } catch {
            if showsUnavailableAlert {
                unavailableRecentDocument = recentDocument
            }
        }
    }

    func createNewDocument(kind: DocumentKind) {
        do {
            let directory = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let url = try NewDocumentService.createDocument(kind: kind, in: directory)
            open(url: url)
        } catch {
            errorMessage = "Could not create \(kind.displayName) document: \(error.localizedDescription)"
        }
    }

    func removeRecentDocument(_ recentDocument: RecentDocument) {
        recentDocuments.removeAll { $0.id == recentDocument.id }
        persistRecentDocuments()

        if unavailableRecentDocument?.id == recentDocument.id {
            unavailableRecentDocument = nil
        }
    }

    func openSample(_ sample: SampleDocumentService.Sample) {
        do {
            let url = try SampleDocumentService.sampleURL(for: sample)
            open(url: url)
        } catch {
            errorMessage = "Could not open \(sample.title): \(error.localizedDescription)"
        }
    }

    func openSample(id: String) {
        guard let sample = SampleDocumentService.sample(with: id) else {
            errorMessage = "Sample document not found."
            return
        }

        openSample(sample)
    }

    func restoreMostRecentDocumentIfRecentlyActive(maxIdleInterval: TimeInterval) {
        guard currentDocument == nil else { return }
        guard let lastActiveAt = userDefaults.object(forKey: lastActiveAtKey) as? Date else { return }
        guard Date().timeIntervalSince(lastActiveAt) <= maxIdleInterval else { return }
        guard let recentDocument = recentDocuments.first else { return }

        reopen(recentDocument, showsUnavailableAlert: false)
    }

    func markAppActive() {
        userDefaults.set(Date(), forKey: lastActiveAtKey)
    }

    func updateText(_ text: String) {
        guard var document = currentDocument else { return }
        document.text = text
        document.isModified = true
        currentDocument = document
        scheduleAutosave()
    }

    func saveImmediately() {
        saveTask?.cancel()
        saveTask = nil
        Task { await saveCurrentDocument() }
    }

    private func scheduleAutosave() {
        saveTask?.cancel()
        saveState = .pending

        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await self?.saveCurrentDocument()
        }
    }

    private func saveCurrentDocument() async {
        guard var document = currentDocument else { return }
        saveState = .saving

        do {
            try document.text.write(to: document.url, atomically: true, encoding: .utf8)
            document.isModified = false
            currentDocument = document
            saveState = .saved(.now)
            remember(url: document.url, kind: document.kind)
        } catch {
            saveState = .failed(error.localizedDescription)
            errorMessage = "Could not save \(document.fileName): \(error.localizedDescription)"
        }
    }

    private func loadDocument(url: URL, kind: DocumentKind) throws -> EditableDocument {
        let text = try String(contentsOf: url, encoding: .utf8)
        return EditableDocument(url: url, kind: kind, text: text)
    }

    private func remember(url: URL, kind: DocumentKind) {
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            let item = RecentDocument(bookmark: bookmark, fileName: url.lastPathComponent, kind: kind, lastOpenedAt: .now)
            recentDocuments.removeAll { $0.fileName == item.fileName && $0.kind == item.kind }
            recentDocuments.insert(item, at: 0)
            recentDocuments = Array(recentDocuments.prefix(12))
            persistRecentDocuments()
        } catch {
            errorMessage = "Opened file, but could not remember it for later: \(error.localizedDescription)"
        }
    }

    private func loadRecentDocuments() {
        guard let data = userDefaults.data(forKey: recentDocumentsKey) else { return }
        do {
            recentDocuments = try JSONDecoder().decode([RecentDocument].self, from: data)
        } catch {
            recentDocuments = []
        }
    }

    private func persistRecentDocuments() {
        do {
            let data = try JSONEncoder().encode(recentDocuments)
            userDefaults.set(data, forKey: recentDocumentsKey)
        } catch {
            errorMessage = "Could not save recent documents."
        }
    }
}
