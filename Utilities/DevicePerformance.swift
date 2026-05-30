import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// 检测设备性能并提供智能配置
@MainActor
struct DevicePerformance {

    /// 设备性能等级
    enum PerformanceLevel {
        case low      // 低性能设备
        case medium   // 中等性能设备
        case high     // 高性能设备
    }

    /// 检测设备性能等级
    static func detectPerformanceLevel() -> PerformanceLevel {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let processorCount = ProcessInfo.processInfo.processorCount

        // 根据内存和处理器数量判断性能
        let memoryGB = Double(physicalMemory) / (1024 * 1024 * 1024)

        if memoryGB >= 16 && processorCount >= 8 {
            return .high
        } else if memoryGB >= 8 && processorCount >= 4 {
            return .medium
        } else {
            return .low
        }
    }

    /// 根据性能等级获取推荐的分页大小
    static func recommendedPageSize() -> Int {
        switch detectPerformanceLevel() {
        case .high:
            return 100  // 高性能设备：每页 100 条
        case .medium:
            return 50   // 中等性能：每页 50 条
        case .low:
            return 30   // 低性能设备：每页 30 条
        }
    }

    /// 根据性能等级获取推荐的初始加载数量
    static func recommendedInitialLoad() -> Int {
        switch detectPerformanceLevel() {
        case .high:
            return 100  // 高性能设备：初始加载 100 条
        case .medium:
            return 50   // 中等性能：初始加载 50 条
        case .low:
            return 30   // 低性能设备：初始加载 30 条
        }
    }

    /// 根据性能等级获取推荐的最大显示数量
    static func recommendedMaxDisplay() -> Int {
        switch detectPerformanceLevel() {
        case .high:
            return 1000  // 高性能设备：最多 1000 条
        case .medium:
            return 500   // 中等性能：最多 500 条
        case .low:
            return 300   // 低性能设备：最多 300 条
        }
    }

    /// 根据性能等级获取推荐的预加载触发点
    static func recommendedPreloadThreshold() -> Int {
        switch detectPerformanceLevel() {
        case .high:
            return 30   // 高性能设备：倒数 30 条时预加载
        case .medium:
            return 20   // 中等性能：倒数 20 条时预加载
        case .low:
            return 10   // 低性能设备：倒数 10 条时预加载
        }
    }

    /// 获取设备信息描述（用于调试）
    static func deviceInfo() -> String {
        let memory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(memory) / (1024 * 1024 * 1024)
        let processors = ProcessInfo.processInfo.processorCount
        let level = detectPerformanceLevel()

        return """
        Device Performance:
        - Memory: \(String(format: "%.1f", memoryGB)) GB
        - Processors: \(processors)
        - Level: \(level)
        - Page Size: \(recommendedPageSize())
        - Initial Load: \(recommendedInitialLoad())
        - Max Display: \(recommendedMaxDisplay())
        """
    }
}
