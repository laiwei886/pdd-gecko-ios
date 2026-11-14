import SwiftUI

/// 底部 TabBar：首页 / 聊天 / 订单 / 成长 / 我的（对齐官方布局）。
struct MainTabView: View {
    @State private var tab = 1   // 默认进聊天
    @State private var showWebView = false

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                HomeTabView()
                    .tabItem { Label("首页", systemImage: "house") }
                    .tag(0)
                ChatTabView()
                    .tabItem { Label("聊天", systemImage: "bubble.left.and.bubble.right") }
                    .tag(1)
                OrdersTabView()
                    .tabItem { Label("订单", systemImage: "doc.text") }
                    .tag(2)
                GrowthTabView()
                    .tabItem { Label("成长", systemImage: "chart.bar") }
                    .tag(3)
                MineTabView()
                    .tabItem { Label("我的", systemImage: "person") }
                    .tag(4)
            }
            .tint(.red)

            // 账号 chip 固定悬浮在 TabView 之上（所有页可见），
            // 点 chip 切账号，点 🌐 打开网页版入口。
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    AccountChips()
                    Button(action: { showWebView = true }) {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .frame(width: 30, height: 26)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.top, 4)
                Spacer()
            }
        }
        .sheet(isPresented: $showWebView) {
            WebViewScreen()
        }
    }
}

/// 账号 chip 行（悬浮，含未读红点）。
struct AccountChips: View {
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var pool: WebViewPool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
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
                        .frame(height: 26)
                        .background(active ? Color.blue : Color(white: 0.95).opacity(0.95))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    // 新增账号：直接打开网页版登录页
                    NotificationCenter.default.post(name: .pddAddAccount, object: nil)
                    NotificationCenter.default.post(name: .pddOpenWebView, object: nil)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .frame(width: 26, height: 26)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

extension Notification.Name {
    static let pddAddAccount = Notification.Name("pdd.addAccount")
    static let pddOpenWebView = Notification.Name("pdd.openWebView")
}

/// 首页：聚合卡片（后续阶段填充真实数据）。
struct HomeTabView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    infoCard(title: "今日需接待", value: "—", hint: "来自网页采集")
                    infoCard(title: "待发货订单", value: "—", hint: "来自订单采集")
                    infoCard(title: "未读消息", value: "—", hint: "所有账号合计")
                }
                .padding()
            }
            .navigationTitle("首页")
        }
        .navigationViewStyle(.stack)
    }

    private func infoCard(title: String, value: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 13)).foregroundColor(.gray)
            Text(value).font(.system(size: 24, weight: .semibold))
            Text(hint).font(.system(size: 11)).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(white: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// 成长页：占位（低频）。
struct GrowthTabView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            Text("成长中心")
                .font(.system(size: 15, weight: .medium))
            Text("后续版本接入店铺成长数据")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
