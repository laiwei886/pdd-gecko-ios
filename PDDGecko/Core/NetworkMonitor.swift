import Foundation
import Network

/// 网络状态监听：断网时置离线，恢复时通知上层自动刷新。
@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var online = true

    /// 断网后恢复时回调（用于自动重载所有 WebView）。
    var onReconnect: (() -> Void)?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.pdd.gecko.network")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let reachable = (path.status == .satisfied)
            Task { @MainActor in
                guard let self else { return }
                let wasOffline = !self.online
                self.online = reachable
                if wasOffline && reachable {
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
    }
}
