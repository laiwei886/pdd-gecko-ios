import Foundation
import WebKit

/// 把安卓端已有的 CSS/JS 注入到 WKWebView，复用同一套界面增强。
enum Injection {
    /// 注入顺序：样式在前、脚本在后，均在 documentEnd，保证页面 DOM 已就绪。
    static func scripts() -> [WKUserScript] {
        var result: [WKUserScript] = []

        let cssParts = [
            load("pdd-mobile", ext: "css"),
            load("pdd-mobile-drawer", ext: "css")
        ].compactMap { $0 }

        if !cssParts.isEmpty {
            let css = cssParts.joined(separator: "\n")
            let source = """
            (function () {
              var id = 'pdd-ios-style';
              var old = document.getElementById(id);
              if (old) { old.remove(); }
              var style = document.createElement('style');
              style.id = id;
              style.textContent = \(literal(css));
              (document.head || document.documentElement).appendChild(style);
            })();
            """
            result.append(WKUserScript(source: source,
                                       injectionTime: .atDocumentEnd,
                                       forMainFrameOnly: true))
        }

        if let js = load("pdd-mobile-drawer", ext: "js"), !js.isEmpty {
            result.append(WKUserScript(source: js,
                                       injectionTime: .atDocumentEnd,
                                       forMainFrameOnly: false))
        }

        // 与原生通信的小桥：页面侧可主动报告状态（预留）。
        let bridge = """
        (function () {
          if (window.__pddIosBridgeReady) { return; }
          window.__pddIosBridgeReady = true;
          window.pddNative = {
            openList: function () {
              document.body.classList.add('pdd-mobile-drawer');
            },
            closeList: function () {
              document.body.classList.remove('pdd-mobile-drawer');
            },
            isListOpen: function () {
              return document.body.classList.contains('pdd-mobile-drawer');
            }
          };
        })();
        """
        result.append(WKUserScript(source: bridge,
                                   injectionTime: .atDocumentEnd,
                                   forMainFrameOnly: false))
        return result
    }

    private static func load(_ name: String, ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// 把任意字符串转成合法的 JS 字符串字面量（含引号）。
    private static func literal(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let text = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return text
    }
}
