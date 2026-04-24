import SwiftUI
#if os(macOS)
import KeyboardShortcuts
#endif

struct SettingsView: View {
    @Environment(AppState.self) var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage("editorFontSize") private var editorFontSize: Double = 14
    @AppStorage("showLineNumbers") private var showLineNumbers = false
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("theme") private var theme = "system"
    @AppStorage("enableAIFeatures") private var enableAIFeatures = true
    @AppStorage("targetTranslationLanguage") private var targetTranslationLanguage = "auto"
    
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
        #if os(macOS)
        .frame(width: 550, height: 450)
        #endif
    }
    
    private var generalTab: some View {
        Form {
            Section {
                Picker(String(localized: "Appearance", comment: "Theme picker label"), selection: $theme) {
                    Text(String(localized: "System", comment: "System theme option")).tag("system")
                    Text(String(localized: "Light", comment: "Light theme option")).tag("light")
                    Text(String(localized: "Dark", comment: "Dark theme option")).tag("dark")
                }
                #if os(macOS)
                .pickerStyle(.radioGroup)
                #else
                .pickerStyle(.segmented)
                #endif
            } header: {
                Text(String(localized: "Theme", comment: "Theme section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
            
            #if os(macOS)
            Section {
                KeyboardShortcuts.Recorder(String(localized: "Quick Input Shortcut", comment: "Shortcut picker label"), name: .toggleQuickInput)
            } header: {
                Text(String(localized: "Shortcuts", comment: "Shortcuts section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
            #endif
            
            Section {
                LabeledContent(String(localized: "Network Status", comment: "Network status label"))
                {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(!appState.isConnected ? Color.red : (appState.isServerReachable ? Color.green : Color.orange))
                            .frame(width: 8, height: 8)
                        Text(
                            !appState.isConnected
                                ? String(localized: "Offline", comment: "Network status: Offline")
                                : (appState.isServerReachable
                                    ? String(localized: "Online", comment: "Network status: Online")
                                    : String(localized: "Server Offline", comment: "Network status: Server unreachable"))
                        )
                        .foregroundColor(.secondary)
                    }
                    .onTapGesture {
                        appState.checkServerReachability()
                    }
                }
                
                if let error = appState.lastConnectionError {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .padding(.leading, 4)
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
                        Text(
                            String(
                                localized: "\(Int(editorFontSize)) pt",
                                comment: "Font size value with points unit"))
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
                            .fill(appState.isLocalMode ? Color.green.gradient : LiquidGlassTheme.colors.accent.gradient)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Text(user.displayNameResolved.prefix(1).uppercased())
                                    .font(.system(size: 20, weight: .semibold, design: .default))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayNameResolved)
                                .font(LiquidGlassTheme.typography.headline)
                            
                            if appState.isLocalMode {
                                Text(String(localized: "Local Mode", comment: "Account mode label in settings"))
                                    .font(LiquidGlassTheme.typography.subheadline)
                                    .foregroundColor(.green)
                            } else {
                                Text(user.email ?? user.username)
                                    .font(LiquidGlassTheme.typography.subheadline)
                                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                            }
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

                if appState.isLocalMode {
                    LabeledContent(String(localized: "Mode", comment: "Mode label"),
                                   value: String(localized: "Offline First (Local DB)", comment: "Offline first mode value"))
                    if let folderPath = AccountManager.shared.activeAccount?.dataDirectoryPath,
                       !folderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        LabeledContent(
                            String(localized: "Data Folder", comment: "Data folder label in account settings"),
                            value: folderPath
                        )
                    }
                } else {
                    LabeledContent(String(localized: "Server", comment: "Server info label"), value: appState.serverURL)
                }
                
                LabeledContent(
                    String(localized: "Total Memos", comment: "Memos count label"),
                    value: "--")
                
                LabeledContent(
                    String(localized: "Total Tags", comment: "Tags count label"),
                    value: "--")
            } header: {
                Text(String(localized: "Statistics", comment: "Statistics section header"))
                    .font(LiquidGlassTheme.typography.headline)
            }
            
            // 已保存的账户列表
            if AccountManager.shared.accounts.count > 1 {
                Section {
                    ForEach(AccountManager.shared.accounts) { account in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.displayName)
                                    .font(LiquidGlassTheme.typography.body)
                                Text(account.mode == .local
                                     ? String(localized: "Local", comment: "Account type local")
                                     : (account.serverURL ?? ""))
                                    .font(LiquidGlassTheme.typography.caption)
                                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                            }
                            Spacer()
                            if account.id == AccountManager.shared.activeAccountID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "Saved Accounts", comment: "Saved accounts section header"))
                        .font(LiquidGlassTheme.typography.headline)
                }
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
