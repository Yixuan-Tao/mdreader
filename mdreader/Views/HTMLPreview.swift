import SwiftUI
import WebKit

struct HTMLPreview: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    var targetAnchor: String? = nil
    var onExternalLinkTapped: ((URL) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(targetAnchor: targetAnchor, onExternalLinkTapped: onExternalLinkTapped)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let securedHTML = Self.securedHTML(html)
        let previousAnchor = context.coordinator.targetAnchor

        context.coordinator.onExternalLinkTapped = onExternalLinkTapped
        context.coordinator.targetAnchor = targetAnchor

        if context.coordinator.shouldLoad(html: securedHTML, baseURL: baseURL) {
            context.coordinator.recordLoaded(html: securedHTML, baseURL: baseURL)
            webView.loadHTMLString(securedHTML, baseURL: baseURL)
        } else if targetAnchor != previousAnchor {
            context.coordinator.scrollToTargetAnchor(in: webView)
        }
    }

    static func securedHTML(_ html: String) -> String {
        let policy = """
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: blob: file:; style-src 'unsafe-inline'; font-src data: file:; connect-src 'none'; script-src 'none'; frame-src 'none'; media-src file: data: blob:; object-src 'none'; base-uri 'none'; form-action 'none'">
        """

        if let headRange = html.range(of: "<head", options: [.caseInsensitive]),
           let closeRange = html[headRange.upperBound...].range(of: ">", options: [.caseInsensitive]) {
            var securedHTML = html
            securedHTML.insert(contentsOf: "\n\(policy)", at: closeRange.upperBound)
            return securedHTML
        }

        return """
        <!doctype html>
        <html>
        <head>
        \(policy)
        </head>
        <body>
        \(html)
        </body>
        </html>
        """
    }

    static func linkPolicy(for url: URL, currentURL: URL?) -> PreviewLinkPolicy {
        if url.isBlankPageAnchor {
            return .allowInPreview
        }

        if let currentURL,
           url.removingFragment() == currentURL.removingFragment(),
           url.fragment != nil {
            return .allowInPreview
        }

        guard let scheme = url.scheme?.lowercased() else {
            return .cancel
        }

        if scheme == "http" || scheme == "https" {
            return .openExternally
        }

        return .cancel
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var targetAnchor: String?
        var onExternalLinkTapped: ((URL) -> Void)?
        private var lastLoadedHTML: String?
        private var lastLoadedBaseURL: URL?

        init(targetAnchor: String?, onExternalLinkTapped: ((URL) -> Void)?) {
            self.targetAnchor = targetAnchor
            self.onExternalLinkTapped = onExternalLinkTapped
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            scrollToTargetAnchor(in: webView)
        }

        func shouldLoad(html: String, baseURL: URL?) -> Bool {
            lastLoadedHTML != html || lastLoadedBaseURL != baseURL
        }

        func recordLoaded(html: String, baseURL: URL?) {
            lastLoadedHTML = html
            lastLoadedBaseURL = baseURL
        }

        func scrollToTargetAnchor(in webView: WKWebView) {
            guard let targetAnchor else { return }
            let escapedAnchor = targetAnchor
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("document.getElementById('\(escapedAnchor)')?.scrollIntoView();")
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            switch HTMLPreview.linkPolicy(for: url, currentURL: webView.url) {
            case .allowInPreview:
                decisionHandler(.allow)
            case .openExternally:
                onExternalLinkTapped?(url)
                decisionHandler(.cancel)
            case .cancel:
                decisionHandler(.cancel)
            }
        }
    }
}

enum PreviewLinkPolicy: Equatable {
    case allowInPreview
    case openExternally
    case cancel
}

private extension URL {
    var isBlankPageAnchor: Bool {
        absoluteString.lowercased().hasPrefix("about:blank#")
    }

    func removingFragment() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        components.fragment = nil
        return components.url ?? self
    }
}
