import SwiftUI
import WebKit

/// 主界面：顶部账号栏 + 当前账号的 WKWebView。
struct ContentView: View {
    @StateObject private var store = AccountStore()
    @StateObject private var pool = WebViewPool()

    @State private var showAdd = false
    @State private var addName = ""
    @State private var renameTargetId: String?
    @State private var renameText = ""
    @State private var deleteTarget: Account?
    @State private var toast: String?
    @State private var listOpen = false

    var body: some View {
        VStack(spacing: 0) {
            AccountBarView(
                store: store,
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
                onToggleList: { toggleList() },
                onBack: { handleBack() }
            )

            ZStack(alignment: .leading) {
                content
                // 屏幕左边缘 20pt 手势区：右滑打开/关闭会话列表，不干扰页面滚动
                Color.clear
                    .frame(width: 20)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onEnded { value in
                                if value.translation.width > 60 {
                                    toggleList()
                                }
                            }
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.white)
        .ignoresSafeArea(.keyboard, edges: .bottom)
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
        .onReceive(NotificationCenter.default.publisher(for: .pddBlockedNavigation)) { _ in
            showToast("已拦截 App 下载/外部跳转")
        }
        .onReceive(NotificationCenter.default.publisher(for: .pddNetworkError)) { note in
            if let error = note.object as? Error {
                showToast("网络异常：\((error as NSError).code)")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let account = store.activeAccount {
            WebViewContainer(webView: pool.view(for: account))
                .id(account.id)
        } else {
            VStack(spacing: 8) {
                ProgressView()
                Text("正在准备账号…").font(.system(size: 13)).foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
