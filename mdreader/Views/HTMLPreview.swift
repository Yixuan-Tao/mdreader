import SwiftUI
import WebKit

struct HTMLPreview: UIViewRepresentable {
    let html: String
    let baseURL: URL?
    var onExternalLinkTapped: ((URL) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onExternalLinkTapped: onExternalLinkTapped)
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
        context.coordinator.onExternalLinkTapped = onExternalLinkTapped
        webView.loadHTMLString(Self.securedHTML(html), baseURL: baseURL)
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

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onExternalLinkTapped: ((URL) -> Void)?

        init(onExternalLinkTapped: ((URL) -> Void)?) {
            self.onExternalLinkTapped = onExternalLinkTapped
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

            if shouldOpenExternally(url: url, currentURL: webView.url) {
                onExternalLinkTapped?(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        private func shouldOpenExternally(url: URL, currentURL: URL?) -> Bool {
            guard url.scheme == "http" || url.scheme == "https" else {
                return false
            }

            if let currentURL,
               url.removingFragment() == currentURL.removingFragment(),
               url.fragment != nil {
                return false
            }

            return true
        }
    }
}

private extension URL {
    func removingFragment() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        components.fragment = nil
        return components.url ?? self
    }
}
