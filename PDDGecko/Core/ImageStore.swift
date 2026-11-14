import Foundation
import CryptoKit

/// 图片本地缓存：URL → 本地文件。下载队列并发 3、失败重试 3 次、LRU 上限清理。
@MainActor
final class ImageStore: ObservableObject {
    static let shared = ImageStore()

    /// 供 UI 观察下载状态变化（占位图 → 已就绪）
    @Published private(set) var revision = 0

    private let cacheDir: URL
    private let maxBytes: Int64 = 500 * 1024 * 1024   // 500MB 上限
    private var queue: [String] = []
    private var inFlight: Set<String> = []
    private var failures: [String: Int] = [:]
    private let maxConcurrent = 3
    private let maxRetry = 3

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = caches.appendingPathComponent("pdd_images", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - 路径与状态

    private func localPath(for url: String) -> URL {
        let digest = Insecure.MD5.hash(data: Data(url.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return cacheDir.appendingPathComponent(hex)
    }

    /// 是否已有本地文件。
    func isAvailable(_ url: String) -> Bool {
        FileManager.default.fileExists(atPath: localPath(for: url).path)
    }

    /// 本地文件 URL（供 UI 直接读）。
    func localURL(for url: String) -> URL? {
        isAvailable(url) ? localPath(for: url) : nil
    }

    /// 请求图片：有本地文件直接回调；没有则排队下载。
    func request(_ url: String, completion: ((URL?) -> Void)? = nil) {
        guard url.lowercased().hasPrefix("http") else {
            completion?(nil)
            return
        }
        if isAvailable(url) {
            completion?(localPath(for: url))
            return
        }
        let tries = failures[url] ?? 0
        if tries >= maxRetry {
            completion?(nil)
            return
        }
        if !queue.contains(url) && !inFlight.contains(url) {
            queue.append(url)
        }
        pendingCompletions[url, default: []].append(completion)
        pump()
    }

    private var pendingCompletions: [String: [(URL?) -> Void]] = [:]

    // MARK: - 下载队列

    private func pump() {
        while inFlight.count < maxConcurrent, !queue.isEmpty {
            let url = queue.removeFirst()
            inFlight.insert(url)
            download(url)
        }
    }

    private func download(_ url: String) {
        guard let requestURL = URL(string: url) else {
            finish(url, success: false)
            return
        }
        var request = URLRequest(url: requestURL, timeoutInterval: 30)
        request.setValue("https://mms.pinduoduo.com/", forHTTPHeaderField: "Referer")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self else { return }
                if let data, let response,
                   (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty {
                    let path = self.localPath(for: url)
                    try? data.write(to: path)
                    self.finish(url, success: true)
                } else {
                    self.finish(url, success: false)
                }
            }
        }.resume()
    }

    private func finish(_ url: String, success: Bool) {
        inFlight.remove(url)
        if success {
            failures[url] = 0
        } else {
            failures[url, default: 0] += 1
        }
        let completions = pendingCompletions[url] ?? []
        pendingCompletions[url] = nil
        let path: URL? = success ? localPath(for: url) : nil
        for completion in completions {
            completion?(path)
        }
        revision += 1
        pump()
        if success { trimIfNeeded() }
    }

    // MARK: - 容量管理（LRU）

    /// 缓存总量（字节）。
    func totalBytes() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey])) ?? []
        return files.reduce(Int64(0)) { total, file in
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }

    /// 超限时按访问时间淘汰最旧文件。
    func trimIfNeeded() {
        var total = totalBytes()
        guard total > maxBytes else { return }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: [.contentAccessDateKey, .fileSizeKey])) ?? []
        let sorted = files.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
            return da < db
        }
        for file in sorted {
            if total <= maxBytes { break }
            let size = Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            try? FileManager.default.removeItem(at: file)
            total -= size
        }
    }

    /// 诊断信息。
    func stats() -> String {
        let files = (try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? []
        return "缓存图 \(files.count) 张，共 \(ByteCountFormatter.string(fromByteCount: totalBytes(), countStyle: .file))，队列 \(queue.count)，进行中 \(inFlight.count)"
    }
}
