import Foundation
import UserNotifications

/// 本地通知：未读数新增时弹出系统横幅（即使 App 在后台）。
@MainActor
final class Notifier: ObservableObject {
    static let shared = Notifier()

    /// 每账号上次已通知的未读数：避免重复弹同一条。
    private var lastNotified: [String: Int] = [:]
    private var authorized = false

    private init() {}

    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            Task { @MainActor in
                authorized = granted
                if let error {
                    Log.e("通知授权失败：\(error.localizedDescription)")
                }
                if granted {
                    // 后台也允许弹横幅
                    center.delegate = NotificationDelegate.shared
                }
            }
        }
    }

    /// 账号未读变化入口：只有“新增”才弹，且首次调用不弹（避免刚启动全量弹一遍）。
    func update(account: Account, unread: Int) {
        let previous = lastNotified[account.id]
        lastNotified[account.id] = unread

        guard authorized, let previous, unread > previous else { return }
        let increase = unread - previous

        let content = UNMutableNotificationContent()
        content.title = account.name
        let body = increase >= 99
            ? "有 \(increase) 条新消息"
            : "有 \(increase) 条新消息，点击查看"
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: unread)
        content.userInfo = ["accountId": account.id]

        let request = UNNotificationRequest(
            identifier: "pdd-\(account.id)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: nil    // 立即弹出
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// 清除某账号的角标（用户点开该账号后调用）。
    func clearBadge(for accountId: String) {
        lastNotified[accountId] = 0
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
}

/// 前台也显示横幅：默认 iOS 前台不弹，这里补上。
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
