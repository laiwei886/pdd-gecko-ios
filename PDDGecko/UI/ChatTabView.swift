import SwiftUI
import WebKit

/// 原生聊天 Tab：官方样式的三页签 + 通知入口行 + 会话列表。
/// 聊天页从本地渲染图片（ImageStore），断网完整可用。
struct ChatTabView: View {
    @ObservedObject var store = DataStore.shared
    @EnvironmentObject var accountStore: AccountStore
    @EnvironmentObject var pool: WebViewPool
    @EnvironmentObject var images: ImageStore

    @State private var tab = "today"   // today / all / fav
    @State private var selectedConversation: DataStore.Conversation?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerBar
                notifyRow
                tabRow
                Divider()
                conversationList
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(item: $selectedConversation) { conversation in
            NativeChatView(conversation: conversation)
        }
    }

    // MARK: - 顶部：账号名 + 搜索/管理图标（对齐官方）

    private var headerBar: some View {
        HStack(spacing: 8) {
            Text(accountStore.activeAccount?.name ?? "未登录")
                .font(.system(size: 17, weight: .semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 11))
                .foregroundColor(.gray)
            Spacer()
            Image(systemName: "magnifyingglass")
                .foregroundColor(.primary)
            Image(systemName: "gearshape")
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - 通知入口行（四项，红点来自采集）

    private var notifyRow: some View {
        HStack(spacing: 0) {
            notifyItem("doc.text", title: "订单通知")
            notifyItem("storefront", title: "店铺预警")
            notifyItem("speaker.wave.2", title: "官方通知")
            notifyItem("envelope", title: "站内信")
        }
        .padding(.vertical, 10)
        .background(Color(white: 0.97))
    }

    private func notifyItem(_ icon: String, title: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundColor(.primary)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 三页签

    private var tabRow: some View {
        HStack(spacing: 0) {
            tabItem("今日需接待", key: "today")
            tabItem("全部会话", key: "all")
            tabItem("收藏会话", key: "fav")
        }
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func tabItem(_ title: String, key: String) -> some View {
        Button(action: { tab = key }) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: tab == key ? .semibold : .regular))
                    .foregroundColor(tab == key ? .primary : .secondary)
                Rectangle()
                    .fill(tab == key ? Color.primary : Color.clear)
                    .frame(width: 36, height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - 会话列表

    private var conversationList: some View {
        let all = store.conversations.filter { $0.accountId == accountStore.activeId }
        let list = filtered(all)
        return Group {
            if list.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(list) { conversation in
                        Button(action: { selectedConversation = conversation }) {
                            row(conversation)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func filtered(_ list: [DataStore.Conversation]) -> [DataStore.Conversation] {
        switch tab {
        case "today":
            return list.filter { $0.unread > 0 || $0.lastTime.contains(":") }
        case "fav":
            return list.filter { $0.unread > 0 }   // 收藏采集接入前的近似
        default:
            return list
        }
    }

    private func row(_ conversation: DataStore.Conversation) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.blue.opacity(0.12))
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
                Text(conversation.lastTime)
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
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundColor(.blue.opacity(0.35))
            Text("暂无会话")
                .font(.system(size: 16, weight: .medium))
            Text("登录账号后，采集到的会话会显示在这里")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.98))
    }
}

/// 原生聊天页：气泡 + 本地图片渲染 + 发送框（阶段 D 接真实发送）。
struct NativeChatView: View {
    let conversation: DataStore.Conversation
    @ObservedObject private var store = DataStore.shared
    @EnvironmentObject private var images: ImageStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            messageList
            inputBar
        }
        .background(Color(white: 0.96))
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

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                let list = store.messages(for: conversation.id)
                LazyVStack(spacing: 6) {
                    ForEach(Array(list.enumerated()), id: \.element.id) { _, message in
                        bubble(message)
                    }
                    if list.isEmpty {
                        VStack(spacing: 6) {
                            Text("暂无消息缓存")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                            Text("进入网页版会话后自动采集")
                                .font(.system(size: 11))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical, 10)
                .onChange(of: list.count) { _ in
                    if let last = list.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: DataStore.ChatMessage) -> some View {
        let isOut = message.direction == "out"
        HStack {
            if isOut { Spacer(minLength: 60) }
            VStack(alignment: isOut ? .trailing : .leading, spacing: 2) {
                if message.content.isEmpty {
                    // 无文本：尝试本地图片
                    LocalImage(message: message, images: images)
                        .frame(maxWidth: 220, maxHeight: 220)
                } else {
                    Text(message.content)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(isOut ? Color.blue.opacity(0.9) : Color.white)
                        .foregroundColor(isOut ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Text(message.time)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            if !isOut { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 10)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("发送功能将在阶段 D 接入", text: $draft)
                .font(.system(size: 14))
                .padding(10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Button(action: {}) {
                Text("发送")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(true)
        }
        .padding(10)
        .background(Color(white: 0.97))
    }
}

/// 从 ImageStore 读本地图片；没有就占位并入队下载。
struct LocalImage: View {
    let message: DataStore.ChatMessage
    @ObservedObject var images: ImageStore

    @State private var path: URL?

    var body: some View {
        Group {
            if let path {
                Image(uiImage: UIImage(contentsOfFile: path.path) ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                    Text("图片待缓存")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .frame(width: 160, height: 110)
                .background(Color(white: 0.92))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onAppear {
                    // 消息内容里若存了 URL 则请求下载
                    if let url = message.imageURL {
                        images.request(url) { local in
                            path = local
                        }
                    }
                }
            }
        }
    }
}

extension DataStore.ChatMessage {
    /// 阶段 A′ 采集时把图片 URL 存进 content 前缀（img:开头）；UI 侧拆开。
    var imageURL: String? {
        content.hasPrefix("img:") ? String(content.dropFirst(4)) : nil
    }
}
