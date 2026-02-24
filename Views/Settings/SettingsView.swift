import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
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
            
            aboutTab
                .tabItem {
                    Label(String(localized: "About", comment: "Settings tab label"), systemImage: "info.circle")
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
                    Text("English").tag("en")
                    Text("简体中文").tag("zh-Hans")
                    Text("繁體中文").tag("zh-Hant")
                    Text("日本語").tag("ja")
                    Text("Español").tag("es")
                    Text("Français").tag("fr")
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
                LabeledContent(String(localized: "Server", comment: "Server info label"), value: appState.serverURL)
                
                LabeledContent(String(localized: "Total Memos", comment: "Memos count label"), value: "\(appState.memos.count)")
                
                LabeledContent(String(localized: "Total Tags", comment: "Tags count label"), value: "\(appState.tags.count)")
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
    
    private var aboutTab: some View {
        VStack(spacing: 24) {
            Image(systemName: "note.text")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("Essays")
                    .font(LiquidGlassTheme.typography.largeTitle)
                
                Text("Version 1.0.0")
                    .font(LiquidGlassTheme.typography.subheadline)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
            }
            
            Text(String(localized: "A beautiful macOS client for Memos", comment: "App description"))
                .font(LiquidGlassTheme.typography.body)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/usememos/memos")!) {
                    Label(String(localized: "Memos on GitHub", comment: "GitHub link label"), systemImage: "link")
                        .font(LiquidGlassTheme.typography.callout)
                }
                
                Text(String(localized: "Built with SwiftUI and ❤️", comment: "Credits text"))
                    .font(LiquidGlassTheme.typography.footnote)
                    .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
            }
            
            Spacer()
        }
        .padding(32)
    }
}
