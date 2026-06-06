import XCTest
@testable import mdreader

final class mdreaderTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testDocumentKindDetection() {
        XCTAssertEqual(DocumentKind.kind(for: URL(fileURLWithPath: "/tmp/readme.md")), .markdown)
        XCTAssertEqual(DocumentKind.kind(for: URL(fileURLWithPath: "/tmp/readme.markdown")), .markdown)
        XCTAssertEqual(DocumentKind.kind(for: URL(fileURLWithPath: "/tmp/page.html")), .html)
        XCTAssertEqual(DocumentKind.kind(for: URL(fileURLWithPath: "/tmp/page.htm")), .html)
        XCTAssertEqual(DocumentKind.kind(for: URL(fileURLWithPath: "/tmp/notes.txt")), .text)
        XCTAssertEqual(DocumentKind.kind(for: URL(fileURLWithPath: "/tmp/notes.text")), .text)
        XCTAssertNil(DocumentKind.kind(for: URL(fileURLWithPath: "/tmp/archive.pdf")))
    }

    func testMarkdownHTMLRendererEscapesUnsafeCharacters() {
        let html = MarkdownHTMLRenderer.render("# Hello <script>", title: "A & B")

        XCTAssertTrue(html.contains("A &amp; B"))
        XCTAssertTrue(html.contains("<h1>Hello &lt;script&gt;</h1>"))
        XCTAssertFalse(html.contains("<script>"))
    }

    func testMarkdownHTMLRendererKeepsBlockFormatting() {
        let markdown = """
        # Title

        First paragraph line
        continues here.

        - One
        - Two

        1. First
        2. Second

        ```swift
        let app = "mdreader"
        ```
        """
        let html = MarkdownHTMLRenderer.render(markdown, title: "Blocks")

        XCTAssertTrue(html.contains("<h1>Title</h1>"))
        XCTAssertTrue(html.contains("<p>First paragraph line continues here.</p>"))
        XCTAssertTrue(html.contains("<ul><li>One</li><li>Two</li></ul>"))
        XCTAssertTrue(html.contains("<ol><li>First</li><li>Second</li></ol>"))
        XCTAssertTrue(html.contains("<pre><code>let app = &quot;mdreader&quot;</code></pre>"))
    }

    func testMarkdownHTMLRendererSupportsInlineFormatting() {
        let html = MarkdownHTMLRenderer.render("Use **bold**, *italic*, `code`, and [Apple](https://apple.com).", title: "Inline")

        XCTAssertTrue(html.contains("<strong>bold</strong>"))
        XCTAssertTrue(html.contains("<em>italic</em>"))
        XCTAssertTrue(html.contains("<code>code</code>"))
        XCTAssertTrue(html.contains("<a href=\"https://apple.com\">Apple</a>"))
    }

    func testMarkdownHTMLRendererSupportsTablesAndRules() {
        let markdown = """
        ***

        | Name | Value |
        | ---- | ----- |
        | Map | Dragon Shire |
        | Goal | Objective |
        """
        let html = MarkdownHTMLRenderer.render(markdown, title: "Table")

        XCTAssertTrue(html.contains("<hr>"))
        XCTAssertTrue(html.contains("<thead><tr><th>Name</th><th>Value</th></tr></thead>"))
        XCTAssertTrue(html.contains("<td>Map</td><td>Dragon Shire</td>"))
        XCTAssertTrue(html.contains("<td>Goal</td><td>Objective</td>"))
    }

    func testPlainTextHTMLRendererEscapesUnsafeCharacters() {
        let html = PlainTextHTMLRenderer.render("Hello <script>\nNext line", title: "A & B")

        XCTAssertTrue(html.contains("A &amp; B"))
        XCTAssertTrue(html.contains("Hello &lt;script&gt;\nNext line"))
        XCTAssertFalse(html.contains("<script>"))
    }

    func testHTMLPreviewInjectsStrictContentSecurityPolicy() {
        let html = HTMLPreview.securedHTML("<html><head><title>Test</title></head><body><img src=\"https://example.com/a.png\"><script>alert(1)</script></body></html>")

        XCTAssertTrue(html.contains("Content-Security-Policy"))
        XCTAssertTrue(html.contains("default-src 'none'"))
        XCTAssertTrue(html.contains("script-src 'none'"))
        XCTAssertTrue(html.contains("connect-src 'none'"))
        XCTAssertFalse(html.contains("img-src https:"))
    }

    func testPrivacyManifestDeclaresUserDefaultsReason() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any])
        let accessedAPITypes = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaultsEntry = try XCTUnwrap(accessedAPITypes.first { entry in
            entry["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        })
        let reasons = try XCTUnwrap(userDefaultsEntry["NSPrivacyAccessedAPITypeReasons"] as? [String])

        XCTAssertTrue(reasons.contains("CA92.1"))
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertTrue((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
    }

    func testNewMarkdownDocumentUsesDefaultNameAndContent() throws {
        let url = try NewDocumentService.createDocument(kind: .markdown, in: temporaryDirectory)
        let text = try String(contentsOf: url, encoding: .utf8)

        XCTAssertEqual(url.lastPathComponent, "Untitled.md")
        XCTAssertTrue(text.contains("# Untitled"))
    }

    func testNewHTMLDocumentUsesDefaultNameAndContent() throws {
        let url = try NewDocumentService.createDocument(kind: .html, in: temporaryDirectory)
        let text = try String(contentsOf: url, encoding: .utf8)

        XCTAssertEqual(url.lastPathComponent, "Untitled.html")
        XCTAssertTrue(text.contains("<!doctype html>"))
    }

    func testNewTextDocumentUsesDefaultNameAndContent() throws {
        let url = try NewDocumentService.createDocument(kind: .text, in: temporaryDirectory)
        let text = try String(contentsOf: url, encoding: .utf8)

        XCTAssertEqual(url.lastPathComponent, "Untitled.txt")
        XCTAssertTrue(text.contains("plain text"))
    }

    func testNewDocumentAppendsIndexWhenNameExists() throws {
        _ = try NewDocumentService.createDocument(kind: .markdown, in: temporaryDirectory)
        let secondURL = try NewDocumentService.createDocument(kind: .markdown, in: temporaryDirectory)

        XCTAssertEqual(secondURL.lastPathComponent, "Untitled 2.md")
    }

    @MainActor
    func testRemoveRecentDocument() {
        let store = DocumentStore()
        let recent = RecentDocument(
            bookmark: Data("bookmark".utf8),
            fileName: "Readme.md",
            kind: .markdown,
            lastOpenedAt: Date()
        )

        store.recentDocuments = [recent]
        store.removeRecentDocument(recent)

        XCTAssertTrue(store.recentDocuments.isEmpty)
    }

    @MainActor
    func testStartupRestoreSkipsWhenLastActiveIsOld() throws {
        let suiteName = "mdreaderTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let fileURL = temporaryDirectory.appendingPathComponent("Old.md")
        try "# Old".write(to: fileURL, atomically: true, encoding: .utf8)
        let bookmark = try fileURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)

        let store = DocumentStore(userDefaults: userDefaults)
        store.recentDocuments = [
            RecentDocument(bookmark: bookmark, fileName: "Old.md", kind: .markdown, lastOpenedAt: Date())
        ]
        userDefaults.set(Date(timeIntervalSinceNow: -3_600), forKey: "lastActiveAt")

        store.restoreMostRecentDocumentIfRecentlyActive(maxIdleInterval: 30 * 60)

        XCTAssertNil(store.currentDocument)
    }

    @MainActor
    func testStartupRestoreOpensRecentWhenLastActiveIsRecent() throws {
        let suiteName = "mdreaderTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let fileURL = temporaryDirectory.appendingPathComponent("Recent.md")
        try "# Recent".write(to: fileURL, atomically: true, encoding: .utf8)
        let bookmark = try fileURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)

        let store = DocumentStore(userDefaults: userDefaults)
        store.recentDocuments = [
            RecentDocument(bookmark: bookmark, fileName: "Recent.md", kind: .markdown, lastOpenedAt: Date())
        ]
        userDefaults.set(Date(), forKey: "lastActiveAt")

        store.restoreMostRecentDocumentIfRecentlyActive(maxIdleInterval: 30 * 60)

        XCTAssertEqual(store.currentDocument?.fileName, "Recent.md")
        XCTAssertEqual(store.currentDocument?.text, "# Recent")
    }

    @MainActor
    func testStartupRestoreFailureDoesNotShowUnavailableAlert() {
        let suiteName = "mdreaderTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = DocumentStore(userDefaults: userDefaults)
        store.recentDocuments = [
            RecentDocument(bookmark: Data("invalid bookmark".utf8), fileName: "Missing.md", kind: .markdown, lastOpenedAt: Date())
        ]
        userDefaults.set(Date(), forKey: "lastActiveAt")

        store.restoreMostRecentDocumentIfRecentlyActive(maxIdleInterval: 30 * 60)

        XCTAssertNil(store.currentDocument)
        XCTAssertNil(store.unavailableRecentDocument)
    }

    @MainActor
    func testSettingsPersistAcrossStoreInstances() {
        let suiteName = "mdreaderTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = SettingsStore(userDefaults: userDefaults)
        store.settings.editorFontSize = 21
        store.settings.previewFontSize = 19
        store.settings.defaultEditorMode = .preview

        let reloadedStore = SettingsStore(userDefaults: userDefaults)

        XCTAssertEqual(reloadedStore.settings.editorFontSize, 21)
        XCTAssertEqual(reloadedStore.settings.previewFontSize, 19)
        XCTAssertEqual(reloadedStore.settings.defaultEditorMode, .preview)
    }
}
