import SwiftUI

@main
struct PDDGeckoApp: App {
    @StateObject private var accountStore = AccountStore()
    @StateObject private var pool = WebViewPool()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(accountStore)
                .environmentObject(pool)
                .preferredColorScheme(.light)
                .onAppear {
                    // 隐藏数据层预热：为当前账号创建 WebView（采集登录态与数据）
                    if let active = accountStore.activeAccount {
                        _ = pool.view(for: active)
                    }
                }
        }
    }
}
