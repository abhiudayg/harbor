import Foundation
import WebKit

@MainActor
public final class WebKitEngine {
    public let webView: WKWebView
    private let navigationDelegate = NavigationWaiter()
    private let contentRules: Task<Bool, Never>

    public init(isBackground: Bool, contentBlocking: ContentBlockingPolicy = .standard) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = isBackground
            ? WKWebsiteDataStore.nonPersistent()
            : WKWebsiteDataStore.default()
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = navigationDelegate
        let controller = configuration.userContentController
        contentRules = Task { @MainActor in
            guard let json = contentBlocking.ruleListJSON,
                  let list = try? await WKContentRuleListStore.default().compileContentRuleList(
                      forIdentifier: "harbor-content-blocking",
                      encodedContentRuleList: json
                  )
            else {
                return false
            }
            controller.add(list)
            return true
        }
    }

    public var isPersistent: Bool {
        webView.configuration.websiteDataStore.isPersistent
    }

    public var isContentBlocking: Bool {
        get async {
            await contentRules.value
        }
    }

    public func load(_ url: URL, restrictToPublicWeb: Bool = false) async throws {
        _ = await contentRules.value
        navigationDelegate.restrictToPublicWeb = restrictToPublicWeb
        try await navigationDelegate.waitForNavigation {
            webView.load(URLRequest(url: url))
        }
    }

    public func loadHTML(_ html: String, baseURL: URL? = nil) async throws {
        _ = await contentRules.value
        navigationDelegate.restrictToPublicWeb = false
        try await navigationDelegate.waitForNavigation {
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    public func evaluate(
        _ script: String,
        arguments: [String: Any]
    ) async throws -> Any? {
        try await webView.callAsyncJavaScript(script, arguments: arguments, in: nil, contentWorld: .page)
    }
}

@MainActor
final class NavigationWaiter: NSObject, WKNavigationDelegate {
    var restrictToPublicWeb = false
    private var continuation: CheckedContinuation<Void, Error>?

    func waitForNavigation(_ start: () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            start()
        }
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        guard restrictToPublicWeb, let url = webView.url, !DestinationPolicy.isAllowed(url) else {
            return
        }
        webView.stopLoading()
        continuation?.resume(throwing: PageDriverError.navigationFailed("redirect to a disallowed destination"))
        continuation = nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        guard restrictToPublicWeb, navigationAction.targetFrame?.isMainFrame ?? true else {
            decisionHandler(.allow)
            return
        }
        guard let url = navigationAction.request.url, DestinationPolicy.isAllowed(url) else {
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        continuation?.resume(throwing: PageDriverError.navigationFailed(error.localizedDescription))
        continuation = nil
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        continuation?.resume(throwing: PageDriverError.navigationFailed(error.localizedDescription))
        continuation = nil
    }
}
