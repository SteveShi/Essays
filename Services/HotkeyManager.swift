import AppKit

// MARK: - Hotkey 数据模型

struct HotkeyConfig: Codable, Equatable {
    /// 按键字符（大写），例如 "N"
    var key: String
    /// NSEvent.ModifierFlags 的原始值
    var modifierFlags: UInt

    /// 默认快捷键：⌘⌥N
    static let `default` = HotkeyConfig(key: "N", modifierFlags: NSEvent.ModifierFlags([.command, .option]).rawValue)

    var modifiers: NSEvent.ModifierFlags { NSEvent.ModifierFlags(rawValue: modifierFlags) }

    /// 用于 UI 展示，例如 "⌘⌥N"
    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        s += key.uppercased()
        return s
    }
}

// MARK: - HotkeyManager

/// 使用 NSEvent 全局监听替代 Carbon EventHotKey API
@MainActor
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    private var monitor: Any?
    private let userDefaultsKey = "quickInputHotkey"

    @Published var config: HotkeyConfig {
        didSet { save(); restart() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let saved = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            config = saved
        } else {
            config = .default
        }
    }

    // MARK: 启动监听

    func start() {
        stop()
        let cfg = config
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            let requiredModifiers = cfg.modifiers.intersection([.command, .option, .shift, .control])
            let eventModifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
            let keyMatches = event.charactersIgnoringModifiers?.uppercased() == cfg.key
            if eventModifiers == requiredModifiers && keyMatches {
                DispatchQueue.main.async {
                    QuickInputPanelManager.shared.togglePanel()
                }
            }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func restart() { start() }

    // MARK: 持久化

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    /// 重置为默认快捷键
    func resetToDefault() {
        config = .default
    }
}
