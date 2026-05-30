import Foundation
#if os(iOS)
import UIKit

@MainActor
class QuickActionService: ObservableObject {
    static let shared = QuickActionService()

    @Published var pendingAction: QuickAction?

    enum QuickAction {
        case newMemo
        case search
        case quickCapture
    }

    private init() {}

    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        switch shortcutItem.type {
        case "com.essays.app.ios.newMemo":
            pendingAction = .newMemo
        case "com.essays.app.ios.search":
            pendingAction = .search
        case "com.essays.app.ios.quickCapture":
            pendingAction = .quickCapture
        default:
            break
        }
    }

    func clearPendingAction() {
        pendingAction = nil
    }
}
#else
@MainActor
class QuickActionService: ObservableObject {
    static let shared = QuickActionService()
    private init() {}
}
#endif
