import SwiftUI
#if os(macOS)
import AppKit
#endif

struct LoginView: View {
    @Environment(AppState.self) var appState: AppState

    enum ServiceMode: String, CaseIterable {
        case local
        case remote

        var displayName: String {
            switch self {
            case .local:
                return String(localized: "Local Mode", comment: "Service mode: local embedded server")
            case .remote:
                return String(localized: "Remote Mode", comment: "Service mode: remote server")
            }
        }
    }

    enum RemoteAuthTab: Int, CaseIterable {
        case credentials
        case token

        var displayName: String {
            switch self {
            case .credentials:
                return String(localized: "Username & Password", comment: "Auth tab: credentials login")
            case .token:
                return String(localized: "Token Login", comment: "Auth tab: token login")
            }
        }
    }

    @State private var selectedMode: ServiceMode = .remote
    @State private var remoteAuthTab: RemoteAuthTab = .token

    // 远程模式字段
    @State private var serverURL: String = ""
    @State private var accessToken: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var selectedAPIVersion: MemosAPIVersion = .v027
    @State private var localDataDirectoryPath: String = ""

    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
        NavigationView {
            Form {
                Section {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(ServiceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Service Mode")
                }

                switch selectedMode {
                case .local:
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Offline-First Storage", systemImage: "internaldrive")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Memos will be stored locally on your device. No network connection required.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        Text("Local Mode")
                    }

                case .remote:
                    Section {
                        TextField("Server URL", text: $serverURL)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        Picker("API Version", selection: $selectedAPIVersion) {
                            ForEach(MemosAPIVersion.allCases, id: \.self) { version in
                                Text(version.rawValue).tag(version)
                            }
                        }
                    } header: {
                        Text("Server")
                    }

                    Section {
                        Picker("Auth Method", selection: $remoteAuthTab) {
                            ForEach(RemoteAuthTab.allCases, id: \.self) { tab in
                                Text(tab.displayName).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch remoteAuthTab {
                        case .token:
                            TextField("Access Token", text: $accessToken)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        case .credentials:
                            TextField("Username", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()

                            SecureField("Password", text: $password)
                                .textContentType(.password)
                        }
                    } header: {
                        Text("Authentication")
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }

                Section {
                    Button {
                        Task {
                            await signIn()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                            }
                            Text(signInButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!canSignIn)
                }
            }
            .navigationTitle("Essays")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if appState.isLoggedIn {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onAppear {
            serverURL = appState.serverURL
            accessToken = appState.accessToken
        }
        #else
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                headerView
                loginForm
            }
            .padding(40)
            .frame(maxWidth: 480)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.05),
                    Color.clear,
                    Color.accentColor.opacity(0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .overlay(alignment: .topTrailing) {
            // 只在已经有登录账户（即作为弹窗展示时）才显示取消按钮
            if appState.isLoggedIn {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(LiquidGlassTheme.colors.tertiaryText)
                }
                .buttonStyle(.plain)
                .padding(24)
            }
        }
        .onAppear {
            serverURL = appState.serverURL
            accessToken = appState.accessToken
            if let account = AccountManager.shared.activeAccount, account.mode == .local {
                localDataDirectoryPath = account.dataDirectoryPath ?? ""
            }
        }
        #endif
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(String(localized: "Essays", comment: "Application name"))
                .font(LiquidGlassTheme.typography.largeTitle)
                .foregroundColor(LiquidGlassTheme.colors.text)

            Text(String(localized: "Connect to your Memos server", comment: "Subtitle for login screen"))
                .font(LiquidGlassTheme.typography.subheadline)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
        }
    }

    // MARK: - Login Form

    private var loginForm: some View {
        VStack(spacing: 20) {
            // 服务模式下拉菜单
            modePicker

            // 根据模式显示不同的表单
            switch selectedMode {
            case .local:
                localModeForm
            case .remote:
                remoteModeForm
            }

            // 错误信息
            if let error = errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(LiquidGlassTheme.colors.error)

                    Text(error)
                        .font(LiquidGlassTheme.typography.callout)
                        .foregroundColor(LiquidGlassTheme.colors.error)
                }
                .padding(.top, 8)
            }

            // 登录按钮
            signInButton
        }
    }

    // MARK: - 模式选择

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Service Mode", comment: "Label for service mode picker"))
                .font(LiquidGlassTheme.typography.caption)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .textCase(.uppercase)
                .tracking(1)

            Picker(String(localized: "Service Mode", comment: "Picker for service mode"), selection: $selectedMode) {
                ForEach(ServiceMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 本地模式表单

    private var localModeForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Offline-First Database", comment: "Label for local offline mode"))
                .font(LiquidGlassTheme.typography.caption)
                .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                .textCase(.uppercase)
                .tracking(1)

            Text(String(localized: "Memos will be stored in an offline-first local database. No network connection is required.", comment: "Help text for local storage mode"))
                .font(LiquidGlassTheme.typography.footnote)
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)

            #if os(macOS)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(localDataDirectoryPath.isEmpty
                         ? String(localized: "No folder selected", comment: "Placeholder when local data folder is not selected")
                         : localDataDirectoryPath)
                        .font(LiquidGlassTheme.typography.footnote)
                        .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer()

                    Button(String(localized: "Choose Folder", comment: "Button to choose local data folder")) {
                        chooseLocalDataFolderForNewStorage()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button {
                    chooseExistingLocalDataFolder()
                } label: {
                    Label(
                        String(localized: "Use Existing Local Folder", comment: "Button to select an existing local data folder"),
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    useDropboxLocalFolder()
                } label: {
                    Label(
                        String(localized: "Use Dropbox Local Folder", comment: "Button to use local Dropbox folder for local data"),
                        systemImage: "externaldrive.connected.to.line.below"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            #else
            // iOS: 使用应用的Documents目录
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(LiquidGlassTheme.colors.accent)
                    Text(String(localized: "Data will be stored in app's local storage", comment: "iOS local mode storage info"))
                        .font(LiquidGlassTheme.typography.footnote)
                        .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LiquidGlassTheme.colors.accent.opacity(0.1))
                )
            }
            #endif
        }
    }

    // MARK: - 远程模式表单

    private var remoteModeForm: some View {
        VStack(spacing: 16) {
            // Server URL & API Version
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(localized: "Server URL", comment: "Label for server URL field"))
                        .font(LiquidGlassTheme.typography.caption)
                        .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                        .textCase(.uppercase)
                        .tracking(1)
                    Spacer()
                    Picker(String(localized: "API Version", comment: "API version picker"), selection: $selectedAPIVersion) {
                        ForEach(MemosAPIVersion.allCases, id: \.self) { version in
                            Text(version.rawValue).tag(version)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                }

                TextField(
                    String(
                        localized: "https://your-memos-server.com",
                        comment: "Placeholder for server URL field"), text: $serverURL
                )
                .textFieldStyle(.roundedBorder)
                .font(LiquidGlassTheme.typography.body)
                .autocorrectionDisabled()
            }

            // 认证选项卡
            Picker(String(localized: "Authentication Method", comment: "Auth method picker label"), selection: $remoteAuthTab) {
                ForEach(RemoteAuthTab.allCases, id: \.self) { tab in
                    Text(tab.displayName).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            switch remoteAuthTab {
            case .credentials:
                credentialsForm
            case .token:
                tokenForm
            }
        }
    }

    private var credentialsForm: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Username", comment: "Label for username field"))
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1)

                TextField(String(localized: "Username", comment: "Placeholder for username field"), text: $username)
                    .textFieldStyle(.roundedBorder)
                    .font(LiquidGlassTheme.typography.body)
                    .autocorrectionDisabled()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Password", comment: "Label for password field"))
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1)

                SecureField(String(localized: "Password", comment: "Placeholder for password field"), text: $password)
                    .textFieldStyle(.roundedBorder)
                    .font(LiquidGlassTheme.typography.body)
                    .onSubmit {
                        Task {
                            await signIn()
                        }
                    }
            }
        }
    }

    private var tokenForm: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "Access Token", comment: "Label for access token field"))
                    .font(LiquidGlassTheme.typography.caption)
                    .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                    .textCase(.uppercase)
                    .tracking(1)

                SecureField(String(localized: "Access Token", comment: "Placeholder for access token field"), text: $accessToken)
                    .textFieldStyle(.roundedBorder)
                    .font(LiquidGlassTheme.typography.body)
                    .onSubmit {
                        Task {
                            await signIn()
                        }
                    }
            }

            Text(String(localized: "Use personal access token for API authentication", comment: "Help text for access token"))
                .font(LiquidGlassTheme.typography.footnote)
                .foregroundColor(LiquidGlassTheme.colors.tertiaryText)
        }
    }

    // MARK: - 登录按钮

    private var signInButton: some View {
        Button {
            Task {
                await signIn()
            }
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }

                Text(signInButtonTitle)
                    .font(LiquidGlassTheme.typography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSignIn)
        .padding(.top, 8)
    }

    private var signInButtonTitle: String {
        if isLoading {
            return selectedMode == .local
                ? String(localized: "Starting local mode...", comment: "Button state during local mode start")
                : String(localized: "Signing in...", comment: "Button state during login")
        }
        return selectedMode == .local
            ? String(localized: "Start Local Mode", comment: "Button text to start local mode")
            : String(localized: "Sign In", comment: "Button text to start login")
    }

    // MARK: - 验证

    private var canSignIn: Bool {
        guard !isLoading else { return false }

        switch selectedMode {
        case .local:
            #if os(macOS)
            return !localDataDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            #else
            // iOS: 不需要选择文件夹，直接允许登录
            return true
            #endif
        case .remote:
            let normalizedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedServerURL.isEmpty else { return false }
            switch remoteAuthTab {
            case .credentials:
                return !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !password.isEmpty
            case .token:
                return !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    // MARK: - 操作

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch selectedMode {
            case .local:
                await signInLocal()
            case .remote:
                try await signInRemote()
            }
        } catch {
            if error.isCancellationLike {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    private func signInLocal() async {
        #if os(macOS)
        let selectedFolder = localDataDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedFolder.isEmpty else {
            errorMessage = String(localized: "Please choose a local data folder first.", comment: "Error when local data folder is missing")
            return
        }
        let dataPath = selectedFolder
        #else
        // iOS: 使用应用的Documents目录
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
        let dataPath = documentsPath
        #endif

        // 创建并保存本地账户
        let account = Account.localAccount(dataDirectoryPath: dataPath)
        let resolvedAccount = LocalDatabase.shared.activateStore(for: account) ?? account
        AccountManager.shared.setActiveAccount(resolvedAccount)

        appState.currentUser = User.localUser
        appState.isLoggedIn = true
        appState.saveCredentials()
    }

    private func signInRemote() async throws {
        let normalizedServerURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedServerURL.isEmpty else {
            errorMessage = String(localized: "Server URL is required")
            return
        }

        switch remoteAuthTab {
        case .credentials:
            let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedUsername.isEmpty else {
                errorMessage = String(localized: "Username is required", comment: "Error when username empty")
                return
            }
            guard !password.isEmpty else {
                errorMessage = String(localized: "Password is required", comment: "Error when password empty")
                return
            }

            MemosAPIClient.shared.configure(
                serverURL: normalizedServerURL,
                accessToken: "",
                apiVersion: selectedAPIVersion
            )
            let user = try await MemosAPIClient.shared.signIn(username: normalizedUsername, password: password)
            let token = MemosAPIClient.shared.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !token.isEmpty else {
                throw MemosAPIError.serverError(
                    String(
                        localized: "Sign-in succeeded but no access token was returned. Please use Access Token mode.",
                        comment: "Error shown when credential sign-in response does not include a token"
                    )
                )
            }

            // 保存远程账户
            let account = Account.remoteAccount(
                displayName: user.displayNameResolved,
                serverURL: normalizedServerURL,
                apiVersion: selectedAPIVersion,
                accessToken: token,
                username: normalizedUsername
            )
            let resolvedAccount = LocalDatabase.shared.activateStore(for: account) ?? account
            AccountManager.shared.setActiveAccount(resolvedAccount)

            appState.serverURL = normalizedServerURL
            appState.accessToken = token
            appState.currentUser = user
            appState.isLoggedIn = true
            appState.saveCredentials()

        case .token:
            let normalizedAccessToken = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedAccessToken.isEmpty else {
                errorMessage = String(localized: "Access token is required")
                return
            }

            MemosAPIClient.shared.configure(
                serverURL: normalizedServerURL,
                accessToken: normalizedAccessToken,
                apiVersion: selectedAPIVersion
            )
            let user = try await MemosAPIClient.shared.getCurrentUser()

            // 保存远程账户
            let account = Account.remoteAccount(
                displayName: user.displayNameResolved,
                serverURL: normalizedServerURL,
                apiVersion: selectedAPIVersion,
                accessToken: normalizedAccessToken
            )
            let resolvedAccount = LocalDatabase.shared.activateStore(for: account) ?? account
            AccountManager.shared.setActiveAccount(resolvedAccount)

            appState.serverURL = normalizedServerURL
            appState.accessToken = normalizedAccessToken
            appState.currentUser = user
            appState.isLoggedIn = true
            appState.saveCredentials()
        }
    }

    #if os(macOS)
    private func chooseLocalDataFolderForNewStorage() {
        chooseLocalDataFolder(
            canCreateDirectories: true,
            message: String(localized: "Choose a folder to store local account data.", comment: "Message for local data folder picker")
        )
    }

    private func chooseExistingLocalDataFolder() {
        chooseLocalDataFolder(
            canCreateDirectories: false,
            message: String(localized: "Choose an existing local data folder to restore or sync local data.", comment: "Message for choosing an existing local data folder")
        )
    }

    private func chooseLocalDataFolder(canCreateDirectories: Bool, message: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = canCreateDirectories
        panel.prompt = String(localized: "Select", comment: "Confirm button for folder picker")
        panel.message = message

        if panel.runModal() == .OK, let url = panel.url {
            localDataDirectoryPath = url.path
        }
    }

    private func useDropboxLocalFolder() {
        if let folderURL = DropboxSyncService.shared.preferredDropboxEssaysFolder() {
            try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            localDataDirectoryPath = folderURL.path
            return
        }

        chooseLocalDataFolder(
            canCreateDirectories: true,
            message: String(localized: "Choose your Dropbox Essays folder.", comment: "Message for choosing Dropbox local folder")
        )
    }
    #endif

}
