#if os(macOS)
import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleQuickInput = Self("toggleQuickInput", default: .init(.n, modifiers: [.command, .option]))
}

@MainActor
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    private init() {}

    func start() {
        KeyboardShortcuts.onKeyDown(for: .toggleQuickInput) {
            DispatchQueue.main.async {
                QuickInputPanelManager.shared.togglePanel()
            }
        }
    }

    func stop() {
        KeyboardShortcuts.removeAllHandlers()
    }
}
#else
import Foundation

@MainActor
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    private init() {}
    func start() {}
    func stop() {}
}
#endif
