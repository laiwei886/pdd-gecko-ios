import SwiftUI

/// 聊天 Tab：原生会话列表（数据来自本地缓存），离线也可浏览。
struct ChatTabView: View {
    @ObservedObject var store = DataStore.shared
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var pool: WebViewPool

    @State private var selectedConversation: DataStore.Conversation?

    var body: some View {
        NavigationView {
            Group {
                if store.conversations.isEmpty {
                    emptyState
                } else {
                    conversationList
                }
            }
            .navigationTitle("聊天")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .sheet(item: $selectedConversation) { conversation in
            NativeChatView(conversation: conversation)
        }
    }

    private var conversationList: some View {
        List {
            ForEach(store.conversations.filter { $0.accountId == accountStore.activeId }) { conversation in
                Button(action: { selectedConversation = conversation }) {
                    conversationRow(conversation)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
        }
        .listStyle(.plain)
    }

    private func conversationRow(_ conversation: DataStore.Conversation) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(conversation.customerName.prefix(1)))
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(conversation.customerName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(conversation.lastMessage.isEmpty ? "…" : conversation.lastMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(conversation.lastTime.isEmpty ? "" : conversation.lastTime)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                if conversation.unread > 0 {
                    Text(conversation.unread > 99 ? "99+" : "\(conversation.unread)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text("暂无会话")
                .font(.system(size: 15, weight: .medium))
            Text("登录账号后，网页采集的会话会显示在这里")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 原生聊天页（阶段 A 先展示缓存消息；阶段 D 接发送）。
struct NativeChatView: View {
    let conversation: DataStore.Conversation
    @ObservedObject private var store = DataStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                messageList
                inputBar
            }
            .navigationTitle(conversation.customerName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                let list = store.messages(for: conversation.id)
                ForEach(Array(list.enumerated()), id: \.element.id) { index, message in
                    bubble(message)
                        .id(message.id)
                        .onAppear {
                            if index == list.count - 1 {
                                proxy.scrollTo(message.id, anchor: .bottom)
                            }
                        }
                }
                if list.isEmpty {
                    Text("暂无消息缓存，进入网页版会话后自动采集")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(.top, 30)
                }
            }
            .background(Color(white: 0.96))
        }
    }

    private func bubble(_ message: DataStore.ChatMessage) -> some View {
        let isOut = message.direction == "out"
        return HStack {
            if isOut { Spacer(minLength: 50) }
            Text(message.content.isEmpty ? "[卡片/图片]" : message.content)
                .font(.system(size: 14))
                .padding(10)
                .background(isOut ? Color.blue.opacity(0.9) : Color.white)
                .foregroundColor(isOut ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if !isOut { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var inputBar: some View {
        HStack {
            Text("发送功能将在阶段 D 接入")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Spacer()
        }
        .padding()
        .background(Color(white: 0.97))
    }
}

/// 订单 Tab：阶段 C 接入真实数据，先展示骨架与缓存。
struct OrdersTabView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                tabBar
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("订单管理")
                        .font(.system(size: 15, weight: .medium))
                    Text("阶段 C 接入订单采集与列表")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }

    /// 仿官方横向页签（阶段 C 填充数据）
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(["待付款", "待发货", "待收货", "退款售后", "近3个月订单"], id: \.self) { name in
                    Text(name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.white)
        .overlay(alignment: .bottom) { Divider() }
    }
}

/// 我的 Tab：阶段 C 接入店铺信息，先展示骨架。
struct MineTabView: View {
    @EnvironmentObject var accountStore: AccountStore

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("当前账号")
                                .font(.system(size: 15, weight: .semibold))
                            Text(accountStore.activeAccount?.name ?? "未登录")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(white: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 0) {
                        ForEach(["售后订单", "异常包裹", "官方打单", "订单申诉", "工单管理", "商品体检", "设置"], id: \.self) { name in
                            HStack {
                                Text(name).font(.system(size: 14))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 12)
                            Divider()
                        }
                    }
                    .padding(.horizontal)
                    .background(Color(white: 0.97))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("我的")
        }
        .navigationViewStyle(.stack)
    }
}
