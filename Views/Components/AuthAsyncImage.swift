import SwiftUI
import Foundation

/// Authenticated image loading following the MoeMemos pattern.
///
/// Images are downloaded manually to the local disk cache using standard URLSession.
/// Once downloaded, SwiftUI's native `AsyncImage` renders the `file://` URL.
/// This prevents layout loops, cross-thread NSImage crashes, and memory leaks.
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
                // SwiftUI AsyncImage rendering a local disk file (100% safe, no network loop)
                AsyncImage(url: localURL) { phase in
                    if let image = phase.image {
                        content(image)
                    } else if phase.error != nil {
                        placeholder()
                    } else {
                        placeholder()
                    }
                }
            } else if hasFailed {
                placeholder()
            } else {
                placeholder()
                    .task {
                        await downloadToLocalCache()
                    }
            }
        }
    }

    private func downloadToLocalCache() async {
        guard !urls.isEmpty else {
            hasFailed = true
            return
        }

        let cacheDir = FileManager.default.temporaryDirectory.appendingPathComponent(
            "MemosImageCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(
                at: cacheDir, withIntermediateDirectories: true)
        }

        // Try candidate URLs one by one
        for url in urls {
            if Task.isCancelled { return }

            // Use url string hash as cache key
            let safeName = "\((url.absoluteString).hashValue).img"
            let localFile = cacheDir.appendingPathComponent(safeName)

            // If already cached on disk, use it immediately
            if FileManager.default.fileExists(atPath: localFile.path) {
                self.localURL = localFile
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            if let token = UserDefaults.standard.string(forKey: "memos_access_token"),
                !token.isEmpty
            {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            if let (data, response) = try? await URLSession.shared.data(for: request),
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode)
            {
                if Task.isCancelled { return }
                
                // Save to local disk cache
                do {
                    try data.write(to: localFile)
                    self.localURL = localFile
                    return
                } catch {
                    // Write failed, try next url
                    continue
                }
            }
        }

        // All URLs failed
        if !Task.isCancelled {
            self.hasFailed = true
        }
    }
}
