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

/// 网页侧脚本：统计未读角标并上报；另提供诊断函数，便于排查选择器。
enum UnreadScript {
    static let source = """
    (function () {
      if (window.__pddUnreadInstalled) { return; }
      window.__pddUnreadInstalled = true;

      var SELECTORS = [
        '[class*="unread"]', '[class*="Unread"]', '[class*="UNREAD"]',
        '[class*="badge"]', '[class*="Badge"]',
        '[class*="red-dot"]', '[class*="redDot"]',
        '[class*="msg-count"]', '[class*="msgCount"]',
        '[class*="dot"]', '[class*="count"]'
      ];

      function pickNumber(el) {
        var text = (el.textContent || '').trim();
        var m = text.match(/(\\d+)/);
        if (m) { return parseInt(m[1], 10); }
        if (/99\\+|99/.test(text)) { return 99; }
        return 0;
      }

      function collectCount() {
        var total = 0;
        var seen = [];
        for (var s = 0; s < SELECTORS.length; s += 1) {
          var nodes = document.querySelectorAll(SELECTORS[s]);
          for (var i = 0; i < nodes.length; i += 1) {
            var el = nodes[i];
            if (seen.indexOf(el) >= 0) { continue; }
            seen.push(el);
            // 只统计可见且有数字（或有红点）的元素
            var style = window.getComputedStyle(el);
            if (style.display === 'none' || style.visibility === 'hidden') { continue; }
            total += pickNumber(el);
          }
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
      window.__pddDiagnose = function () {
        var out = { title: document.title, url: location.href, candidates: [] };
        var nodes = document.querySelectorAll('[class*="unread"],[class*="badge"],[class*="dot"],[class*="count"]');
        for (var i = 0; i < nodes.length && i < 15; i += 1) {
          out.candidates.push({
            cls: String(nodes[i].className || ''),
            text: (nodes[i].textContent || '').trim().slice(0, 16)
          });
        }
        out.count = collectCount();
        return JSON.stringify(out);
      };

      setInterval(report, 8000);
      setTimeout(report, 2500);
    })();
    """
}
