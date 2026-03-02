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
