import SwiftUI

/// 原生账号密码登录页：填 Apple 风格的表单，提交后在隐藏 WebView 里代填并触发登录。
/// 密码不落盘、不上传，只在本轮内存中使用。
struct PasswordLoginView: View {
    let account: Account
    @EnvironmentObject private var pool: WebViewPool
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var password = ""
    @State private var status: String = ""
    @State private var busy = false
    @State private var showSliderVerify = false

    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                    .padding(.top, 30)

                Text("账号密码登录")
                    .font(.system(size: 18, weight: .semibold))
                Text("为“\(account.name)”登录拼多多商家账号")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                VStack(alignment: .leading, spacing: 6) {
                    Text("账号（手机号/邮箱/用户名）")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    TextField("请输入账号", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("密码")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    SecureField("请输入密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal, 24)

                if !status.isEmpty {
                    Text(status)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                Button(action: { submit() }) {
                    HStack {
                        if busy { ProgressView().tint(.white) }
                        Text(busy ? "登录中…" : "登录")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(username.isEmpty || password.isEmpty || busy ? Color.gray : Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 24)
                .disabled(username.isEmpty || password.isEmpty || busy)

                // 滑块验证面板：出现时全屏覆盖，App 内直接拖动
                if showSliderVerify {
                    SliderVerifyView(account: account)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.opacity)
                }

                VStack(spacing: 4) {
                    Text("密码仅用于本次在网页登录框中代填，")
                    Text("不会保存到设备，也不会上传到任何第三方。")
                }
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(busy)
    }

    /// 提交：把账号密码注入隐藏 WebView 的登录表单并点击登录。
    private func submit() {
        guard let webView = pool.existing(account.id) else {
            status = "登录通道未就绪，请稍后重试"
            return
        }
        busy = true
        status = "正在填写表单…"

        let escapedUser = username.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let escapedPass = password.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function () {
          function findInput(selectors) {
            for (var i = 0; i < selectors.length; i++) {
              var els = document.querySelectorAll(selectors[i]);
              for (var j = 0; j < els.length; j++) {
                var el = els[j];
                var r = el.getBoundingClientRect();
                if (r.width > 0 && r.height > 0 && el.type !== 'hidden') { return el; }
              }
            }
            return null;
          }
          var user = findInput(['input[name="username"]', 'input[placeholder*="账号"]', 'input[placeholder*="手机"]', 'input[placeholder*="邮箱"]', 'input[type="text"]']);
          var pass = findInput(['input[type="password"]']);
          if (!user || !pass) { return 'noform'; }
          function setNative(el, value) {
            var proto = Object.getPrototypeOf(el);
            var desc = Object.getOwnPropertyDescriptor(proto, 'value');
            desc.set.call(el, value);
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          }
          setNative(user, '\(escapedUser)');
          setNative(pass, '\(escapedPass)');
          setTimeout(function () {
            var btn = document.querySelector('button[type="submit"], .login-btn, [class*="login-btn"], button');
            if (btn) { btn.click(); }
          }, 300);
          return 'submitted';
        })();
        """

        // 确保在登录页
        if webView.url?.absoluteString.contains("/login") != true {
            webView.load(URLRequest(url: WebViewFactory.loginURL))
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            webView.evaluateJavaScript(js) { result, error in
                if let error {
                    busy = false
                    status = "执行失败：\(error.localizedDescription)"
                    return
                }
                let value = (result as? String) ?? "unknown"
                switch value {
                case "submitted":
                    // 提交后轮询检测滑块：出现则弹出内嵌验证面板（App 内拖动）
                    status = "已提交，检测安全验证…"
                    pollForSlider()
                case "noform":
                    busy = false
                    status = "未找到登录表单，请点“重试”"
                default:
                    busy = false
                    status = "未知返回：\(value)"
                }
            }
        }
    }

    /// 轮询检测滑块弹层：出现 → 弹出内嵌验证面板；登录成功 → 关闭全部。
    private func pollForSlider() {
        guard let webView = pool.existing(account.id) else {
            busy = false
            return
        }
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            attempts += 1
            webView.evaluateJavaScript(
                "document.querySelector('[class*=\"captcha\"], [class*=\"verify\"], [class*=\"slider\"]') !== null"
            ) { result, _ in
                let hasSlider = (result as? Bool) ?? false
                let url = webView.url?.absoluteString ?? ""
                let loggedIn = url.contains("chat-merchant")

                if loggedIn {
                    timer.invalidate()
                    busy = false
                    status = "登录成功"
                    dismiss()
                    return
                }
                if hasSlider {
                    timer.invalidate()
                    status = "需要安全验证"
                    showSliderVerify = true
                    return
                }
                if attempts > 20 {
                    timer.invalidate()
                    busy = false
                    status = "未检测到登录结果，请重试或用 🌐 网页版"
                }
            }
        }
    }
}
