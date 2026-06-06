import Foundation

enum NewDocumentService {
    static func defaultFileName(for kind: DocumentKind) -> String {
        switch kind {
        case .markdown:
            return "Untitled.md"
        case .html:
            return "Untitled.html"
        case .text:
            return "Untitled.txt"
        }
    }

    static func initialContent(for kind: DocumentKind) -> String {
        switch kind {
        case .markdown:
            return """
            # Untitled

            Start writing Markdown here.
            """
        case .html:
            return """
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>Untitled</title>
            </head>
            <body>
              <h1>Untitled</h1>
              <p>Start writing HTML here.</p>
            </body>
            </html>
            """
        case .text:
            return "Start writing plain text here."
        }
    }

    static func uniqueDocumentURL(for kind: DocumentKind, in directory: URL, fileManager: FileManager = .default) -> URL {
        let defaultName = defaultFileName(for: kind)
        let baseName = (defaultName as NSString).deletingPathExtension
        let pathExtension = (defaultName as NSString).pathExtension
        var candidate = directory.appendingPathComponent(defaultName)
        var index = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension(pathExtension)
            index += 1
        }

        return candidate
    }

    static func createDocument(kind: DocumentKind, in directory: URL, fileManager: FileManager = .default) throws -> URL {
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let url = uniqueDocumentURL(for: kind, in: directory, fileManager: fileManager)
        try initialContent(for: kind).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
