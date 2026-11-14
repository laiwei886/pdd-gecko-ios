import SwiftUI
import WebKit

/// 滑块安全验证面板：登录/操作触发验证时，把网页里的滑块弹层
/// 用同源 WebView 呈现给用户直接拖动，成功后自动关闭。
/// 用户手指操作真实滑块（合规），全程不跳出 App。
struct SliderVerifyView: View {
    let account: Account
    @EnvironmentObject private var pool: WebViewPool
    @Environment(\.dismiss) private var dismiss

    @State private var done = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Text("安全验证")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if done {
                        Label("验证通过", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(Color(white: 0.97))

                // 同源 WebView：共享 Cookie，页面定位到滑块区域
                VerifyWebView(account: account, pool: pool, onSuccess: {
                    withAnimation { done = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text("请按提示拖动滑块完成验证。验证通过后自动继续登录。")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(!done)
    }
}

/// 验证 WebView：共享该账号 dataStore（Cookie 相通），加载登录页并聚焦滑块弹层。
struct VerifyWebView: UIViewRepresentable {
    let account: Account
    let pool: WebViewPool
    let onSuccess: () -> Void

    class Coordinator {
        var timer: Timer?
        deinit { timer?.invalidate() }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        // 新建验证专用 WebView，但共享同一 dataStore（Cookie 一致）
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WebViewFactory.dataStore(for: account)
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = NavigationGuard.shared
        webView.load(URLRequest(url: WebViewFactory.loginURL))

        // 轮询检测：滑块消失（验证完成）时回调
        context.coordinator.timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
            webView.evaluateJavaScript(
                "document.querySelector('[class*=\"captcha\"], [class*=\"verify\"], [class*=\"slider\"]') === null"
            ) { result, _ in
                if let gone = result as? Bool, gone, !webView.isLoading {
                    onSuccess()
                }
            }
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
