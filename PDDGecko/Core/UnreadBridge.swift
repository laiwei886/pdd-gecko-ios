import Foundation
import WebKit

/// 接收网页上报的未读数：每个账号一个 handler，带 accountId 回传原生。
final class UnreadBridge: NSObject, WKScriptMessageHandler {
    let accountId: String
    private let onUnread: (String, Int) -> Void

    init(accountId: String, onUnread: @escaping (String, Int) -> Void) {
        self.accountId = accountId
        self.onUnread = onUnread
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.name == "pddUnread" else { return }
        var count = 0
        if let body = message.body as? [String: Any],
           let value = body["count"] as? Int {
            count = value
        } else if let value = message.body as? Int {
            count = value
        } else if let value = message.body as? NSNumber {
            count = value.intValue
        }
        onUnread(accountId, max(0, count))
    }
}

/// 网页侧脚本：定期统计未读角标，并把未读数上报给原生。
enum UnreadScript {
    static let source = """
    (function () {
      if (window.__pddUnreadInstalled) { return; }
      window.__pddUnreadInstalled = true;

      function collectCount() {
        var total = 0;
        var nodes = document.querySelectorAll('[class*="unread"], [class*="Unread"], .badge, .msg-count, [class*="red-dot"]');
        for (var i = 0; i < nodes.length; i += 1) {
          var el = nodes[i];
          var text = (el.textContent || '').trim();
          var m = text.match(/(\\d+)/);
          if (m) { total += parseInt(m[1], 10); }
          else if (text.indexOf('99') >= 0) { total += 99; }
        }
        return total;
      }

      function report() {
        var count = collectCount();
        try {
          window.webkit.messageHandlers.pddUnread.postMessage({ count: count });
        } catch (e) { /* 非 WKWebView 环境忽略 */ }
        return count;
      }

      window.__pddTick = report;
      setInterval(report, 15000);
      setTimeout(report, 3000);

      // 让页面认为自己始终可见，避免被判定 hidden 后自动切换成“店铺休息”
      try {
        Object.defineProperty(document, 'hidden', { get: function () { return false; } });
        Object.defineProperty(document, 'visibilityState', { get: function () { return 'visible'; } });
      } catch (e) { /* 已有只读属性时忽略 */ }
    })();
    """
}
