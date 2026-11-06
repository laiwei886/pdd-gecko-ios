import SwiftUI
import WebKit
import AudioToolbox

/// 主界面：顶部账号栏 + 当前账号的 WKWebView。
struct ContentView: View {
    @StateObject private var store = AccountStore()
    @StateObject private var pool = WebViewPool()
    @StateObject private var network = NetworkMonitor()

    @State private var showAdd = false
    @State private var addName = ""
    @State private var renameTargetId: String?
    @State private var renameText = ""
    @State private var deleteTarget: Account?
    @State private var toast: String?
    @State private var listOpen = false
    @State private var moreMenu = false
    @State private var diagText = ""
    @State private var showDiag = false
    @State private var isOffline = false

    var body: some View {
        VStack(spacing: 0) {
            AccountBarView(
                store: store,
                unread: pool.unread,
                onAdd: {
                    addName = "账号\(store.accounts.count + 1)"
                    showAdd = true
                },
                onRename: { account in
                    renameTargetId = account.id
                    renameText = account.name
                },
                onDelete: { account in
                    deleteTarget = account
                },
                onBack: { handleBack() },
                onOrders: { handleOrders() },
                onMore: { moreMenu = true }
            )

            // 所有账号的 WebView 挂在同一个容器里（非当前账号透明度极低但仍在视图树），
            // 这样后台账号也能持续收消息，只在 chip 上显示未读数。
            ZStack {
                WebViewsHost(accounts: store.accounts, activeId: store.activeId, pool: pool)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isOffline {
                    offlineOverlay
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            pool.onNewMessage = {
                AudioServicesPlaySystemSound(1007)
            }
            network.onReconnect = {
                isOffline = false
                pool.reloadAll()
                showToast("网络已恢复，正在刷新")
            }
            if !network.online {
                isOffline = true
            }
        }
        .alert("未读检测诊断", isPresented: $showDiag) {
            Button("好", role: .cancel) {}
        } message: {
            Text(diagText)
        }
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.78))
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.opacity)
            }
        }
        .alert("新增账号", isPresented: $showAdd) {
            TextField("账号名称", text: $addName)
            Button("取消", role: .cancel) {}
            Button("确定") {
                let name = addName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let account = store.add(name: name)
                pool.loadLogin(for: account)
            }
        } message: {
            Text("起个名字，确定后会打开扫码登录页。")
        }
        .alert("重命名账号", isPresented: Binding(
            get: { renameTargetId != nil },
            set: { if !$0 { renameTargetId = nil } }
        )) {
            TextField("账号名称", text: $renameText)
            Button("取消", role: .cancel) { renameTargetId = nil }
            Button("保存") {
                if let id = renameTargetId {
                    store.rename(id, to: renameText.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                renameTargetId = nil
            }
        }
        .confirmationDialog(
            "删除该账号？",
            isPresented: Binding(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            ),
            presenting: deleteTarget
        ) { account in
            Button("确认删除", role: .destructive) {
                pool.remove(account.id)
                WebViewFactory.clearData(for: account)
                store.remove(account.id)
                listOpen = false
                deleteTarget = nil
            }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: { account in
            Text("将清除“\(account.name)”的登录状态与本地数据，其他账号不受影响。")
        }
        .confirmationDialog("更多操作", isPresented: $moreMenu, titleVisibility: .visible) {
            Button("订单") { handleOrders() }
            Button("转移会话") { tapSelector(".transfer-chat-item-btn", label: "转移会话") }
            Button("收藏/取消收藏") { tapSelector("[class*='collect'], [class*='star']", label: "收藏") }
            Button("加入黑名单") { tapSelector("[class*='black'], [class*='block']", label: "黑名单") }
            Button("备注") { tapSelector("[class*='remark'], [class*='note']", label: "备注") }
            Button("诊断未读检测") { diagnoseUnread() }
            Button("刷新页面") { reloadPage() }
            Button("取消", role: .cancel) {}
        }
        .onReceive(NotificationCenter.default.publisher(for: .pddBlockedNavigation)) { _ in
            showToast("已拦截 App 下载/外部跳转")
        }
        .onReceive(NotificationCenter.default.publisher(for: .pddNetworkError)) { note in
            if let error = note.object as? Error {
                let code = (error as NSError).code
                // 断网/超时类错误：显示离线提示，保留页面已有内容
                if code == NSURLErrorNotConnectedToInternet
                    || code == NSURLErrorNetworkConnectionLost
                    || code == NSURLErrorTimedOut
                    || code == NSURLErrorCannotFindHost
                    || code == NSURLErrorCannotConnectToHost {
                    isOffline = true
                } else {
                    showToast("网络异常：\(code)")
                }
            }
        }
    }

    /// 断网提示：半透明覆盖，页面已有内容仍可见，不白屏。
    private var offlineOverlay: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 34))
                    .foregroundColor(.white)
                Text("网络不可用")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("已保留上次内容，网络恢复后自动刷新")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
                Button("重试") {
                    isOffline = false
                    pool.reloadAll()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func toggleList() {
        guard let account = store.activeAccount,
              let webView = pool.existing(account.id) else { return }
        listOpen.toggle()
        let js = listOpen
            ? "document.body.classList.add('pdd-mobile-drawer');"
            : "document.body.classList.remove('pdd-mobile-drawer');"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// 订单入口：切换网页版的订单面板（与安卓壳同一套 class）。
    private func handleOrders() {
        guard let account = store.activeAccount,
              let webView = pool.existing(account.id) else { return }
        let js = """
        (function () {
          document.body.classList.toggle('pdd-mobile-orders');
          return document.body.classList.contains('pdd-mobile-orders');
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            let open = (result as? Bool) ?? false
            showToast(open ? "已打开订单" : "已关闭订单")
        }
    }

    /// 在网页里点击指定选择器；找不到就提示网页版不支持，避免静默失败。
    private func tapSelector(_ selector: String, label: String) {
        guard let account = store.activeAccount,
              let webView = pool.existing(account.id) else { return }
        let js = """
        (function () {
          try {
            var el = document.querySelector('\(selector)');
            if (!el) { return 'missing'; }
            el.click();
            return 'ok';
          } catch (e) {
            return 'error';
          }
        })();
        """
        webView.evaluateJavaScript(js) { result, _ in
            let status = (result as? String) ?? "missing"
            if status == "ok" {
                showToast("已执行：\(label)")
            } else {
                showToast("网页版没有“\(label)”入口")
            }
        }
    }

    private func reloadPage() {
        guard let account = store.activeAccount,
              let webView = pool.existing(account.id) else { return }
        webView.reload()
        showToast("已刷新")
    }

    /// 诊断：把页面里匹配到的未读候选元素回传，便于调整选择器。
    private func diagnoseUnread() {
        guard let account = store.activeAccount,
              let webView = pool.existing(account.id) else { return }
        let js = "window.__pddDiagnose ? window.__pddDiagnose() : '脚本未注入'"
        webView.evaluateJavaScript(js) { result, error in
            if let error {
                diagText = "执行失败：\(error.localizedDescription)"
            } else {
                diagText = String(describing: result ?? "无返回")
            }
            showDiag = true
        }
    }

    /// 顶部返回键：优先关会话列表，其次回会话列表，再次走浏览历史，最后回工作台。
    private func handleBack() {
        guard let account = store.activeAccount,
              let webView = pool.existing(account.id) else { return }
        let url = webView.url?.absoluteString ?? ""
        webView.evaluateJavaScript("document.body.classList.contains('pdd-mobile-drawer')") { result, _ in
            if let open = result as? Bool, open {
                webView.evaluateJavaScript("document.body.classList.remove('pdd-mobile-drawer')")
                listOpen = false
                return
            }
            if url.contains("chat-merchant") {
                webView.evaluateJavaScript("document.body.classList.add('pdd-mobile-drawer')")
                listOpen = true
                return
            }
            if webView.canGoBack {
                webView.goBack()
            } else if url.contains("/login") {
                webView.load(URLRequest(url: WebViewFactory.startURL))
            } else {
                webView.evaluateJavaScript("document.body.classList.add('pdd-mobile-drawer')")
                listOpen = true
            }
        }
    }

    private func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toast == text { toast = nil }
        }
    }
}

/// 把 WKWebView 放进 SwiftUI；同一个 WKWebView 实例可反复挂载，页面状态保留。
struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
