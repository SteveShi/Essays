import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@main
struct EssaysApp: App {
#if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#else
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
    @State private var appState = AppState()
    @State private var databaseReloadToken = UUID()
    #if os(macOS)
    @State private var updaterViewModel = UpdaterViewModel()
    #endif
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
                .id(databaseReloadToken)
                .environment(appState)
                .modelContainer(LocalDatabase.shared.container)
                .preferredColorScheme(preferredColorScheme)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 600)
                #endif
                .task {
                    #if os(macOS)
                    HotkeyManager.shared.start()
                    #endif
                    #if os(macOS)
                    if #available(macOS 26.0, *) {
                        await MemosAIAssistant.shared.initialize()
                    }
                    #endif
                }
                .onReceive(NotificationCenter.default.publisher(for: .databaseContainerDidChange)) { _ in
                    databaseReloadToken = UUID()
                }
        }
#if os(macOS)
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
            
            CommandGroup(after: .appInfo) {
                Button(String(localized: "Check for Updates...", comment: "Menu command to check for updates")) {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }
        }
#endif
        
        #if os(macOS)
        Settings {
            SettingsView()
                .id(databaseReloadToken)
                .environment(appState)
                .modelContainer(LocalDatabase.shared.container)
                .preferredColorScheme(preferredColorScheme)
        }
        #endif
    }
}


#if os(macOS)
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
            button.image = NSImage(systemSymbolName: "pencil.line", accessibilityDescription: String(localized: "Essays Quick Input", comment: "Accessibility description for menu bar icon"))
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
            menu.addItem(NSMenuItem(title: String(localized: "Quit Essays"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            QuickInputPanelManager.shared.togglePanel()
        }
    }
}
#else
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}
#endif

extension Notification.Name {
    static let createNewMemo = Notification.Name("createNewMemo")
    static let focusSearch = Notification.Name("focusSearch")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let toggleQuickInput = Notification.Name("toggleQuickInput")
}
