import Foundation
import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// 管理图片缓存，支持内存和磁盘持久化
@MainActor
class ImageCacheManager {
    static let shared = ImageCacheManager()

    private let memoryCache = NSCache<NSString, PlatformImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    private init() {
        // 配置内存缓存
        memoryCache.countLimit = 100 // 最多缓存 100 张图片
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // 50MB

        // 配置磁盘缓存目录
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)

        // 创建缓存目录
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // 监听内存警告
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif

        // 启动时清理过期缓存
        Task {
            await cleanExpiredCache()
        }
    }

    /// 设置图片到缓存（内存 + 磁盘）
    func setImage(_ image: PlatformImage, forKey key: String) {
        // 存入内存缓存
        let cost = estimatedMemorySize(of: image)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)

        // 异步存入磁盘缓存
        Task {
            await saveToDisk(image, forKey: key)
        }
    }

    /// 从缓存获取图片（先内存，后磁盘）
    func image(forKey key: String) -> PlatformImage? {
        // 先从内存缓存读取
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        // 从磁盘缓存读取
        if let image = loadFromDisk(forKey: key) {
            // 重新放入内存缓存
            let cost = estimatedMemorySize(of: image)
            memoryCache.setObject(image, forKey: key as NSString, cost: cost)
            return image
        }

        return nil
    }

    /// 清除内存缓存
    @objc func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    /// 清除所有缓存（内存 + 磁盘）
    func clearAllCache() {
        clearMemoryCache()
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - 磁盘缓存

    private func diskCacheURL(forKey key: String) -> URL {
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return diskCacheURL.appendingPathComponent(filename)
    }

    private func saveToDisk(_ image: PlatformImage, forKey key: String) async {
        let url = diskCacheURL(forKey: key)

        #if os(macOS)
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return
        }
        #else
        guard let pngData = image.pngData() else {
            return
        }
        #endif

        try? pngData.write(to: url)
    }

    private func loadFromDisk(forKey key: String) -> PlatformImage? {
        let url = diskCacheURL(forKey: key)

        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }

    /// 清理超过 7 天的缓存文件
    private func cleanExpiredCache() async {
        let expirationDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 天前

        guard let files = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return
        }

        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modificationDate = attributes[.modificationDate] as? Date else {
                continue
            }

            if modificationDate < expirationDate {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    // MARK: - 辅助方法

    private func estimatedMemorySize(of image: PlatformImage) -> Int {
        #if os(macOS)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
        }
        return cgImage.bytesPerRow * cgImage.height
        #else
        guard let cgImage = image.cgImage else {
            return 0
        }
        return cgImage.bytesPerRow * cgImage.height
        #endif
    }
}
