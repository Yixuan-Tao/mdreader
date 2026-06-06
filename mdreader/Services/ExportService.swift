import Foundation
import UIKit

struct MarkdownHeading: Identifiable, Equatable {
    let level: Int
    let title: String
    let anchor: String

    var id: String { anchor }
}

enum ExportService {
    static func htmlData(for document: EditableDocument) -> Data {
        let html: String

        switch document.kind {
        case .html:
            html = document.text
        case .markdown:
            html = MarkdownHTMLRenderer.render(document.text, title: document.fileName)
        case .text:
            html = PlainTextHTMLRenderer.render(document.text, title: document.fileName)
        }

        return Data(html.utf8)
    }

    static func htmlExportURL(for document: EditableDocument) throws -> URL {
        let baseName = document.url.deletingPathExtension().lastPathComponent
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)-export")
            .appendingPathExtension("html")

        try htmlData(for: document).write(to: exportURL, options: .atomic)
        return exportURL
    }

    static func pdfExportURL(for document: EditableDocument) throws -> URL {
        let baseName = document.url.deletingPathExtension().lastPathComponent
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)-preview")
            .appendingPathExtension("pdf")

        let html = String(decoding: htmlData(for: document), as: UTF8.self)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(UIMarkupTextPrintFormatter(markupText: html), startingAtPageAt: 0)

        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let printable = page.insetBy(dx: 36, dy: 36)
        renderer.setValue(NSValue(cgRect: page), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printable), forKey: "printableRect")

        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, page, nil)
        for pageIndex in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: pageIndex, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()

        try data.write(to: exportURL, options: .atomic)
        return exportURL
    }
}

enum PlainTextHTMLRenderer {
    static func render(_ text: String, title: String, fontSize: Double = 17) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(MarkdownHTMLRenderer.escape(title))</title>
        <style>
        :root { color-scheme: light dark; }
        body {
          margin: 0;
          padding: 24px 20px 40px;
          color: #1f2328;
          background: #ffffff;
        }
        pre {
          margin: 0;
          white-space: pre-wrap;
          overflow-wrap: anywhere;
          font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
          font-size: \(fontSize)px;
          line-height: 1.55;
        }
        @media (prefers-color-scheme: dark) {
          body { color: #e6edf3; background: #000000; }
        }
        </style>
        </head>
        <body>
        <pre>\(MarkdownHTMLRenderer.escape(text))</pre>
        </body>
        </html>
        """
    }
}

enum MarkdownHTMLRenderer {
    static func render(_ markdown: String, title: String, fontSize: Double = 17, searchQuery: String = "") -> String {
        let body = renderBlocks(markdown, searchQuery: searchQuery)

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>
        :root { color-scheme: light dark; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
          font-size: \(fontSize)px;
          line-height: 1.58;
          margin: 0;
          padding: 24px 20px 40px;
          color: #1f2328;
          background: #ffffff;
          overflow-wrap: anywhere;
        }
        h1, h2, h3, h4, h5, h6 { line-height: 1.22; margin: 1.2em 0 0.5em; font-weight: 700; scroll-margin-top: 18px; }
        h1 { font-size: 2em; border-bottom: 1px solid #d0d7de; padding-bottom: 0.25em; }
        h2 { font-size: 1.55em; border-bottom: 1px solid #d0d7de; padding-bottom: 0.22em; }
        h3 { font-size: 1.25em; }
        p { margin: 0 0 1em; }
        ul, ol { margin: 0 0 1em 1.35em; padding: 0; }
        li { margin: 0.25em 0; }
        li.task-list-item { list-style: none; margin-left: -1.35em; }
        .task-box { display: inline-block; width: 1.05em; color: #57606a; }
        pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background: #f6f8fa; border-radius: 6px; }
        code { padding: 2px 4px; }
        pre { padding: 12px; overflow-x: auto; margin: 0 0 1em; }
        pre code { padding: 0; background: transparent; }
        pre code[data-language]::before {
          content: attr(data-language);
          display: block;
          margin-bottom: 8px;
          color: #57606a;
          font-size: 0.78em;
          text-transform: uppercase;
          letter-spacing: 0.04em;
        }
        .token-keyword { color: #cf222e; }
        .token-string { color: #0a3069; }
        .token-comment { color: #6e7781; }
        blockquote { border-left: 4px solid #d0d7de; margin: 0 0 1em; padding-left: 14px; color: #57606a; }
        a { color: #0969da; }
        img { max-width: 100%; }
        mark.search-hit { background: #fff3a3; color: inherit; border-radius: 3px; padding: 0 2px; }
        .table-wrapper { overflow-x: auto; margin: 0 0 1em; }
        table { border-collapse: collapse; width: 100%; min-width: 520px; }
        th, td { border: 1px solid #d0d7de; padding: 6px 8px; }
        th { font-weight: 700; background: #f6f8fa; }
        hr { border: 0; border-top: 1px solid #d0d7de; margin: 1.5em 0; }
        @media (prefers-color-scheme: dark) {
          body { color: #e6edf3; background: #000000; }
          h1, h2, th, td, hr { border-color: #30363d; }
          pre, code { background: #161b22; }
          th { background: #161b22; }
          blockquote { border-left-color: #30363d; color: #8b949e; }
          a { color: #58a6ff; }
          .task-box { color: #8b949e; }
          .token-keyword { color: #ff7b72; }
          .token-string { color: #a5d6ff; }
          .token-comment { color: #8b949e; }
          mark.search-hit { background: #674f00; }
        }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    static func tableOfContents(from markdown: String) -> [MarkdownHeading] {
        var usedAnchors: [String: Int] = [:]

        return markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> MarkdownHeading? in
                guard let heading = heading(from: String(line), usedAnchors: &usedAnchors),
                      heading.level <= 3 else {
                    return nil
                }
                return heading
            }
    }

    static func searchMatchCount(in markdown: String, query: String) -> Int {
        countSearchMatches(in: markdown, query: query)
    }

    private static func renderBlocks(_ markdown: String, searchQuery: String) -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var blocks: [String] = []
        var paragraph: [String] = []
        var unorderedItems: [String] = []
        var orderedItems: [String] = []
        var codeLines: [String] = []
        var tableLines: [String] = []
        var codeLanguage: String?
        var isInCodeBlock = false
        var usedAnchors: [String: Int] = [:]

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append("<p>\(inline(paragraph.joined(separator: " "), searchQuery: searchQuery))</p>")
            paragraph.removeAll()
        }

        func flushUnorderedList() {
            guard !unorderedItems.isEmpty else { return }
            blocks.append("<ul>\(unorderedItems.joined())</ul>")
            unorderedItems.removeAll()
        }

        func flushOrderedList() {
            guard !orderedItems.isEmpty else { return }
            blocks.append("<ol>\(orderedItems.joined())</ol>")
            orderedItems.removeAll()
        }

        func flushLists() {
            flushUnorderedList()
            flushOrderedList()
        }

        func flushTable() {
            guard !tableLines.isEmpty else { return }
            if let table = tableHTML(from: tableLines, searchQuery: searchQuery) {
                blocks.append(table)
            } else {
                blocks.append(contentsOf: tableLines.map { "<p>\(inline($0, searchQuery: searchQuery))</p>" })
            }
            tableLines.removeAll()
        }

        func flushFlowBlocks() {
            flushParagraph()
            flushLists()
            flushTable()
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInCodeBlock {
                    blocks.append(codeBlockHTML(lines: codeLines, language: codeLanguage))
                    codeLines.removeAll()
                    codeLanguage = nil
                    isInCodeBlock = false
                } else {
                    flushFlowBlocks()
                    codeLanguage = fenceLanguage(from: trimmed)
                    isInCodeBlock = true
                }
                continue
            }

            if isInCodeBlock {
                codeLines.append(line)
                continue
            }

            if trimmed.isEmpty {
                flushFlowBlocks()
                continue
            }

            if isHorizontalRule(trimmed) {
                flushFlowBlocks()
                blocks.append("<hr>")
                continue
            }

            if let heading = headingHTML(for: trimmed, usedAnchors: &usedAnchors, searchQuery: searchQuery) {
                flushFlowBlocks()
                blocks.append(heading)
                continue
            }

            if trimmed.hasPrefix(">") {
                flushFlowBlocks()
                let quoted = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                blocks.append("<blockquote>\(inline(quoted, searchQuery: searchQuery))</blockquote>")
                continue
            }

            if let item = unorderedListItem(from: trimmed) {
                flushParagraph()
                flushTable()
                flushOrderedList()
                unorderedItems.append(unorderedListItemHTML(item, searchQuery: searchQuery))
                continue
            }

            if let item = orderedListItem(from: trimmed) {
                flushParagraph()
                flushTable()
                flushUnorderedList()
                orderedItems.append("<li>\(inline(item, searchQuery: searchQuery))</li>")
                continue
            }

            if trimmed.contains("|") {
                flushParagraph()
                flushLists()
                tableLines.append(trimmed)
                continue
            }

            flushTable()
            flushLists()
            paragraph.append(trimmed)
        }

        if isInCodeBlock {
            blocks.append(codeBlockHTML(lines: codeLines, language: codeLanguage))
        }
        flushFlowBlocks()

        return blocks.joined(separator: "\n")
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3 else { return false }
        return compact.allSatisfy { $0 == "*" }
            || compact.allSatisfy { $0 == "-" }
            || compact.allSatisfy { $0 == "_" }
    }

    private static func headingHTML(for line: String, usedAnchors: inout [String: Int], searchQuery: String) -> String? {
        guard let heading = heading(from: line, usedAnchors: &usedAnchors) else { return nil }

        return "<h\(heading.level) id=\"\(heading.anchor)\">\(inline(heading.title, searchQuery: searchQuery))</h\(heading.level)>"
    }

    private static func heading(from line: String, usedAnchors: inout [String: Int]) -> MarkdownHeading? {
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount),
              line.dropFirst(markerCount).first == " " else {
            return nil
        }

        let title = String(line.dropFirst(markerCount + 1)).trimmingCharacters(in: .whitespaces)
        let baseAnchor = slug(for: title)
        let index = usedAnchors[baseAnchor, default: 0]
        usedAnchors[baseAnchor] = index + 1
        let anchor = index == 0 ? baseAnchor : "\(baseAnchor)-\(index + 1)"
        return MarkdownHeading(level: markerCount, title: title, anchor: anchor)
    }

    private static func unorderedListItem(from line: String) -> String? {
        guard line.count > 2 else { return nil }
        let prefix = line.prefix(2)
        guard prefix == "- " || prefix == "* " || prefix == "+ " else { return nil }
        return String(line.dropFirst(2))
    }

    private static func orderedListItem(from line: String) -> String? {
        guard let dotIndex = line.firstIndex(of: ".") else { return nil }
        let number = line[..<dotIndex]
        let afterDot = line[line.index(after: dotIndex)...]
        guard !number.isEmpty,
              number.allSatisfy(\.isNumber),
              afterDot.first == " " else {
            return nil
        }

        return String(afterDot.dropFirst())
    }

    private static func tableHTML(from lines: [String], searchQuery: String = "") -> String? {
        guard lines.count >= 2, isTableSeparator(lines[1]) else { return nil }

        let headers = tableCells(from: lines[0])
        guard !headers.isEmpty else { return nil }

        let headerHTML = headers.map { "<th>\(inline($0, searchQuery: searchQuery))</th>" }.joined()
        let bodyRows = lines.dropFirst(2).map { line in
            let cells = tableCells(from: line)
            return "<tr>\(cells.map { "<td>\(inline($0, searchQuery: searchQuery))</td>" }.joined())</tr>"
        }.joined()

        return """
        <div class="table-wrapper"><table>
        <thead><tr>\(headerHTML)</tr></thead>
        <tbody>\(bodyRows)</tbody>
        </table></div>
        """
    }

    private static func tableCells(from line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") {
            trimmed.removeFirst()
        }
        if trimmed.hasSuffix("|") {
            trimmed.removeLast()
        }

        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cells = tableCells(from: line)
        guard !cells.isEmpty else { return false }

        return cells.allSatisfy { cell in
            let compact = cell.filter { !$0.isWhitespace }
            guard compact.count >= 3 else { return false }
            return compact.allSatisfy { $0 == "-" || $0 == ":" }
                && compact.contains("-")
        }
    }

    private static func inline<S: StringProtocol>(_ text: S, searchQuery: String = "") -> String {
        var result = escape(String(text))
        result = replacingMatches(in: result, pattern: "`([^`]+)`") { match in
            "<code>\(match[1])</code>"
        }
        result = replacingMatches(in: result, pattern: "\\*\\*([^*]+)\\*\\*") { match in
            "<strong>\(match[1])</strong>"
        }
        result = replacingMatches(in: result, pattern: "\\*([^*]+)\\*") { match in
            "<em>\(match[1])</em>"
        }
        result = replacingMatches(in: result, pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)") { match in
            let label = match[1]
            let href = match[2].replacingOccurrences(of: "\"", with: "%22")
            return "<a href=\"\(href)\">\(label)</a>"
        }
        return highlightVisibleText(in: result, query: searchQuery)
    }

    private static func unorderedListItemHTML(_ item: String, searchQuery: String) -> String {
        if item.hasPrefix("[ ] ") {
            return "<li class=\"task-list-item\"><span class=\"task-box\">□</span>\(inline(item.dropFirst(4), searchQuery: searchQuery))</li>"
        }

        if item.hasPrefix("[x] ") || item.hasPrefix("[X] ") {
            return "<li class=\"task-list-item\"><span class=\"task-box\">☑</span>\(inline(item.dropFirst(4), searchQuery: searchQuery))</li>"
        }

        return "<li>\(inline(item, searchQuery: searchQuery))</li>"
    }

    private static func fenceLanguage(from line: String) -> String? {
        let language = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
        return language.isEmpty ? nil : String(language)
    }

    private static func codeBlockHTML(lines: [String], language: String?) -> String {
        let code = highlightCode(escape(lines.joined(separator: "\n")), language: language)
        guard let language else {
            return "<pre><code>\(code)</code></pre>"
        }

        let safeLanguage = escape(language.lowercased())
        return "<pre><code class=\"language-\(safeLanguage)\" data-language=\"\(safeLanguage)\">\(code)</code></pre>"
    }

    private static func highlightCode(_ code: String, language: String?) -> String {
        guard let language = language?.lowercased(),
              ["swift", "javascript", "js", "python", "json", "shell", "bash", "sh", "html", "css"].contains(language) else {
            return code
        }

        var highlighted = code
        highlighted = replacingMatches(in: highlighted, pattern: "(&quot;[^\\n]*?&quot;|'[^\\n]*?')") { match in
            "<span class=\"token-string\">\(match[1])</span>"
        }
        highlighted = replacingMatches(in: highlighted, pattern: "(//[^\\n]*|#[^\\n]*|&lt;!--.*?--&gt;)") { match in
            "<span class=\"token-comment\">\(match[1])</span>"
        }
        highlighted = replacingMatches(in: highlighted, pattern: "\\b(func|let|var|struct|class|enum|import|if|else|for|while|return|guard|switch|case|const|function|def|true|false|null|nil|public|private|static|async|await)\\b") { match in
            "<span class=\"token-keyword\">\(match[1])</span>"
        }
        return highlighted
    }

    private static func slug(for heading: String) -> String {
        let lowercased = heading.lowercased()
        let allowed = lowercased.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            if scalar.value > 127 {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(allowed)
            .split(separator: "-")
            .joined(separator: "-")
        return collapsed.isEmpty ? "section" : collapsed
    }

    private static func highlightVisibleText(in html: String, query: String) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return html }

        var result = ""
        var textBuffer = ""
        var isInsideTag = false

        func flushTextBuffer() {
            result += highlightEscapedText(textBuffer, query: trimmedQuery)
            textBuffer.removeAll()
        }

        for character in html {
            if character == "<" {
                flushTextBuffer()
                isInsideTag = true
                result.append(character)
            } else if character == ">" {
                isInsideTag = false
                result.append(character)
            } else if isInsideTag {
                result.append(character)
            } else {
                textBuffer.append(character)
            }
        }
        flushTextBuffer()

        return result
    }

    private static func highlightEscapedText(_ text: String, query: String) -> String {
        guard !text.isEmpty else { return text }
        let escapedQuery = NSRegularExpression.escapedPattern(for: escape(query))
        return replacingMatches(in: text, pattern: escapedQuery, options: [.caseInsensitive]) { match in
            "<mark class=\"search-hit\">\(match[0])</mark>"
        }
    }

    private static func countSearchMatches(in text: String, query: String) -> Int {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else { return 0 }
        let pattern = NSRegularExpression.escapedPattern(for: trimmedQuery)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return 0 }
        let nsText = text as NSString
        return regex.numberOfMatches(in: text, range: NSRange(location: 0, length: nsText.length))
    }

    static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = [],
        replacement: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).reversed()
        var result = text

        for match in matches {
            let groups = (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                guard range.location != NSNotFound else { return "" }
                return nsText.substring(with: range)
            }
            let range = Range(match.range, in: result)!
            result.replaceSubrange(range, with: replacement(groups))
        }

        return result
    }
}
