import SwiftUI
import SwiftData
import AppKit
import Carbon

@main
struct EssaysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @AppStorage("theme") private var theme = "system"
    @AppStorage("quickInputShortcut") private var quickInputShortcut = 1
    
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
                    if #available(macOS 26.0, *) {
                        await MemosAIAssistant.shared.initialize()
                    } else {
                        // Fallback on earlier versions
                    }
                }
                .onChange(of: quickInputShortcut) { old, new in
                    appDelegate.updateGlobalHotkey()
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
    var settingsWindowController: NSWindowController?
    var hotkeyRef: EventHotKeyRef?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        registerGlobalHotkey()
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
            statusItem.button?.performClick(nil) // Trigger menu
            statusItem.menu = nil // Reset so left click still works directly
        } else {
            QuickInputPanelManager.shared.togglePanel()
        }
    }
    
    @MainActor
    @objc func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
    
    func updateGlobalHotkey() {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        registerGlobalHotkey()
    }
    
    private func registerGlobalHotkey() {
        var hotKeyId = EventHotKeyID()
        hotKeyId.signature = UTGetOSTypeFromString("ESSY" as CFString)
        hotKeyId.id = 1
        
        let shortcutOpt = UserDefaults.standard.integer(forKey: "quickInputShortcut")
        
        let modifierFlags: UInt32
        if shortcutOpt == 2 {
            modifierFlags = UInt32(cmdKey | shiftKey) // Cmd + Shift + N
        } else {
            modifierFlags = UInt32(cmdKey | optionKey) // Cmd + Option + N
        }
        
        let keyCode: UInt32 = 45 // 'N'
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            // Must dispatch to main thread for UI interactions
            DispatchQueue.main.async {
                QuickInputPanelManager.shared.togglePanel()
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        RegisterEventHotKey(keyCode, modifierFlags, hotKeyId, GetApplicationEventTarget(), 0, &hotkeyRef)
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
