import SwiftUI
import WebKit

/// 单一 UIView 容器承载所有账号的 WebView：
/// 全部留在同一视图树里（后台账号 alpha 极小但未隐藏），
/// 避免 SwiftUI 反复重建容器把 WebView 移出窗口导致白屏。
@MainActor
struct WebViewsHost: UIViewRepresentable {
    let accounts: [Account]
    let activeId: String?
    let pool: WebViewPool

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        // 移除已删除账号的 WebView
        for sub in container.subviews where sub is WKWebView {
            let stillNeeded = accounts.contains { account in
                pool.existing(account.id) === sub
            }
            if !stillNeeded {
                sub.removeFromSuperview()
            }
        }

        for account in accounts {
            let webView = pool.view(for: account)
            if webView.superview !== container {
                webView.removeFromSuperview()
                webView.translatesAutoresizingMaskIntoConstraints = false
                container.addSubview(webView)
                NSLayoutConstraint.activate([
                    webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    webView.topAnchor.constraint(equalTo: container.topAnchor),
                    webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
                ])
            }
            let active = account.id == activeId
            webView.alpha = active ? 1.0 : 0.001
            webView.isUserInteractionEnabled = active
            if active {
                container.bringSubviewToFront(webView)
            }
        }
    }
}
