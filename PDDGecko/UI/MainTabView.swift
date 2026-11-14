import SwiftUI

/// 底部 TabBar：首页 / 聊天 / 订单 / 成长 / 我的（对齐官方布局）。
struct MainTabView: View {
    @State private var tab = 1   // 默认进聊天

    var body: some View {
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
    }
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
