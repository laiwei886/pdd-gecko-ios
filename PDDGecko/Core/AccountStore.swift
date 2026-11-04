import Foundation

/// 一个账号：id 同时作为 WKWebsiteDataStore 的 identifier（iOS 17+），保证多账号存储隔离。
struct Account: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var createdAt: Date
}

/// 账号列表与当前账号，持久化在 UserDefaults。
@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published private(set) var activeId: String?

    private let listKey = "pdd.accounts.v1"
    private let activeKey = "pdd.active.v1"

    init() {
        load()
    }

    var activeAccount: Account? {
        guard let activeId else { return nil }
        return accounts.first { $0.id == activeId }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: listKey),
           let saved = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = saved
        }
        activeId = UserDefaults.standard.string(forKey: activeKey)

        if accounts.isEmpty {
            let first = Account(id: UUID().uuidString, name: "账号1", createdAt: Date())
            accounts = [first]
            activeId = first.id
        }
        if activeId == nil || !accounts.contains(where: { $0.id == activeId }) {
            activeId = accounts.first?.id
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: listKey)
        }
        UserDefaults.standard.set(activeId, forKey: activeKey)
    }

    @discardableResult
    func add(name: String, activate: Bool = true) -> Account {
        let account = Account(id: UUID().uuidString, name: name, createdAt: Date())
        accounts.append(account)
        if activate {
            activeId = account.id
        }
        persist()
        return account
    }

    func rename(_ id: String, to name: String) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].name = name
        persist()
    }

    func remove(_ id: String) {
        accounts.removeAll { $0.id == id }
        if activeId == id {
            activeId = accounts.first?.id
        }
        if accounts.isEmpty {
            let fresh = Account(id: UUID().uuidString, name: "账号1", createdAt: Date())
            accounts = [fresh]
            activeId = fresh.id
        }
        persist()
    }

    func activate(_ id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        activeId = id
        persist()
    }
}
