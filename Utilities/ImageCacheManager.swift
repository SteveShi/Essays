import Foundation
import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// 管理图片缓存，限制内存使用
@MainActor
class ImageCacheManager {
    static let shared = ImageCacheManager()

    private let cache = NSCache<NSString, PlatformImage>()

    private init() {
        // 限制缓存大小
        cache.countLimit = 100 // 最多缓存 100 张图片
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB

        // 监听内存警告
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
    }

    func setImage(_ image: PlatformImage, forKey key: String) {
        let cost = estimatedMemorySize(of: image)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }

    func image(forKey key: String) -> PlatformImage? {
        return cache.object(forKey: key as NSString)
    }

    @objc func clearCache() {
        cache.removeAllObjects()
    }

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
