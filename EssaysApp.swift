 import SwiftUI

@main
struct EssaysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @AppStorage("theme") private var theme = "system"
    
    private var preferredColorScheme: ColorScheme? {
        switch theme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    if #available(macOS 26.0, *) {
                        await MemosAIAssistant.shared.initialize()
                    } else {
                        // Fallback on earlier versions
                    }
                }
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "New Memo", comment: "Menu command for new memo")) {
                    NotificationCenter.default.post(name: .createNewMemo, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button(String(localized: "Search", comment: "Menu command for search")) {
                    NotificationCenter.default.post(name: .focusSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
            }
            
            CommandGroup(replacing: .sidebar) {
                Button(String(localized: "Toggle Sidebar", comment: "Menu command to toggle sidebar")) {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .control])
            }
        }
        
        Settings {
            SettingsView()
                .environment(appState)
                .preferredColorScheme(preferredColorScheme)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Window configuration handled by SwiftUI modifiers
    }
}

extension Notification.Name {
    static let createNewMemo = Notification.Name("createNewMemo")
    static let focusSearch = Notification.Name("focusSearch")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let openSettings = Notification.Name("openSettings")
}

struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: @Sendable () -> Void = {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

extension EnvironmentValues {
    var openSettings: @Sendable () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}
