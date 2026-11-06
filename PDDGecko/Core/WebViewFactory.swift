import Foundation
import WebKit

/// 创建与清理账号对应的 WKWebView / WKWebsiteDataStore。
enum WebViewFactory {
    static let startUrlString = "https://mms.pinduoduo.com/chat-merchant/index.html"

    static var startURL: URL {
        URL(string: startUrlString)!
    }

    static var loginURL: URL {
        let encoded = startUrlString.addingPercentEncoding(
            withAllowedCharacters: .alphanumerics
        ) ?? startUrlString
        return URL(string: "https://mms.pinduoduo.com/login/?redirectUrl=\(encoded)")!
    }

    static func make(for account: Account, bridge: UnreadBridge) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore(for: account)
        configuration.allowsInlineMediaPlayback = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        // 允许网页 JS 打开新窗口（商品规格弹窗里的“查看详情”等依赖此行为）
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.userContentController.removeAllUserScripts()
        Injection.scripts().forEach {
            configuration.userContentController.addUserScript($0)
        }
        // 未读上报 + 保活脚本
        configuration.userContentController.addUserScript(
            WKUserScript(source: UnreadScript.source,
                         injectionTime: .atDocumentEnd,
                         forMainFrameOnly: false)
        )
        configuration.userContentController.add(bridge, name: "pddUnread")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        webView.navigationDelegate = NavigationGuard.shared
        webView.uiDelegate = NavigationGuard.shared
        webView.load(URLRequest(url: startURL))
        return webView
    }

    /// iOS 17+ 用按 identifier 隔离的持久化存储；低版本回退默认存储（此时不支持多账号隔离）。
    static func dataStore(for account: Account) -> WKWebsiteDataStore {
        if #available(iOS 17.0, *), let uuid = UUID(uuidString: account.id) {
            return WKWebsiteDataStore(forIdentifier: uuid)
        }
        return .default()
    }

    /// 删除账号时清掉它自己的 Cookie/缓存，不影响其它账号。
    static func clearData(for account: Account, completion: (() -> Void)? = nil) {
        if #available(iOS 17.0, *), let uuid = UUID(uuidString: account.id) {
            WKWebsiteDataStore.remove(forIdentifier: uuid) { _ in completion?() }
        } else {
            completion?()
        }
    }
}
