import SwiftUI
import AppKit

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
                .preferredColorScheme(preferredColorScheme)
                .frame(minWidth: 900, minHeight: 600)
                .task {
                    HotkeyManager.shared.start()
                    if #available(macOS 26.0, *) {
                        await MemosAIAssistant.shared.initialize()
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
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.stop()
    }

    @MainActor
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pencil.line", accessibilityDescription: "Essays Quick Input")
            button.action = #selector(statusBarButtonClicked(sender:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @MainActor
    @objc func statusBarButtonClicked(sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: String(localized: "Settings"), action: #selector(openSettings), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: String(localized: "Quit Essays"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            QuickInputPanelManager.shared.togglePanel()
        }
    }

    @MainActor
    @objc func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

extension Notification.Name {
    static let createNewMemo = Notification.Name("createNewMemo")
    static let focusSearch = Notification.Name("focusSearch")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let openSettings = Notification.Name("openSettings")
    static let toggleQuickInput = Notification.Name("toggleQuickInput")
}

struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: @Sendable () -> Void = {
        #if os(macOS)
            Task { @MainActor in
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        #endif
    }
}

extension EnvironmentValues {
    var openSettings: @Sendable () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}
