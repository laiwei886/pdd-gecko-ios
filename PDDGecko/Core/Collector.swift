import Foundation
import WebKit

/// 数据采集：在隐藏 WebView 里注入脚本，抓取会话/消息/未读并回传入库。
/// 所有选择器集中在此文件，页面改版只改这里。
enum Collector {

    // MARK: - 消息通道

    /// 每个 WebView 绑定一个 handler，带 accountId 回传。
    final class Bridge: NSObject, WKScriptMessageHandler {
        let accountId: String
        let onEvent: (String, String, Any) -> Void   // accountId, type, payload

        init(accountId: String, onEvent: @escaping (String, String, Any) -> Void) {
            self.accountId = accountId
            self.onEvent = onEvent
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "pddCollector" else { return }
            onEvent(accountId, message.name, message.body)
        }
    }

    // MARK: - 注入脚本

    /// 采集脚本：每 8 秒采集一次会话列表，结果 JSON 回传。
    /// 拼多多网页版会话结构（v1 选择器，改版后调整此处）：
    ///   会话项：.left-panel .chat-item
    ///   客户名：.chat-item .nickname-span / .nickname
    ///   最后消息：.chat-item .chat-message-content
    ///   未读：.chat-item [class*="unread"], [class*="badge"]
    static let conversationsScript = """
    (function () {
      if (window.__pddCollectConversations) { return; }
      window.__pddCollectConversations = true;

      function pick(el, selectors) {
        for (var i = 0; i < selectors.length; i++) {
          var n = el.querySelector(selectors[i]);
          if (n) { return (n.textContent || '').trim(); }
        }
        return '';
      }

      function unreadOf(item) {
        var total = 0;
        var nodes = item.querySelectorAll('[class*="unread"], [class*="badge"], [class*="red-dot"]');
        for (var i = 0; i < nodes.length; i++) {
          var m = (nodes[i].textContent || '').match(/(\\d+)/);
          if (m) { total += parseInt(m[1], 10); }
        }
        return total;
      }

      function collect() {
        var items = document.querySelectorAll('.left-panel .chat-item');
        var list = [];
        for (var i = 0; i < items.length; i++) {
          var el = items[i];
          var customer = pick(el, ['.nickname-span', '.nickname']);
          if (!customer) { continue; }
          var last = pick(el, ['.chat-message-content']);
          var time = '';
          var timeEl = el.querySelector('.chat-time');
          if (timeEl) { time = (timeEl.textContent || '').trim(); }
          list.push({
            customer: customer,
            lastMessage: last,
            lastTime: time,
            unread: unreadOf(el),
            index: i
          });
        }
        try {
          window.webkit.messageHandlers.pddCollector.postMessage({
            type: 'conversations',
            list: list
          });
        } catch (e) { /* 忽略 */ }
      }

      setInterval(collect, 8000);
      setTimeout(collect, 2500);
    })();
    """

    /// 注入到指定 WebView 的全部采集脚本。
    static func install(to configuration: WKWebViewConfiguration, bridge: Bridge) {
        configuration.userContentController.add(bridge, name: "pddCollector")
        configuration.userContentController.addUserScript(
            WKUserScript(source: conversationsScript,
                         injectionTime: .atDocumentEnd,
                         forMainFrameOnly: false)
        )
    }

    // MARK: - 解析与入库

    /// 处理采集回传：解析 JSON → 构造会话 → 入库（线程安全由调用方保证在主线程）。
    @MainActor
    static func handlePayload(_ body: Any, accountId: String, store: DataStore) {
        guard let obj = body as? [String: Any],
              let type = obj["type"] as? String,
              type == "conversations",
              let list = obj["list"] as? [[String: Any]] else { return }

        var result: [DataStore.Conversation] = []
        for (index, item) in list.enumerated() {
            let customer = item["customer"] as? String ?? ""
            if customer.isEmpty { continue }
            let last = item["lastMessage"] as? String ?? ""
            let time = item["lastTime"] as? String ?? ""
            let unread = (item["unread"] as? Int) ?? 0
            let id = "conv_\(accountId)_\(customer.hashValue)"
            result.append(DataStore.Conversation(
                id: id,
                accountId: accountId,
                customerName: customer,
                lastMessage: last,
                lastTime: time,
                unread: unread
            ))
        }
        store.upsertConversations(result)
    }
}
