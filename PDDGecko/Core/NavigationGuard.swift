import Foundation
import WebKit

/// 导航守卫：只允许拼多多系域名，拦截 App 下载页与外部跳转（与安卓壳一致）。
final class NavigationGuard: NSObject, WKNavigationDelegate, WKUIDelegate {
    static let shared = NavigationGuard()

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        let scheme = (url.scheme ?? "").lowercased()
        if ["intent", "market", "pddopen", "pinduoduo"].contains(scheme) {
            decisionHandler(.cancel)
            notifyBlocked()
            return
        }
        guard scheme == "http" || scheme == "https" else {
            decisionHandler(.allow)
            return
        }
        let host = (url.host ?? "").lowercased()
        let allowedHost = host == "pinduoduo.com"
            || host.hasSuffix(".pinduoduo.com")
            || host == "yangkeduo.com"
            || host.hasSuffix(".yangkeduo.com")
        if !allowedHost || url.absoluteString.contains("/other/downloadapp") {
            decisionHandler(.cancel)
            notifyBlocked()
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let code = (error as NSError).code
        if code == NSURLErrorCancelled { return }
        NotificationCenter.default.post(name: .pddNetworkError, object: error)
    }

    private func notifyBlocked() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .pddBlockedNavigation, object: nil)
        }
    }
}

extension Notification.Name {
    static let pddBlockedNavigation = Notification.Name("pdd.blockedNavigation")
    static let pddNetworkError = Notification.Name("pdd.networkError")
}
