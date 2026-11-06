import Foundation
import WebKit

/// 每个账号一个 WKWebView，全部保持在视图层级中（只用透明度区分当前显示），
/// 这样未选中的账号也持续收消息；同时定期唤醒 JS，避免 WebKit 节流导致掉线。
@MainActor
final class WebViewPool: ObservableObject {
    @Published private(set) var unread: [String: Int] = [:]

    /// 未读总数增加时触发（用于统一播放提示音，不依赖各页面自己的音频）。
    var onNewMessage: (() -> Void)?

    private var views: [String: WKWebView] = [:]
    private var bridges: [String: UnreadBridge] = [:]
    private var order: [String] = []
    private var keepAliveTimer: Timer?

    private let limit = 3

    var totalUnread: Int {
        unread.values.reduce(0, +)
    }

    init() {
        keepAliveTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.keepAlive()
            }
        }
    }

    func view(for account: Account) -> WKWebView {
        if let cached = views[account.id] {
            touch(account.id)
            return cached
        }
        let bridge = UnreadBridge(accountId: account.id) { [weak self] accountId, count in
            guard let self else { return }
            let before = self.totalUnread
            if self.unread[accountId] != count {
                self.unread[accountId] = count
            }
            if self.totalUnread > before {
                self.onNewMessage?()
            }
        }
        bridges[account.id] = bridge
        let created = WebViewFactory.make(for: account, bridge: bridge)
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
        bridges[id] = nil
        unread[id] = nil
        order.removeAll { $0 == id }
    }

    func existing(_ id: String) -> WKWebView? {
        views[id]
    }

    func unreadCount(for id: String) -> Int {
        unread[id] ?? 0
    }

    /// 网络恢复时重载所有账号页面（已加载过的），避免停留在错误页。
    func reloadAll() {
        for (_, webView) in views {
            if webView.url != nil {
                webView.reload()
            }
        }
    }

    /// 定期让所有账号的网页执行一次 JS：保持 WebSocket/定时器活跃，避免被系统节流。
    private func keepAlive() {
        for (_, webView) in views {
            webView.evaluateJavaScript(
                "window.__pddTick ? window.__pddTick() : null",
                completionHandler: nil
            )
        }
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
            bridges[oldest] = nil
            unread[oldest] = nil
        }
    }
}
