import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14
    @AppStorage("showLineNumbers") private var showLineNumbers = false
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("theme") private var theme = "system"
    @AppStorage("enableAIFeatures") private var enableAIFeatures = true
    @AppStorage("targetTranslationLanguage") private var targetTranslationLanguage = "auto"
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    
    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label(String(localized: "General", comment: "Settings tab label"), systemImage: "gear")
                }
            
            editorTab
                .tabItem {
                    Label(String(localized: "Editor", comment: "Settings tab label"), systemImage: "textformat")
                }
            
            aiTab
                .tabItem {
                    Label(String(localized: "AI", comment: "Settings tab label"), systemImage: "sparkles")
                }
            
            accountTab
                .tabItem {
                    Label(String(localized: "Account", comment: "Settings tab label"), systemImage: "person.circle")
                }
            
        }
        .frame(width: 550, height: 450)
    }
    
    private var generalTab: some View {
        Form {
            Section {
                Picker(String(localized: "Appearance", comment: "Theme picker label"), selection: $theme) {
                    Text(String(localized: "System", comment: "System theme option")).tag("system")
                    Text(String(localized: "Light", comment: "Light theme option")).tag("light")
                    Text(String(localized: "Dark", comment: "Dark theme option")).tag("dark")
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text(String(localized: "Theme", comment: "Theme section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
            
            Section {
                LabeledContent(String(localized: "Quick Input Shortcut", comment: "Shortcut picker label")) {
                    HStack(spacing: 8) {
                        KeyRecorderView(config: $hotkeyManager.config)
                        Button(String(localized: "Reset", comment: "Reset hotkey to default")) {
                            hotkeyManager.resetToDefault()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                        .font(LiquidGlassTheme.typography.caption)
                    }
                }
                Text(String(localized: "Click the shortcut field and press your desired key combination.", comment: "Hotkey recorder hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text(String(localized: "Shortcuts", comment: "Shortcuts section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
            
            Section {
                LabeledContent(String(localized: "Network Status", comment: "Network status label"))
                {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(appState.isOnline ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(
                            appState.isOnline
                                ? String(localized: "Online", comment: "Network status: Online")
                                : String(localized: "Offline", comment: "Network status: Offline")
                        )
                        .foregroundColor(.secondary)
                    }
                }

                Toggle(String(localized: "Auto-save drafts", comment: "Toggle for auto-save"), isOn: $autoSave)
            } header: {
                Text(String(localized: "Behavior", comment: "Behavior section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var editorTab: some View {
        Form {
            Section {
                Slider(value: $editorFontSize, in: 10...24, step: 1) {
                    HStack {
                        Text(String(localized: "Font Size", comment: "Font size slider label"))
                        Spacer()
                        Text("\(Int(editorFontSize)) pt")
                            .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                    }
                }
                
                Toggle(String(localized: "Show line numbers", comment: "Toggle for line numbers"), isOn: $showLineNumbers)
            } header: {
                Text(String(localized: "Editor Settings", comment: "Editor settings section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Markdown Support", comment: "Markdown support title"))
                        .font(LiquidGlassTheme.typography.subheadline)
                        .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "• Headers (# to ######)", comment: "Markdown header help"))
                        Text(String(localized: "• Bold (**text**) and Italic (*text*)", comment: "Markdown style help"))
                        Text(String(localized: "• Links ([text](url))", comment: "Markdown link help"))
                        Text(String(localized: "• Code (`code`) and Code Blocks (```)", comment: "Markdown code help"))
                        Text(String(localized: "• Tags (#tag)", comment: "Markdown tag help"))
                    }
                    .font(LiquidGlassTheme.typography.footnote)
                    .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
                }
            } header: {
                Text(String(localized: "Formatting", comment: "Formatting section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var aiTab: some View {
        Form {
            Section {
                Toggle(String(localized: "Enable AI Features", comment: "Toggle for AI features"), isOn: $enableAIFeatures)
                Text(String(localized: "AI features use Apple Intelligence on-device processing and will not send any data to the cloud.", comment: "AI privacy disclaimer"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Label(String(localized: "Apple Intelligence", comment: "Apple Intelligence header"), systemImage: "apple.intelligence")
                    .font(LiquidGlassTheme.typography.headline)
            }
            
            Section {
                Picker(String(localized: "Target Translation Language", comment: "Translation language picker label"), selection: $targetTranslationLanguage) {
                    Text(String(localized: "Auto-detect", comment: "Auto-detect language")).tag("auto")
                    Text(String(localized: "English", comment: "Language option English")).tag("en")
                    Text(String(localized: "简体中文", comment: "Language option Simplified Chinese"))
                        .tag("zh-Hans")
                    Text(String(localized: "繁體中文", comment: "Language option Traditional Chinese"))
                        .tag("zh-Hant")
                    Text(String(localized: "日本語", comment: "Language option Japanese")).tag("ja")
                    Text(String(localized: "Español", comment: "Language option Spanish")).tag("es")
                    Text(String(localized: "Français", comment: "Language option French")).tag("fr")
                }
            } header: {
                Label(String(localized: "Translation", comment: "Translation header"), systemImage: "globe")
                    .font(LiquidGlassTheme.typography.headline)
            }
            
            Section {
                LabeledContent {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "AI Ready", comment: "AI ready status"))
                            .foregroundColor(.secondary)
                    }
                } label: {
                    Text(String(localized: "Apple Intelligence", comment: "AI status label"))
                }
            } header: {
                Label(String(localized: "Status", comment: "Status header"), systemImage: "info.circle")
                    .font(LiquidGlassTheme.typography.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var accountTab: some View {
        Form {
            Section {
                if let user = appState.currentUser {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(LiquidGlassTheme.colors.accent.gradient)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(user.displayNameResolved.prefix(1).uppercased())
                                    .font(.system(size: 20, weight: .semibold, design: .default))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayNameResolved)
                                .font(LiquidGlassTheme.typography.headline)
                            
                            Text(user.email ?? user.username)
                                .font(LiquidGlassTheme.typography.subheadline)
                                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                        }
                    }
                }
            } header: {
                Text(String(localized: "Profile", comment: "Profile section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
            
            Section {
                LabeledContent(
                    String(localized: "Version", comment: "App version label"),
                    value: appState.appVersion)

                LabeledContent(String(localized: "Server", comment: "Server info label"), value: appState.serverURL)
                
                LabeledContent(
                    String(localized: "Total Memos", comment: "Memos count label"),
                    value: String(
                        localized: "\(appState.memos.count)", comment: "Total memos count value"))
                
                LabeledContent(
                    String(localized: "Total Tags", comment: "Tags count label"),
                    value: String(
                        localized: "\(appState.tags.count)", comment: "Total tags count value"))
            } header: {
                Text(String(localized: "Statistics", comment: "Statistics section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
            
            Section {
                HStack {
                    Spacer()
                    
                    Button(String(localized: "Sign Out", comment: "Sign out button text")) {
                        appState.clearCredentials()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(LiquidGlassTheme.colors.error)
                    
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    

}

// MARK: - KeyRecorderView

/// 显示当前快捷键，点击后进入录制模式，用户按下新组合键即保存
struct KeyRecorderView: View {
    @Binding var config: HotkeyConfig

    @State private var isRecording = false

    var body: some View {
        KeyRecorderField(config: $config, isRecording: $isRecording)
            .frame(width: 140, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording
                        ? LiquidGlassTheme.colors.accent.opacity(0.12)
                        : Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isRecording
                                    ? LiquidGlassTheme.colors.accent
                                    : Color.primary.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
    }
}

/// NSViewRepresentable：捕获键盘输入并回调 HotkeyConfig
struct KeyRecorderField: NSViewRepresentable {
    @Binding var config: HotkeyConfig
    @Binding var isRecording: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> RecorderNSTextField {
        let field = RecorderNSTextField()
        field.coordinator = context.coordinator
        field.isBordered = false
        field.backgroundColor = .clear
        field.isEditable = false
        field.isSelectable = false
        field.alignment = .center
        field.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        return field
    }

    func updateNSView(_ nsView: RecorderNSTextField, context: Context) {
        nsView.stringValue = isRecording
            ? String(localized: "Press shortcut…", comment: "Hotkey recorder prompt")
            : config.displayString
        nsView.textColor = isRecording ? NSColor.controlAccentColor : NSColor.labelColor
    }

    @MainActor
    class Coordinator: NSObject {
        var parent: KeyRecorderField
        init(_ parent: KeyRecorderField) { self.parent = parent }

        func handle(event: NSEvent) -> Bool {
            // 忽略纯 modifier 键
            guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty,
                  event.modifierFlags.intersection([.command, .option, .shift, .control]).isEmpty == false
            else { return false }

            let newConfig = HotkeyConfig(
                key: chars.uppercased(),
                modifierFlags: event.modifierFlags
                    .intersection([.command, .option, .shift, .control]).rawValue
            )
            self.parent.config = newConfig
            self.parent.isRecording = false
            return true
        }
    }
}

/// 自定义 NSTextField 子类，响应点击进入录制模式，并拦截键盘事件
final class RecorderNSTextField: NSTextField {
    weak var coordinator: KeyRecorderField.Coordinator?

    override func mouseDown(with event: NSEvent) {
        coordinator.flatMap { _ in
            DispatchQueue.main.async {
                self.coordinator?.parent.isRecording.toggle()
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        guard let coord = coordinator, coord.parent.isRecording else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 53 { // Esc — 取消录制
            coord.parent.isRecording = false
            return
        }
        _ = coord.handle(event: event)
    }

    override var acceptsFirstResponder: Bool { true }
    override func becomeFirstResponder() -> Bool { true }
}
