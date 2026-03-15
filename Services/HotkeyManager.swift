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
