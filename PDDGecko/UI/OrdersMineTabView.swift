import SwiftUI

/// 订单 Tab：官方样式（标题栏 + 横向页签 + 排序/筛选栏 + 空态）。
/// 阶段 C 接入订单采集数据；当前先呈现完整 UI 骨架。
struct OrdersTabView: View {
    @State private var tab = "近3个月订单"

    private let tabs = ["待付款", "待发货", "待收货", "退款售后", "近3个月订单", "3个月前订单"]

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("订单管理")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                Image(systemName: "magnifyingglass")
                Image(systemName: "square.grid.2x2")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // 横向页签
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(tabs, id: \.self) { name in
                        VStack(spacing: 6) {
                            Text(name)
                                .font(.system(size: 15, weight: tab == name ? .semibold : .regular))
                                .foregroundColor(tab == name ? .primary : .secondary)
                            Rectangle()
                                .fill(tab == name ? Color.primary : Color.clear)
                                .frame(width: 40, height: 2)
                        }
                        .onTapGesture { tab = name }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Divider() }

            // 排序/筛选栏
            HStack {
                HStack(spacing: 4) {
                    Text("最新下单在上")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("筛选")
                        .font(.system(size: 13))
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 12))
                }
                Text("批量备注")
                    .font(.system(size: 13))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(white: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            // 空态（阶段 C 用采集数据替换）
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44))
                    .foregroundColor(.blue.opacity(0.35))
                Text("还没有人购买过您的商品")
                    .font(.system(size: 15, weight: .medium))
                Text("订单采集接入后，这里显示订单卡片列表")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .background(Color(white: 0.97))
    }
}

/// 我的 Tab：店铺信息 + 指标 + 九宫格入口（对齐官方“我的”页）。
struct MineTabView: View {
    @EnvironmentObject private var accountStore: AccountStore

    private let metrics = [
        ("成长层级", "--"), ("店铺星级", "--"),
        ("评分分排名", "--"), ("服务体验分", "--")
    ]

    private let quickLinks = [
        ("售后订单", "arrow.uturn.left"),
        ("异常包裹", "exclamationmark.triangle"),
        ("官方打单", "printer"),
        ("订单申诉", "scale.3d"),
        ("工单管理", "list.bullet.rectangle"),
        ("商品体检", "stethoscope"),
        ("机会商品", "sparkles"),
        ("价格预警", "yensign.circle"),
        ("违规信息", "exclamationmark.octagon"),
        ("设置", "gearshape")
    ]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // 店铺头
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 46, height: 46)
                            .overlay(Text("店").font(.system(size: 18, weight: .medium)).foregroundColor(.green))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(accountStore.activeAccount?.name ?? "未登录")
                                .font(.system(size: 16, weight: .semibold))
                            Text("主账号")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("店铺主页")
                            .font(.system(size: 12))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.4)))
                    }
                    .padding()
                    .background(Color(white: 0.98))

                    // 指标行
                    HStack {
                        ForEach(metrics, id: \.0) { title, value in
                            VStack(spacing: 4) {
                                Text(value).font(.system(size: 14, weight: .medium))
                                Text(title).font(.system(size: 11)).foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 10)
                    .background(Color(white: 0.98))

                    // 快捷条
                    HStack {
                        quick("账户资金", icon: "creditcard")
                        Divider().frame(height: 30)
                        quick("官方招商", icon: "person.2")
                        Divider().frame(height: 30)
                        quick("官方客服", icon: "headphones")
                    }
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 九宫格
                    VStack(spacing: 14) {
                        ForEach(0..<2) { row in
                            HStack {
                                ForEach(0..<5) { col in
                                    let index = row * 5 + col
                                    if index < quickLinks.count {
                                        gridItem(quickLinks[index])
                                    } else {
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .background(Color(white: 0.98))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .background(Color(white: 0.95))
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    private func quick(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13)).foregroundColor(.red)
            Text(title).font(.system(size: 12)).foregroundColor(.red)
        }
        .frame(maxWidth: .infinity)
    }

    private func gridItem(_ item: (String, String)) -> some View {
        VStack(spacing: 6) {
            Image(systemName: item.1)
                .font(.system(size: 20))
                .foregroundColor(.primary)
            Text(item.0)
                .font(.system(size: 12))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}
