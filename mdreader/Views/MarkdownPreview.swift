import SwiftUI

struct MarkdownPreview: View {
    let markdown: String
    let fontSize: Double
    let baseURL: URL?
    let searchQuery: String
    let targetAnchor: String?
    var onExternalLinkTapped: ((URL) -> Void)?

    var body: some View {
        HTMLPreview(
            html: MarkdownHTMLRenderer.render(markdown, title: "Markdown Preview", fontSize: fontSize, searchQuery: searchQuery),
            baseURL: baseURL,
            targetAnchor: targetAnchor,
            onExternalLinkTapped: onExternalLinkTapped
        )
    }
}
