import Foundation
import SwiftUI
import Observation
import SwiftData
import OSLog

@MainActor
@Observable
class AppState {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.steveshi.essays",
        category: "AppState"
    )

    private static let sidebarDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    enum SidebarSelection: Hashable {
        case all
        case today
        case past7Days
        case archived
        case attachments
        case publicMemos
        case protectedMemos
        case privateMemos
        case tag(String)
        case date(Date)
        case outbox
    }

    var serverURL: String = ""
    var accessToken: String = ""
    var isOnline: Bool { NetworkMonitor.shared.isConnected }
    var isServerReachable: Bool = false
    var lastConnectionError: String? = nil

    /// 当前活跃账户
    var activeAccount: Account? {
        AccountManager.shared.activeAccount
    }

    /// 是否处于本地模式
    var isLocalMode: Bool {
        AccountManager.shared.isLocalMode
    }

    /// 账户唯一标识，用于数据库隔离
    var activeAccountID: String {
        if isLocalMode { return "local" }
        if let account = activeAccount {
            return Self.accountIdentifier(for: account)
        }
        return Self.normalizedRemoteAccountID(from: serverURL)
    }


    
    /// Returns true if either the network monitor reports a connection OR we successfully reached the server.
    var isConnected: Bool {
        if isLocalMode {
            return true // Local Mode is offline-first, always logically connected to local DB
        }
        return isOnline || isServerReachable
    }

    static func accountIdentifier(for account: Account) -> String {
        switch account.mode {
        case .local:
            return "local"
        case .remote:
            return normalizedRemoteAccountID(from: account.serverURL ?? "")
        }
    }

    static func normalizedRemoteAccountID(from rawServerURL: String) -> String {
        var trimmed = rawServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        // Backward compatibility:
        // Older builds might persist server URLs without scheme, e.g. "example.com".
        // Normalize them to the same canonical form as network configuration.
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            if trimmed.lowercased().contains("localhost")
                || trimmed.range(of: "^[0-9.]+$", options: .regularExpression) != nil {
                trimmed = "http://" + trimmed
            } else {
                trimmed = "https://" + trimmed
            }
        }

        let fallback = trimmed.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased()
        else {
            return fallback
        }

        var normalized = "\(scheme)://\(host)"
        if let port = components.port {
            normalized += ":\(port)"
        }

        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !path.isEmpty {
            normalized += "/\(path)"
        }
        return normalized
    }

    func matchesActiveAccount(accountID: String?, memoName: String? = nil) -> Bool {
        if let memoName, memoName.hasPrefix("local_") {
            return activeAccountID == "local"
        }
        if let accountID {
            let normalized = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized == "local" {
                return activeAccountID == "local"
            }
            return Self.normalizedRemoteAccountID(from: normalized) == activeAccountID
        }
        return isLocalMode
    }
    var appVersion: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // App Data - Reactive Selection State
    var searchText: String = ""
    var selectedTag: String?
    var isGalleryMode: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?
    var isLoggedIn: Bool = false
    var currentUser: User?
    var user: User? { currentUser }
    
    var scrollToMemoID: String?
    var selectedMemo: Memo?
    var selectedMemoForDetail: Memo?

    // Data source and derived states
    var memos: [Memo] = [] {
        didSet {
            updateRawDataDerivedStates()
        }
    }
    var memosByName: [String: Memo] = [:]
    var tags: [Tag] = []

    var memoDateComponents: Set<DateComponents> = []
    var todayMemosCount: Int = 0
    var recentWeekMemosCount: Int = 0
    var publicMemosCount: Int = 0
    var protectedMemosCount: Int = 0
    var privateMemosCount: Int = 0
    var archivedMemosCount: Int = 0
    var imageAttachmentMemosCount: Int = 0

    // For NavigationSplitView column control (iPhone navigation)
    var columnVisibility: NavigationSplitViewVisibility = .all
    
    var sidebarSelection: SidebarSelection? = .all {
        didSet {
            updateFiltersFromSelection()
        }
    }

    private func updateFiltersFromSelection() {
        guard let selection = sidebarSelection else { return }
        isGalleryMode = false
        switch selection {
        case .all:
            searchText = ""
            selectedTag = nil
        case .today:
            searchText = "created:today"
            selectedTag = nil
        case .past7Days:
            searchText = "created:7d"
            selectedTag = nil
        case .archived:
            searchText = "is:archived"
            selectedTag = nil
        case .attachments:
            searchText = ""
            selectedTag = nil
            isGalleryMode = true
        case .publicMemos:
            searchText = "visibility:public"
            selectedTag = nil
        case .protectedMemos:
            searchText = "visibility:workspace"
            selectedTag = nil
        case .privateMemos:
            searchText = "visibility:private"
            selectedTag = nil
        case .tag(let tagName):
            searchText = ""
            selectedTag = tagName
        case .date(let date):
            searchText = "created:\(Self.sidebarDateFormatter.string(from: date))"
            selectedTag = nil
        case .outbox:
            searchText = ""
            selectedTag = nil
        }
    }

    private let userDefaults = UserDefaults.standard
    private let serverURLKey = "memos_server_url"
    private let accessTokenKey = "memos_access_token"
    private let currentUserKey = "memos_current_user"
    
    init() {
        loadSavedCredentials()
        let resolvedActive = LocalDatabase.shared.activateStore(for: AccountManager.shared.activeAccount)
        if let resolvedActive {
            AccountManager.shared.setActiveAccount(resolvedActive)
        }
        loadLocalCachedMemos()
        setupConnectivityActions()
        checkServerReachability()
        startServerStatusTimer()
    }

    private func setupConnectivityActions() {
        NetworkMonitor.shared.onConnectedChange = { [weak self] isConnected in
            Task { @MainActor in
                // Independently check server reachability whenever connectivity changes
                self?.checkServerReachability()
                if isConnected {
                    self?.syncPendingMemos()
                }
            }
        }
    }

    private func startServerStatusTimer() {
        // Check connectivity and trigger background sync every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkServerReachability()
                if self?.isServerReachable == true {
                    SyncEngine.shared.triggerSync()
                }
            }
        }
    }

    @MainActor
    func checkServerReachability() {
        if isLocalMode {
            self.isServerReachable = true
            self.lastConnectionError = nil
            return
        }

        
        guard !serverURL.isEmpty, let _ = URL(string: serverURL) else { 
            self.isServerReachable = false
            self.lastConnectionError = String(localized: "Server URL not configured or invalid")
            return 
        }
        
        Task {
            do {
                MemosAPIClient.shared.configure(
                    serverURL: serverURL,
                    accessToken: accessToken,
                    apiVersion: activeAccount?.apiVersion ?? .v027
                )
                _ = try await MemosAPIClient.shared.checkServerStatus()
                await MainActor.run {
                    self.isServerReachable = true
                    self.lastConnectionError = nil
                }
            } catch MemosAPIError.serverError(let json) where json.contains("\"code\":") {
                // If it's a valid Memos JSON error (like 404/401), the server IS reachable!
                Self.logger.warning("Server reachable (status error payload): \(json, privacy: .public)")
                await MainActor.run {
                    self.isServerReachable = true
                    self.lastConnectionError = nil
                }
            } catch MemosAPIError.decodingError {
                // If the server responded but we couldn't decode, the server IS reachable
                Self.logger.warning("Server reachable with unexpected response format")
                await MainActor.run {
                    self.isServerReachable = true
                    self.lastConnectionError = nil
                }
            } catch MemosAPIError.unauthorized {
                // Server is reachable but token is invalid/expired
                Self.logger.warning("Server reachable but unauthorized")
                await MainActor.run {
                    self.isServerReachable = true
                    self.lastConnectionError = nil
                }
            } catch {
                if error.isCancellationLike {
                    return
                }
                let errorDescription = error.localizedDescription
                Self.logger.error("Server reachability check failed: \(errorDescription, privacy: .public)")
                await MainActor.run {
                    self.isServerReachable = false
                    self.lastConnectionError = errorDescription
                }
            }
        }
    }

    @MainActor
    func loadLocalCachedMemos() {
        // Fetch fresh from context every time, bypassing any stale AppState array cache
        LocalDatabase.shared.context.processPendingChanges()
        let fetched = LocalDatabase.shared.fetchAllMemos()
        migrateLegacyLocalMemosIfNeeded(fetched)
        let scoped = fetched.filter { memo in
            matchesActiveAccount(accountID: memo.accountID, memoName: memo.name)
                && !memo.isSystemCommentMemo
        }
        for memo in scoped {
            memo.extractTagsFromContent()
        }
        self.memos = scoped
    }

    @MainActor
    private func migrateLegacyLocalMemosIfNeeded(_ memos: [Memo]) {
        guard isLocalMode else { return }
        var didChange = false
        for memo in memos where memo.name.hasPrefix("local_") {
            if memo.accountID != "local" {
                memo.accountID = "local"
                didChange = true
            }
        }
        if didChange {
            try? LocalDatabase.shared.context.save()
        }
    }

    private func syncPendingMemos() {
        // 同步逻辑将在后续 MemosAPIClient 改造中完善
        Self.logger.debug("Network restored, checking for pending syncs")
    }

    /// 仅在 memos 原始数据改变时调用的昂贵计算（日历点位、字典索引、全局计数）
    @MainActor
    private func updateRawDataDerivedStates() {
        // 更新以 Name 为索引的快速查找字典
        var byName: [String: Memo] = [:]
        var tagCounts: [String: Int] = [:]

        for memo in memos {
            byName[memo.name] = memo
            for tag in memo.tags {
                tagCounts[tag, default: 0] += 1
            }
        }
        self.memosByName = byName
        self.tags = tagCounts.map { Tag(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count || ($0.count == $1.count && $0.name < $1.name) }

        let calendar = Calendar.current

        // Date components for the sidebar calendar (耗时操作，仅在数据变动时执行一次)
        let components = memos.map {
            calendar.dateComponents([.year, .month, .day], from: $0.createdAt)
        }
        self.memoDateComponents = Set(components)

        // Pre-compute quick action counts
        self.todayMemosCount = memos.filter { calendar.isDateInToday($0.createdAt) }.count

        if let startOfRecentWeek = calendar.date(byAdding: .day, value: -7, to: Date()) {
            self.recentWeekMemosCount = memos.filter { $0.createdAt >= startOfRecentWeek }.count
        } else {
            self.recentWeekMemosCount = 0
        }
        
        // 统计公开和私有数量 (仅统计 NORMAL 状态)
        let normalMemos = memos.filter { $0.state == .normal }
        self.publicMemosCount = normalMemos.filter { $0.visibility == MemoVisibility.`public` }.count
        self.protectedMemosCount = normalMemos.filter { $0.visibility == MemoVisibility.protected }.count
        self.privateMemosCount = normalMemos.filter { $0.visibility == MemoVisibility.`private` }.count
        self.archivedMemosCount = memos.filter { $0.state == .archived }.count
        self.imageAttachmentMemosCount = memos.reduce(0) { count, memo in
            count + memo.attachments.filter { $0.isImage }.count
        }
    }

    func loadSavedCredentials() {
        // 优先从 AccountManager 加载活跃账户
        if let account = AccountManager.shared.activeAccount {
            switch account.mode {
            case .local:
                serverURL = ""
                accessToken = account.accessToken ?? ""
                currentUser = User.localUser(displayName: account.displayName)
                isLoggedIn = true
            case .remote:
                serverURL = account.serverURL ?? ""
                accessToken = account.accessToken ?? ""
                if !serverURL.isEmpty, !accessToken.isEmpty {
                    currentUser = User(
                        name: "users/\(account.id.uuidString)",
                        role: .user,
                        username: account.username ?? account.displayName,
                        email: nil,
                        displayName: account.displayName,
                        avatarUrl: nil,
                        description: nil,
                        state: "NORMAL",
                        createTime: nil,
                        updateTime: nil
                    )
                    isLoggedIn = true
                } else {
                    currentUser = nil
                    isLoggedIn = false
                }
            }
        } else {
            // 向后兼容：从旧的 UserDefaults 键加载
            serverURL = userDefaults.string(forKey: serverURLKey) ?? ""
            accessToken = userDefaults.string(forKey: accessTokenKey) ?? ""
            
            if let userData = userDefaults.data(forKey: currentUserKey),
                let user = try? JSONDecoder().decode(User.self, from: userData) as User,
               !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                currentUser = user
                isLoggedIn = true
            } else {
                currentUser = nil
                isLoggedIn = false
            }
        }
    }
    
    func saveCredentials() {
        userDefaults.set(serverURL, forKey: serverURLKey)
        userDefaults.set(accessToken, forKey: accessTokenKey)
        
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: currentUserKey)
        }
        
        Task { @MainActor in
            checkServerReachability()
        }
    }
    
    func clearCredentials() {
        userDefaults.removeObject(forKey: serverURLKey)
        userDefaults.removeObject(forKey: accessTokenKey)
        userDefaults.removeObject(forKey: currentUserKey)
        

        // 从 AccountManager 退出当前账户
        AccountManager.shared.signOutCurrentAccount()
        _ = LocalDatabase.shared.activateStore(for: nil)
        
        serverURL = ""
        accessToken = ""
        currentUser = nil
        isLoggedIn = false
        memos = []
        tags = []
        selectedMemoForDetail = nil
    }
    
    /// 切换到指定账户
    func switchToAccount(_ account: Account) {
        let resolvedAccount = LocalDatabase.shared.activateStore(for: account) ?? account
        AccountManager.shared.setActiveAccount(resolvedAccount)
        if resolvedAccount.mode == .remote {
            LocalDatabase.shared.purgeLocalOutboxTasks()
        }
        memos = []
        tags = []
        selectedMemoForDetail = nil
        loadSavedCredentials()
        if resolvedAccount.mode == .remote {
            MemosAPIClient.shared.configure(
                serverURL: resolvedAccount.serverURL ?? "",
                accessToken: resolvedAccount.accessToken ?? "",
                apiVersion: resolvedAccount.apiVersion ?? .v027
            )
        }
        loadLocalCachedMemos()
        checkServerReachability()
        SyncEngine.shared.triggerSync()
    }

    func updateLocalDataFolder(_ folderURL: URL) {
        guard var account = AccountManager.shared.activeAccount, account.mode == .local else { return }
        account.dataDirectoryPath = folderURL.path
        let resolvedAccount = LocalDatabase.shared.activateStore(for: account) ?? account
        AccountManager.shared.updateAccount(resolvedAccount)
        AccountManager.shared.setActiveAccount(resolvedAccount)
        memos = []
        tags = []
        selectedMemoForDetail = nil
        loadSavedCredentials()
        loadLocalCachedMemos()
        checkServerReachability()
    }
    
    @MainActor
    func archiveMemo(_ memo: Memo) async {
        guard matchesActiveAccount(accountID: memo.accountID, memoName: memo.name) else { return }
        // Optimistic UI update: change state immediately
        let previousState = memo.state
        memo.state = .archived
        
        do {
            if isLocalMode {
                try LocalDatabase.shared.context.save()
                return
            }

            // Enqueue outbox task only; SyncEngine will execute network request.
            let payload = SimpleMemoPayload(
                contentSummary: memo.truncatedContent,
                accountID: activeAccountID
            )
            let payloadData = (try? JSONEncoder().encode(payload)) ?? Data()
            let task = OutboxTask(type: .archiveMemo, payload: payloadData, memoId: memo.name)
            LocalDatabase.shared.context.insert(task)
            try LocalDatabase.shared.context.save()
            SyncEngine.shared.triggerSync()
        } catch {
            // Revert on failure
            memo.state = previousState
            self.errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func unarchiveMemo(_ memo: Memo) async {
        guard matchesActiveAccount(accountID: memo.accountID, memoName: memo.name) else { return }
        // Optimistic UI update: change state immediately
        let previousState = memo.state
        memo.state = .normal
        
        do {
            if isLocalMode {
                try LocalDatabase.shared.context.save()
                return
            }

            // Enqueue outbox task only; SyncEngine will execute network request.
            let payload = SimpleMemoPayload(
                contentSummary: memo.truncatedContent,
                accountID: activeAccountID
            )
            let payloadData = (try? JSONEncoder().encode(payload)) ?? Data()
            let task = OutboxTask(type: .unarchiveMemo, payload: payloadData, memoId: memo.name)
            LocalDatabase.shared.context.insert(task)
            try LocalDatabase.shared.context.save()
            SyncEngine.shared.triggerSync()
        } catch {
            // Revert on failure
            memo.state = previousState
            self.errorMessage = error.localizedDescription
        }
    }
}
