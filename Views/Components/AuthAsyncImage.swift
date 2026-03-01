import SwiftUI
import Foundation

/// 遵循 MoeMemos 模式的带鉴权图片加载组件。
///
/// 核心优化：
/// 1. 所有磁盘 I/O 均在后台线程执行，防止主线程卡死。
/// 2. 使用原生 AsyncImage 处理 file:// URL，规避多线程解码崩溃。
struct AuthAsyncImage<Content: View, Placeholder: View>: View {
    let urls: [URL]
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var localURL: URL?
    @State private var hasFailed = false

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urls = url.map { [$0] } ?? []
        self.content = content
        self.placeholder = placeholder
    }

    init(
        urls: [URL],
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.urls = urls
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let localURL = localURL {
                AsyncImage(url: localURL) { phase in
                    switch phase {
                    case .success(let image):
                        content(image)
                    case .failure:
                        placeholder()
                            .onAppear { hasFailed = true }
                    case .empty:
                        placeholder()
                    @unknown default:
                        placeholder()
                    }
                }
            } else if hasFailed {
                placeholder()
            } else {
                placeholder()
                    .task {
                        // 显式异步执行磁盘与下载逻辑，防止阻塞 MainActor
                        await prepareLocalURL()
                    }
            }
        }
    }

    private func prepareLocalURL() async {
        guard !urls.isEmpty else {
            self.hasFailed = true
            return
        }

        // 调用静态助手方法在非隔离上下文中执行 I/O
        if let resultURL = await ImageStorageHelper.shared.ensureLocalImage(for: urls) {
            self.localURL = resultURL
        } else {
            self.hasFailed = true
        }
    }
}

/// 专门用于磁盘 I/O 的单例助手，确保不占用主线程
actor ImageStorageHelper {
    static let shared = ImageStorageHelper()

    private let cacheDir: URL

    private init() {
        let caches = FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first!
        self.cacheDir =
            caches
            .appendingPathComponent("Essays", isDirectory: true)
            .appendingPathComponent("Caches", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
        
        // 初始确保目录存在
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    func ensureLocalImage(for urls: [URL]) async -> URL? {
        for url in urls {
            // 如果已经是本地文件
            if url.isFileURL { return url }

            // 检查磁盘缓存
            let safeName = "\(abs(url.absoluteString.hashValue)).img"
            let localFile = cacheDir.appendingPathComponent(safeName)
            
            if FileManager.default.fileExists(atPath: localFile.path) {
                return localFile
            }

            // 下载逻辑
            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            if let token = UserDefaults.standard.string(forKey: "memos_access_token"),
                !token.isEmpty
            {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            do {
                let (tempURL, response) = try await URLSession.shared.download(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                    (200...299).contains(httpResponse.statusCode)
                else {
                    try? FileManager.default.removeItem(at: tempURL)
                    continue
                }

                if FileManager.default.fileExists(atPath: localFile.path) {
                    try? FileManager.default.removeItem(at: localFile)
                }
                try FileManager.default.moveItem(at: tempURL, to: localFile)
                return localFile
            } catch {
                continue
            }
        }
        return nil
    }
}
