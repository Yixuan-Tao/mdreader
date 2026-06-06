import Foundation
import UniformTypeIdentifiers

enum DocumentKind: String, Codable, CaseIterable {
    case markdown
    case html
    case text

    var displayName: String {
        switch self {
        case .markdown: "Markdown"
        case .html: "HTML"
        case .text: "Text"
        }
    }

    var exportExtension: String {
        switch self {
        case .markdown: "html"
        case .html: "html"
        case .text: "html"
        }
    }

    static func kind(for url: URL) -> DocumentKind? {
        switch url.pathExtension.lowercased() {
        case "md", "markdown":
            return .markdown
        case "html", "htm":
            return .html
        case "txt", "text":
            return .text
        default:
            return nil
        }
    }
}

struct EditableDocument: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let kind: DocumentKind
    var fileName: String
    var text: String
    var isModified: Bool
    var lastOpenedAt: Date

    init(url: URL, kind: DocumentKind, text: String, id: UUID = UUID(), lastOpenedAt: Date = .now) {
        self.id = id
        self.url = url
        self.kind = kind
        self.fileName = url.lastPathComponent
        self.text = text
        self.isModified = false
        self.lastOpenedAt = lastOpenedAt
    }
}

struct RecentDocument: Identifiable, Codable, Equatable {
    var id: String { bookmark.base64EncodedString() }

    let bookmark: Data
    let fileName: String
    let kind: DocumentKind
    let lastOpenedAt: Date

    var lastOpenedDescription: String {
        lastOpenedAt.formatted(date: .abbreviated, time: .shortened)
    }
}
