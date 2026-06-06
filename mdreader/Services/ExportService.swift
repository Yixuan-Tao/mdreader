import Foundation
import UIKit

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
    static func render(_ markdown: String, title: String, fontSize: Double = 17) -> String {
        let body = renderBlocks(markdown)

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
        h1, h2, h3, h4, h5, h6 { line-height: 1.22; margin: 1.2em 0 0.5em; font-weight: 700; }
        h1 { font-size: 2em; border-bottom: 1px solid #d0d7de; padding-bottom: 0.25em; }
        h2 { font-size: 1.55em; border-bottom: 1px solid #d0d7de; padding-bottom: 0.22em; }
        h3 { font-size: 1.25em; }
        p { margin: 0 0 1em; }
        ul, ol { margin: 0 0 1em 1.35em; padding: 0; }
        li { margin: 0.25em 0; }
        pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background: #f6f8fa; border-radius: 6px; }
        code { padding: 2px 4px; }
        pre { padding: 12px; overflow-x: auto; margin: 0 0 1em; }
        pre code { padding: 0; background: transparent; }
        blockquote { border-left: 4px solid #d0d7de; margin: 0 0 1em; padding-left: 14px; color: #57606a; }
        a { color: #0969da; }
        img { max-width: 100%; }
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
        }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    private static func renderBlocks(_ markdown: String) -> String {
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var blocks: [String] = []
        var paragraph: [String] = []
        var unorderedItems: [String] = []
        var orderedItems: [String] = []
        var codeLines: [String] = []
        var tableLines: [String] = []
        var isInCodeBlock = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append("<p>\(inline(paragraph.joined(separator: " ")))</p>")
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
            if let table = tableHTML(from: tableLines) {
                blocks.append(table)
            } else {
                blocks.append(contentsOf: tableLines.map { "<p>\(inline($0))</p>" })
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
                    blocks.append("<pre><code>\(escape(codeLines.joined(separator: "\n")))</code></pre>")
                    codeLines.removeAll()
                    isInCodeBlock = false
                } else {
                    flushFlowBlocks()
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

            if let heading = headingHTML(for: trimmed) {
                flushFlowBlocks()
                blocks.append(heading)
                continue
            }

            if trimmed.hasPrefix(">") {
                flushFlowBlocks()
                let quoted = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
                blocks.append("<blockquote>\(inline(quoted))</blockquote>")
                continue
            }

            if let item = unorderedListItem(from: trimmed) {
                flushParagraph()
                flushTable()
                flushOrderedList()
                unorderedItems.append("<li>\(inline(item))</li>")
                continue
            }

            if let item = orderedListItem(from: trimmed) {
                flushParagraph()
                flushTable()
                flushUnorderedList()
                orderedItems.append("<li>\(inline(item))</li>")
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
            blocks.append("<pre><code>\(escape(codeLines.joined(separator: "\n")))</code></pre>")
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

    private static func headingHTML(for line: String) -> String? {
        let markerCount = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(markerCount),
              line.dropFirst(markerCount).first == " " else {
            return nil
        }

        let text = line.dropFirst(markerCount + 1)
        return "<h\(markerCount)>\(inline(text))</h\(markerCount)>"
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

    private static func tableHTML(from lines: [String]) -> String? {
        guard lines.count >= 2, isTableSeparator(lines[1]) else { return nil }

        let headers = tableCells(from: lines[0])
        guard !headers.isEmpty else { return nil }

        let headerHTML = headers.map { "<th>\(inline($0))</th>" }.joined()
        let bodyRows = lines.dropFirst(2).map { line in
            let cells = tableCells(from: line)
            return "<tr>\(cells.map { "<td>\(inline($0))</td>" }.joined())</tr>"
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

    private static func inline<S: StringProtocol>(_ text: S) -> String {
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
        return result
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
        replacement: ([String]) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
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
