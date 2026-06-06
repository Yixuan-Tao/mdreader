import SwiftUI

struct MarkdownPreview: View {
    let markdown: String
    let fontSize: Double
    let baseURL: URL?
    var onExternalLinkTapped: ((URL) -> Void)?

    var body: some View {
        HTMLPreview(
            html: MarkdownHTMLRenderer.render(markdown, title: "Markdown Preview", fontSize: fontSize),
            baseURL: baseURL,
            onExternalLinkTapped: onExternalLinkTapped
        )
    }
}
