import Foundation
import WebKit

/// 每个账号一个 WKWebView，切换只切显示，不销毁；最多保留 3 个，超出时释放最久未用的。
@MainActor
final class WebViewPool: ObservableObject {
    private var views: [String: WKWebView] = [:]
    private var order: [String] = []

    private let limit = 3

    func view(for account: Account) -> WKWebView {
        if let cached = views[account.id] {
            touch(account.id)
            return cached
        }
        let created = WebViewFactory.make(for: account)
        views[account.id] = created
        order.append(account.id)
        trimIfNeeded()
        return created
    }

    func loadLogin(for account: Account) {
        let webView = view(for: account)
        webView.load(URLRequest(url: WebViewFactory.loginURL))
    }

    func remove(_ id: String) {
        views[id]?.stopLoading()
        views[id]?.removeFromSuperview()
        views[id] = nil
        order.removeAll { $0 == id }
    }

    func existing(_ id: String) -> WKWebView? {
        views[id]
    }

    private func touch(_ id: String) {
        guard let index = order.firstIndex(of: id) else { return }
        order.remove(at: index)
        order.append(id)
    }

    private func trimIfNeeded() {
        while order.count > limit, let oldest = order.first {
            order.removeFirst()
            views[oldest]?.stopLoading()
            views[oldest]?.removeFromSuperview()
            views[oldest] = nil
        }
    }
}
