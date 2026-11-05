import SwiftUI

/// 顶部账号栏：返回按钮 + 账号 chip + 加号 + 会话按钮。
struct AccountBarView: View {
    @ObservedObject var store: AccountStore
    var onAdd: () -> Void
    var onRename: (Account) -> Void
    var onDelete: (Account) -> Void
    var onToggleList: () -> Void
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Text("←")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 34, height: 28)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("返回")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.accounts) { account in
                        chip(for: account)
                    }
                }
                .padding(.vertical, 4)
            }

            Button(action: onAdd) {
                Text("＋账号")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button(action: onToggleList) {
                Text("会话")
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Color.blue.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func chip(for account: Account) -> some View {
        let active = account.id == store.activeId
        return Button(action: { store.activate(account.id) }) {
            Text(account.name)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundColor(active ? .white : Color(white: 0.2))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(active ? Color.blue : Color(white: 0.95))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("重命名") { onRename(account) }
            Button("删除账号", role: .destructive) { onDelete(account) }
        }
    }
}
