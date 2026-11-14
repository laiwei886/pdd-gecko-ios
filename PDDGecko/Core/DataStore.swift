import Foundation
import SQLite3

/// 本地数据层：账号/会话/消息/订单摘要。启动先读缓存，采集到增量后写库并通知刷新。
@MainActor
final class DataStore: ObservableObject {
    static let shared = DataStore()

    /// 会话（按账号隔离）
    struct Conversation: Identifiable {
        let id: String          // 账号ID + 客户标识 哈希
        let accountId: String
        let customerName: String
        let lastMessage: String
        let lastTime: String
        let unread: Int
        var collectedAt: Date = Date()
    }

    /// 消息
    struct ChatMessage: Identifiable {
        let id: String          // accountId + conversationId + 序号
        let accountId: String
        let conversationId: String
        let direction: String   // "in" 买家 / "out" 客服
        let content: String
        let time: String
    }

    @Published private(set) var conversations: [Conversation] = []
    @Published private(set) var messages: [String: [ChatMessage]] = [:]   // key: conversationId

    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        dbPath = docs.appendingPathComponent("pdd_cache.sqlite").path
        openDatabase()
        createTables()
        loadCache()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - 基础

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        } else {
            Log.e("sqlite open failed")
        }
    }

    private func createTables() {
        exec("""
        CREATE TABLE IF NOT EXISTS conversations (
            id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            customer TEXT NOT NULL,
            last_message TEXT,
            last_time TEXT,
            unread INTEGER DEFAULT 0,
            collected_at REAL
        );
        """)
        exec("""
        CREATE TABLE IF NOT EXISTS messages (
            id TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            conversation_id TEXT NOT NULL,
            direction TEXT,
            content TEXT,
            time TEXT
        );
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_msg_conv ON messages(conversation_id);")
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: - 会话

    func upsertConversations(_ list: [Conversation]) {
        let stmt = prepare("""
        INSERT OR REPLACE INTO conversations
        (id, account_id, customer, last_message, last_time, unread, collected_at)
        VALUES (?,?,?,?,?,?,?);
        """)
        for c in list {
            bindText(stmt, 1, c.id)
            bindText(stmt, 2, c.accountId)
            bindText(stmt, 3, c.customerName)
            bindText(stmt, 4, c.lastMessage)
            bindText(stmt, 5, c.lastTime)
            sqlite3_bind_int(stmt, 6, Int32(c.unread))
            sqlite3_bind_double(stmt, 7, c.collectedAt.timeIntervalSince1970)
            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }
        sqlite3_finalize(stmt)
        reloadConversations()
    }

    private func reloadConversations() {
        let stmt = prepare("SELECT id, account_id, customer, last_message, last_time, unread FROM conversations ORDER BY collected_at DESC;")
        var list: [Conversation] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = columnText(stmt, 0)
            let acc = columnText(stmt, 1)
            let customer = columnText(stmt, 2)
            let last = columnText(stmt, 3)
            let time = columnText(stmt, 4)
            let unread = Int(sqlite3_column_int(stmt, 5))
            list.append(Conversation(id: id, accountId: acc, customerName: customer,
                                     lastMessage: last, lastTime: time, unread: unread))
        }
        sqlite3_finalize(stmt)
        conversations = list
    }

    // MARK: - 消息

    func replaceMessages(accountId: String, conversationId: String, list: [ChatMessage]) {
        exec("DELETE FROM messages WHERE conversation_id='\(escape(conversationId))';")
        let stmt = prepare("""
        INSERT OR REPLACE INTO messages (id, account_id, conversation_id, direction, content, time)
        VALUES (?,?,?,?,?,?);
        """)
        for m in list {
            bindText(stmt, 1, m.id)
            bindText(stmt, 2, m.accountId)
            bindText(stmt, 3, m.conversationId)
            bindText(stmt, 4, m.direction)
            bindText(stmt, 5, m.content)
            bindText(stmt, 6, m.time)
            sqlite3_step(stmt)
            sqlite3_reset(stmt)
        }
        sqlite3_finalize(stmt)
        messages[conversationId] = list
    }

    func messages(for conversationId: String) -> [ChatMessage] {
        if let cached = messages[conversationId] { return cached }
        let stmt = prepare("""
        SELECT id, account_id, direction, content, time FROM messages
        WHERE conversation_id='\(escape(conversationId))' ORDER BY rowid ASC;
        """)
        var list: [ChatMessage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = columnText(stmt, 0)
            let acc = columnText(stmt, 1)
            let dir = columnText(stmt, 2)
            let content = columnText(stmt, 3)
            let time = columnText(stmt, 4)
            list.append(ChatMessage(id: id, accountId: acc, conversationId: conversationId,
                                    direction: dir, content: content, time: time))
        }
        sqlite3_finalize(stmt)
        messages[conversationId] = list
        return list
    }

    private func loadCache() {
        reloadConversations()
    }

    // MARK: - sqlite helpers

    private func prepare(_ sql: String) -> OpaquePointer? {
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        return stmt
    }

    private func bindText(_ stmt: OpaquePointer?, _ index: Int32, _ text: String) {
        sqlite3_bind_text(stmt, index, text, -1, SQLITE_TRANSIENT)
    }

    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String {
        if let c = sqlite3_column_text(stmt, index) {
            return String(cString: c)
        }
        return ""
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "''")
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// 简易日志
enum Log {
    static func e(_ text: String) {
        NSLog("[PddData] %@", text)
    }
}
