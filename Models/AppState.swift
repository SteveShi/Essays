import Foundation
import SwiftUI
import Observation
import SwiftData

@MainActor
@Observable
class AppState {
    struct MemoGroup: Identifiable {
        let id: String
        let date: Date
        let memos: [Memo]
    }

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


    
    /// Returns true if either the network monitor reports a connection OR we successfully reached the server.
    var isConnected: Bool {
        if isLocalMode {
            return true // Local Mode is offline-first, always logically connected to local DB
        }
        return isOnline || isServerReachable
    }
    var appVersion: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // App Data - Reactive Selection State
    var searchText: String = "" {
        didSet { scheduleFilteredUpdate() }
    }
    var selectedTag: String? {
        didSet { scheduleFilteredUpdate() }
    }
    var isGalleryMode: Bool = false {
        didSet { scheduleFilteredUpdate() }
    }
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
            scheduleFilteredUpdate()
        }
    }
    var filteredMemos: [Memo] = []
    var pinnedMemosList: [Memo] = []
    var timelineGroups: [MemoGroup] = []
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

    @ObservationIgnored
    private var updateTask: Task<Void, Never>?
    
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
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            searchText = "created:\(formatter.string(from: date))"
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

        
        guard !serverURL.isEmpty else { 
            self.isServerReachable = false
            self.lastConnectionError = String(localized: "Server URL not configured")
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
                print("Server reachable (but returned status error): \(json)")
                await MainActor.run {
                    self.isServerReachable = true
                    self.lastConnectionError = nil
                }
            } catch MemosAPIError.decodingError {
                // If the server responded but we couldn't decode, the server IS reachable
                print("Server reachable (response decoded with unexpected format)")
                await MainActor.run {
                    self.isServerReachable = true
                    self.lastConnectionError = nil
                }
            } catch MemosAPIError.unauthorized {
                // Server is reachable but token is invalid/expired
                print("Server reachable (but unauthorized)")
                await MainActor.run {
                    self.isServerReachable = true
                    self.lastConnectionError = nil
                }
            } catch {
                let errorDescription = error.localizedDescription
                print("Server reachability check failed: \(errorDescription)")
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
        for memo in fetched {
            memo.extractTagsFromContent()
        }
        self.memos = fetched
        updateFilteredMemosState()
    }

    private func syncPendingMemos() {
        // 同步逻辑将在后续 MemosAPIClient 改造中完善
        print("Network restored, checking for pending syncs...")
    }



    private func scheduleFilteredUpdate() {
        updateTask?.cancel()
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms debounce
            if Task.isCancelled { return }
            updateFilteredMemosState()
        }
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

    /// 在搜索、标签过滤或数据变动时调用的过滤状态更新（主要针对当前视图显示）
    @MainActor
    func updateFilteredMemosState() {
        let allFiltered = computeFilteredMemos()
        self.filteredMemos = allFiltered
        
        // Timeline normally only shows NORMAL memos even if filtered, 
        // unless explicitly searching for archived
        let visibleMemos: [Memo]
        if searchText.lowercased().contains("is:archived") {
            visibleMemos = allFiltered
        } else {
            visibleMemos = allFiltered.filter { $0.state == .normal }
        }
        
        self.pinnedMemosList = visibleMemos.filter { $0.pinned }
        let unpinned = visibleMemos.filter { !$0.pinned }
        let calendar = Calendar.current

        // Grouping for the timeline
        let grouped = Dictionary(grouping: unpinned) { memo in
            calendar.startOfDay(for: memo.createdAt)
        }

        self.timelineGroups =
            grouped
            .map {
                MemoGroup(
                    id: "group-\($0.key.timeIntervalSince1970)",
                    date: $0.key,
                    memos: $0.value.sorted { $0.createdAt > $1.createdAt }
                )
            }
            .sorted { $0.date > $1.date }
    }
    
    func loadSavedCredentials() {
        // 优先从 AccountManager 加载活跃账户
        if let account = AccountManager.shared.activeAccount {
            switch account.mode {
            case .local:
                serverURL = ""
                accessToken = account.accessToken ?? ""
                currentUser = User.localUser
                isLoggedIn = true
            case .remote:
                serverURL = account.serverURL ?? ""
                accessToken = account.accessToken ?? ""
                if let userData = userDefaults.data(forKey: currentUserKey),
                   let user = try? JSONDecoder().decode(User.self, from: userData) {
                    currentUser = user
                    isLoggedIn = true
                } else if !serverURL.isEmpty, !accessToken.isEmpty {
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

        AccountManager.shared.setActiveAccount(account)
        memos = []
        tags = []
        selectedMemoForDetail = nil
        loadSavedCredentials()
        loadLocalCachedMemos()
        checkServerReachability()
    }
    
    @MainActor
    func archiveMemo(_ memo: Memo) async {
        // Optimistic UI update: change state immediately
        let previousState = memo.state
        memo.state = .archived
        updateFilteredMemosState()
        
        do {
            // Enqueue outbox task only; SyncEngine will execute network request.
            let task = OutboxTask(type: .archiveMemo, payload: Data(), memoId: memo.name)
            LocalDatabase.shared.context.insert(task)
            try LocalDatabase.shared.context.save()
            SyncEngine.shared.triggerSync()
        } catch {
            // Revert on failure
            memo.state = previousState
            updateFilteredMemosState()
            self.errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func unarchiveMemo(_ memo: Memo) async {
        // Optimistic UI update: change state immediately
        let previousState = memo.state
        memo.state = .normal
        updateFilteredMemosState()
        
        do {
            // Enqueue outbox task only; SyncEngine will execute network request.
            let task = OutboxTask(type: .unarchiveMemo, payload: Data(), memoId: memo.name)
            LocalDatabase.shared.context.insert(task)
            try LocalDatabase.shared.context.save()
            SyncEngine.shared.triggerSync()
        } catch {
            // Revert on failure
            memo.state = previousState
            updateFilteredMemosState()
            self.errorMessage = error.localizedDescription
        }
    }
    
    private func computeFilteredMemos() -> [Memo] {
        print(
            "Computing filters: total memos: \(memos.count), searchText: '\(searchText)', selectedTag: '\(selectedTag ?? "nil")'")
        var result = memos
        let (keywordTerms, pinnedFilter, visibilityFilter, stateFilter, createdFilter) = parseSearchFilters(from: searchText)
        
        if let pinnedFilter {
            result = result.filter { $0.pinned == pinnedFilter }
            print("After pinned filter: \(result.count)")
        }
        
        if let visibilityFilter {
            result = result.filter { $0.visibility == visibilityFilter }
            print("After visibility filter (\(visibilityFilter)): \(result.count)")
        }
        
        if let createdFilter {
            let calendar = Calendar.current
            let now = Date()
            switch createdFilter {
            case .today:
                result = result.filter { calendar.isDate($0.createdAt, inSameDayAs: now) }
            case .last7Days:
                guard let start = calendar.date(byAdding: .day, value: -7, to: now) else { break }
                result = result.filter { $0.createdAt >= start }
            case .specificDate(let date):
                result = result.filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            }
            print("After created filter: \(result.count)")
        }
        
        if !keywordTerms.isEmpty {
            result = result.filter { memo in
                keywordTerms.allSatisfy { term in
                    guard !term.isEmpty else { return true }
                    return memo.content.localizedCaseInsensitiveContains(term)
                        || memo.tags.contains { $0.localizedCaseInsensitiveContains(term) }
                }
            }
            print("After keyword filter: \(result.count)")
        }
        
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
            print("After tag filter: \(result.count)")
        }
        
        if let stateFilter {
            result = result.filter { $0.state == stateFilter }
        } else if !searchText.lowercased().contains("is:archived") {
            // Default to normal if not searching for archived
            result = result.filter { $0.state == .normal }
        }
        
        if isGalleryMode {
            // Gallery mode shows all memos with image attachments
            result = memos.filter { memo in
                memo.attachments.contains { $0.isImage }
            }
            print("Gallery mode filtered: \(result.count)")
        }

        print("Final filtered memos: \(result.count)")
        return result.sorted { $0.pinned && !$1.pinned || ($0.pinned == $1.pinned && $0.createdAt > $1.createdAt) }
    }
    
    private func parseSearchFilters(from rawSearch: String) -> ([String], Bool?, MemoVisibility?, MemoState?, CreatedFilter?) {
        // We should split by whitespace, but allow for combining spaces inside quotes if needed.
        // For simplicity, sticking to the whitespace split but ignoring empty.
        let terms = rawSearch.split(whereSeparator: \.isWhitespace).map { String($0) }
        
        var keywordTerms: [String] = []
        var pinnedFilter: Bool?
        var visibilityFilter: MemoVisibility?
        var stateFilter: MemoState?
        var createdFilter: CreatedFilter?
        
        for term in terms {
            let normalized = term.lowercased()
            switch normalized {
            case "is:archived":
                stateFilter = .archived
            case "is:normal":
                stateFilter = .normal
            case "pinned:true":
                pinnedFilter = true
            case "pinned:false":
                pinnedFilter = false
            case "visibility:public":
                visibilityFilter = .public
            case "visibility:workspace", "visibility:protected":
                visibilityFilter = .protected
            case "visibility:private":
                visibilityFilter = .private
            case "created:today":
                createdFilter = .today
            case "created:7d":
                createdFilter = .last7Days
            default:
                if normalized.hasPrefix("created:") {
                    let dateStr = String(normalized.dropFirst("created:".count))
                    let components = dateStr.split(separator: "-").compactMap { Int($0) }
                    
                    if components.count == 3 {
                        var dateComps = DateComponents()
                        dateComps.year = components[0]
                        dateComps.month = components[1]
                        dateComps.day = components[2]
                        
                        if let date = Calendar.current.date(from: dateComps) {
                            createdFilter = .specificDate(date)
                        } else {
                            keywordTerms.append(term)
                        }
                    } else {
                        keywordTerms.append(term)
                    }
                } else {
                    keywordTerms.append(term)
                }
            }
        }
        
        return (keywordTerms, pinnedFilter, visibilityFilter, stateFilter, createdFilter)
    }

    private enum CreatedFilter {
        case today
        case last7Days
        case specificDate(Date)
    }
}
