import SwiftUI
import WebKit
import AudioToolbox

/// 网页视图页：挂在“聊天”Tab 内作为数据层入口（隐藏 WebView 仍需可见才能活跃）。
/// 用户点账号 chip 或“更多”时切换到此页；日常聊天用原生界面。
struct WebViewScreen: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var pool: WebViewPool
    @StateObject private var network = NetworkMonitor()

    @State private var showAdd = false
    @State private var addName = ""
    @State private var renameTargetId: String?
    @State private var renameText = ""
    @State private var deleteTarget: Account?
    @State private var toast: String?
    @State private var moreMenu = false
    @State private var diagText = ""
    @State private var showDiag = false
    @State private var isOffline = false
    @State private var showPasswordLogin = false
    @State private var loginAccount: Account?

    var body: some View {
        VStack(spacing: 0) {
            AccountBarView(
                store: accountStore,
                unread: pool.unread,
                onAdd: {
                    addName = "账号\(accountStore.accounts.count + 1)"
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

            ZStack {
                WebViewsHost(accounts: accountStore.accounts,
                             activeId: accountStore.activeId,
                             pool: pool)
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
            Notifier.shared.requestAuthorization()
            for account in accountStore.accounts {
                DataStore.shared.registerAccountName(id: account.id, name: account.name)
                _ = pool.view(for: account)
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
        .onReceive(NotificationCenter.default.publisher(for: .pddAddAccount)) { _ in
            addName = "账号\(accountStore.accounts.count + 1)"
            showAdd = true
        }
        .alert("新增账号", isPresented: $showAdd) {
            TextField("账号名称", text: $addName)
            Button("取消", role: .cancel) {}
            Button("确定") {
                let name = addName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                let account = accountStore.add(name: name)
                pool.loadLogin(for: account)
                loginAccount = account
                showPasswordLogin = true
            }
        } message: {
            Text("起个名字，确定后进入账号密码登录。")
        }
        .sheet(isPresented: $showPasswordLogin) {
            if let account = loginAccount {
                PasswordLoginView(account: account)
                    .environmentObject(pool)
            }
        }
        .alert("重命名账号", isPresented: Binding(
            get: { renameTargetId != nil },
            set: { if !$0 { renameTargetId = nil } }
        )) {
            TextField("账号名称", text: $renameText)
            Button("取消", role: .cancel) { renameTargetId = nil }
            Button("保存") {
                if let id = renameTargetId {
                    accountStore.rename(id, to: renameText.trimmingCharacters(in: .whitespacesAndNewlines))
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
                accountStore.remove(account.id)
                deleteTarget = nil
            }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: { account in
            Text("将清除“\(account.name)”的登录状态与本地数据，其他账号不受影响。")
        }
        .alert("未读检测诊断", isPresented: $showDiag) {
            Button("好", role: .cancel) {}
        } message: {
            Text(diagText)
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

    private func handleBack() {
        guard let account = accountStore.activeAccount,
              let webView = pool.existing(account.id) else { return }
        let url = webView.url?.absoluteString ?? ""
        webView.evaluateJavaScript("document.body.classList.contains('pdd-mobile-drawer')") { result, _ in
            if let open = result as? Bool, open {
                webView.evaluateJavaScript("document.body.classList.remove('pdd-mobile-drawer')")
                return
            }
            if url.contains("chat-merchant") {
                webView.evaluateJavaScript("document.body.classList.add('pdd-mobile-drawer')")
                return
            }
            if webView.canGoBack {
                webView.goBack()
            } else if url.contains("/login") {
                webView.load(URLRequest(url: WebViewFactory.startURL))
            } else {
                webView.evaluateJavaScript("document.body.classList.add('pdd-mobile-drawer')")
            }
        }
    }

    private func handleOrders() {
        guard let account = accountStore.activeAccount,
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

    private func tapSelector(_ selector: String, label: String) {
        guard let account = accountStore.activeAccount,
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
        guard let account = accountStore.activeAccount,
              let webView = pool.existing(account.id) else { return }
        webView.reload()
        showToast("已刷新")
    }

    private func diagnoseUnread() {
        guard let account = accountStore.activeAccount,
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

    private func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if toast == text { toast = nil }
        }
    }
}

/// 主界面（阶段 A）：TabView 骨架 + 账号栏入口。
struct ContentView: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var pool: WebViewPool
    @State private var showWebViewScreen = false

    var body: some View {
        VStack(spacing: 0) {
            // 账号栏固定在顶部：切账号 / 新增 / 数据层入口
            HStack(spacing: 8) {
                ForEach(accountStore.accounts) { account in
                    let active = account.id == accountStore.activeId
                    Button(action: { accountStore.activate(account.id) }) {
                        HStack(spacing: 4) {
                            Text(account.name)
                                .font(.system(size: 13, weight: active ? .semibold : .regular))
                                .foregroundColor(active ? .white : Color(white: 0.2))
                            let unread = pool.unread[account.id] ?? 0
                            if unread > 0 {
                                Text(unread > 99 ? "99+" : "\(unread)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .frame(minWidth: 16, minHeight: 16)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(active ? Color.blue : Color(white: 0.95))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { showWebViewScreen = true }) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 28)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开网页版")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white)
            .overlay(alignment: .bottom) { Divider() }

            // 隐藏数据层的宿主：保持在窗口里，保证采集与登录态活跃
            WebViewsHost(accounts: accountStore.accounts,
                         activeId: accountStore.activeId,
                         pool: pool)
                .frame(width: 0, height: 0)
                .opacity(0.001)

            Spacer()
        }
        .background(Color.white)
        .sheet(isPresented: $showWebViewScreen) {
            WebViewScreen()
        }
    }
}
