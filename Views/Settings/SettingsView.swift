import SwiftUI
#if os(macOS)
import AppKit
import KeyboardShortcuts
import UniformTypeIdentifiers
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
    @State private var replaceExistingOnImport = true
    @State private var dataTransferStatus: String?
    @State private var isDataTransferRunning = false
    @State private var dropboxSyncService = DropboxSyncService.shared
    @State private var aiAvailabilityState: AIAssistantAvailabilityState = .checking
    #if os(macOS)
    @State private var updaterViewModel = UpdaterViewModel.shared
    #endif
    
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
                #if os(macOS)
                Toggle(
                    String(localized: "Automatically check for updates", comment: "Toggle for Sparkle automatic update checks"),
                    isOn: Binding(
                        get: { updaterViewModel.automaticallyChecksForUpdates },
                        set: { updaterViewModel.automaticallyChecksForUpdates = $0 }
                    )
                )
                #endif
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
                            .fill(aiAvailabilityState.isAvailable ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(aiAvailabilityState.localizedTitle)
                            .foregroundColor(.secondary)
                    }
                } label: {
                    Text(String(localized: "Apple Intelligence", comment: "AI status label"))
                }

                if !aiAvailabilityState.isAvailable {
                    Text(aiAvailabilityState.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Label(String(localized: "Status", comment: "Status header"), systemImage: "info.circle")
                    .font(LiquidGlassTheme.typography.headline)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            await refreshAIAvailability()
        }
    }

    @MainActor
    private func refreshAIAvailability() async {
        aiAvailabilityState = await AIAssistantAvailabilityState.current()
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

            Section {
                Toggle(
                    String(localized: "Replace current data when importing", comment: "Toggle for replacing data during archive import"),
                    isOn: $replaceExistingOnImport
                )

                HStack {
                    Button {
                        exportDataArchive()
                    } label: {
                        Label(
                            String(localized: "Export Data", comment: "Button to export all app data"),
                            systemImage: "square.and.arrow.up"
                        )
                    }
                    .disabled(isDataTransferRunning)

                    Button {
                        importDataArchive()
                    } label: {
                        Label(
                            String(localized: "Import Data", comment: "Button to import all app data"),
                            systemImage: "square.and.arrow.down"
                        )
                    }
                    .disabled(isDataTransferRunning)
                }

                if appState.isLocalMode {
                    Button {
                        chooseActiveLocalDataFolder()
                    } label: {
                        Label(
                            String(localized: "Use Existing Local Folder", comment: "Button to select an existing local data folder"),
                            systemImage: "folder"
                        )
                    }
                    .disabled(isDataTransferRunning)

                    Button {
                        useDropboxLocalFolder()
                    } label: {
                        Label(
                            String(localized: "Use Dropbox Local Folder", comment: "Button to use local Dropbox folder for local data"),
                            systemImage: "externaldrive.connected.to.line.below"
                        )
                    }
                    .disabled(isDataTransferRunning)
                }

                if let dataTransferStatus {
                    Text(dataTransferStatus)
                        .font(.caption)
                        .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                        .textSelection(.enabled)
                }
            } header: {
                Text(String(localized: "Data Transfer", comment: "Data transfer settings section header"))
                    .font(LiquidGlassTheme.typography.headline)
            } footer: {
                Text(String(localized: "Archives include text, images, references, comments, locations, tags, visibility, and archive state.", comment: "Data transfer archive contents footer"))
            }

            if appState.isLocalMode {
                Section {
                    TextField(
                        String(localized: "Dropbox App Key", comment: "Dropbox app key field placeholder"),
                        text: $dropboxSyncService.appKey
                    )
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                    Toggle(
                        String(localized: "Enable Dropbox API sync", comment: "Toggle for Dropbox API sync"),
                        isOn: $dropboxSyncService.isEnabled
                    )
                    .disabled(!dropboxSyncService.isAuthorized)

                    HStack {
                        Button {
                            Task {
                                await dropboxSyncService.authorize()
                            }
                        } label: {
                            Label(
                                dropboxSyncService.isAuthorized
                                    ? String(localized: "Reconnect Dropbox", comment: "Button to reconnect Dropbox")
                                    : String(localized: "Connect Dropbox", comment: "Button to connect Dropbox"),
                                systemImage: "link"
                            )
                        }
                        .disabled(dropboxSyncService.isSyncing)

                        Button {
                            Task {
                                await dropboxSyncService.syncNow()
                            }
                        } label: {
                            Label(
                                dropboxSyncService.isSyncing
                                    ? String(localized: "Syncing Dropbox...", comment: "Button state while Dropbox sync is running")
                                    : String(localized: "Sync Dropbox Now", comment: "Button to sync Dropbox now"),
                                systemImage: "arrow.triangle.2.circlepath"
                            )
                        }
                        .disabled(!dropboxSyncService.isAuthorized || !dropboxSyncService.isEnabled || dropboxSyncService.isSyncing)

                        Button {
                            dropboxSyncService.disconnect()
                        } label: {
                            Label(
                                String(localized: "Disconnect", comment: "Button to disconnect Dropbox"),
                                systemImage: "xmark.circle"
                            )
                        }
                        .disabled(!dropboxSyncService.isAuthorized || dropboxSyncService.isSyncing)
                    }

                    if let status = dropboxSyncService.lastStatusMessage {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                            .textSelection(.enabled)
                    }

                    if let error = dropboxSyncService.lastErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(LiquidGlassTheme.colors.error)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text(String(localized: "Dropbox Sync", comment: "Dropbox sync settings section header"))
                        .font(LiquidGlassTheme.typography.headline)
                } footer: {
                    Text(String(localized: "Dropbox API sync is only used for local mode and stores each memo as a separate JSON record.", comment: "Dropbox sync settings footer"))
                }
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

    private func exportDataArchive() {
        #if os(macOS)
        isDataTransferRunning = true
        defer { isDataTransferRunning = false }

        do {
            let data = try DataTransferService.exportArchive(forAccountID: appState.activeAccountID)
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = String(localized: "Essays Archive", comment: "Default export archive file name")
                + "."
                + DataTransferService.archiveFileExtension
            panel.message = String(localized: "Choose where to save the Essays data archive.", comment: "Message for export archive save panel")
            panel.prompt = String(localized: "Export", comment: "Confirm button for export archive panel")

            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url, options: .atomic)
                dataTransferStatus = String(localized: "Data export completed.", comment: "Status after data export succeeds")
            }
        } catch {
            dataTransferStatus = String(
                format: String(localized: "Data export failed: %@", comment: "Status after data export fails"),
                error.localizedDescription
            )
        }
        #else
        dataTransferStatus = String(localized: "Data transfer is not available on this device.", comment: "Status when data transfer is unavailable")
        #endif
    }

    private func importDataArchive() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.message = String(localized: "Choose an Essays data archive to import.", comment: "Message for import archive open panel")
        panel.prompt = String(localized: "Import", comment: "Confirm button for import archive panel")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        isDataTransferRunning = true
        defer { isDataTransferRunning = false }

        do {
            let data = try Data(contentsOf: url)
            let importedCount = try DataTransferService.importArchive(
                from: data,
                intoAccountID: appState.activeAccountID,
                replaceExisting: replaceExistingOnImport
            )
            appState.loadLocalCachedMemos()
            NotificationCenter.default.post(name: .syncCompleted, object: nil)
            dataTransferStatus = String(
                format: String(localized: "Data import completed: %lld memos.", comment: "Status after data import succeeds"),
                Int64(importedCount)
            )
        } catch {
            dataTransferStatus = String(
                format: String(localized: "Data import failed: %@", comment: "Status after data import fails"),
                error.localizedDescription
            )
        }
        #else
        dataTransferStatus = String(localized: "Data transfer is not available on this device.", comment: "Status when data transfer is unavailable")
        #endif
    }

    private func chooseActiveLocalDataFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Select", comment: "Confirm button for folder picker")
        panel.message = String(localized: "Choose an existing local data folder to restore or sync local data.", comment: "Message for choosing an existing local data folder")

        if panel.runModal() == .OK, let url = panel.url {
            appState.updateLocalDataFolder(url)
            dataTransferStatus = String(localized: "Local data folder updated.", comment: "Status after local data folder selection")
        }
        #else
        dataTransferStatus = String(localized: "Local folder selection is not available on this device.", comment: "Status when local folder selection is unavailable")
        #endif
    }

    private func useDropboxLocalFolder() {
        #if os(macOS)
        if let folderURL = dropboxSyncService.preferredDropboxEssaysFolder() {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            appState.updateLocalDataFolder(folderURL)
            dataTransferStatus = String(localized: "Dropbox local folder selected.", comment: "Status after selecting Dropbox local folder")
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = String(localized: "Select", comment: "Confirm button for folder picker")
        panel.message = String(localized: "Choose your Dropbox Essays folder.", comment: "Message for choosing Dropbox local folder")

        if panel.runModal() == .OK, let url = panel.url {
            appState.updateLocalDataFolder(url)
            dataTransferStatus = String(localized: "Dropbox local folder selected.", comment: "Status after selecting Dropbox local folder")
        }
        #else
        dataTransferStatus = String(localized: "Local folder selection is not available on this device.", comment: "Status when local folder selection is unavailable")
        #endif
    }
    

}
