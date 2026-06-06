import Foundation

enum SampleDocumentService {
    struct Sample: Identifiable {
        let id: String
        let title: String
        let sourceFileName: String
        let destinationFileName: String
        let kind: DocumentKind
        let systemImage: String
    }

    static let samples: [Sample] = [
        Sample(
            id: "markdown",
            title: "风暴英雄多地图机制竞品分析",
            sourceFileName: "SampleMarkdown.md",
            destinationFileName: "风暴英雄多地图机制竞品分析.md",
            kind: .markdown,
            systemImage: "doc.plaintext"
        ),
        Sample(
            id: "html",
            title: "HTML Demo",
            sourceFileName: "SampleHTML.html",
            destinationFileName: "SampleHTML.html",
            kind: .html,
            systemImage: "curlybraces"
        ),
        Sample(
            id: "text",
            title: "TXT Demo",
            sourceFileName: "SampleText.txt",
            destinationFileName: "TestPlainText.txt",
            kind: .text,
            systemImage: "doc.text"
        )
    ]

    static func sampleURL(for sample: Sample) throws -> URL {
        let sourceName = (sample.sourceFileName as NSString).deletingPathExtension
        let sourceExtension = (sample.sourceFileName as NSString).pathExtension

        guard let sourceURL = Bundle.main.url(forResource: sourceName, withExtension: sourceExtension) else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = try sampleDirectory()
        let destinationURL = directory.appendingPathComponent(sample.destinationFileName)

        if !FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        }

        return destinationURL
    }

    static func sample(with id: String) -> Sample? {
        samples.first { $0.id == id }
    }

    private static func sampleDirectory() throws -> URL {
        let documentsURL = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let samplesURL = documentsURL.appendingPathComponent("Samples", isDirectory: true)

        if !FileManager.default.fileExists(atPath: samplesURL.path) {
            try FileManager.default.createDirectory(at: samplesURL, withIntermediateDirectories: true)
        }

        return samplesURL
    }
}
