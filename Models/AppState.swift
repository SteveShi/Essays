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

    var serverURL: String = ""
    var accessToken: String = ""
    var isOnline: Bool
    var appVersion: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var memos: [Memo] = [] {
        didSet {
            updateRawDataDerivedStates()
            updateFilteredMemosState()
        }
    }
    var tags: [Tag] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedMemo: Memo?
    var searchText: String = "" {
        didSet { scheduleFilteredUpdate() }
    }
    private var updateTask: Task<Void, Error>?
    var selectedTag: String? {
        didSet { updateFilteredMemosState() }
    }
    var showArchived: Bool = false
    var isLoggedIn: Bool = false
    var currentUser: User?
    var user: User? { currentUser }  // 为向后兼容保留

    // Pre-computed filtered and grouped results
    private(set) var memosByName: [String: Memo] = [:]
    private(set) var filteredMemos: [Memo] = []
    private(set) var pinnedMemosList: [Memo] = []
    private(set) var timelineGroups: [MemoGroup] = []
    private(set) var memoDateComponents: Set<DateComponents> = []
    private(set) var todayMemosCount: Int = 0
    private(set) var recentWeekMemosCount: Int = 0
    private(set) var publicMemosCount: Int = 0
    private(set) var privateMemosCount: Int = 0

    private let userDefaults = UserDefaults.standard
    private let serverURLKey = "memos_server_url"
    private let accessTokenKey = "memos_access_token"
    private let currentUserKey = "memos_current_user"
    
    init() {
        self.isOnline = NetworkMonitor.shared.isConnected
        loadSavedCredentials()
        loadLocalCachedMemos()  // 优先加载本地缓存
        setupNetworkMonitoring()
        updateFilteredMemosState()  // Initial computation
    }

    private func setupNetworkMonitoring() {
        _ = withObservationTracking {
            NetworkMonitor.shared.isConnected
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.isOnline = NetworkMonitor.shared.isConnected
                if NetworkMonitor.shared.isConnected {
                    self?.syncPendingMemos()
                }
            }
        }
    }

    private func loadLocalCachedMemos() {
        let cached = LocalDatabase.shared.fetchAllMemos()
        if !cached.isEmpty {
            self.memos = cached
        }
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
        
        // 统计公开和私有数量
        self.publicMemosCount = memos.filter { $0.visibility == MemoVisibility.`public` }.count
        self.privateMemosCount = memos.filter { $0.visibility == MemoVisibility.`private` }.count
    }

    /// 在搜索、标签过滤或数据变动时调用的过滤状态更新（主要针对当前视图显示）
    @MainActor
    func updateFilteredMemosState() {
        let allFiltered = computeFilteredMemos()
        self.filteredMemos = allFiltered
        self.pinnedMemosList = allFiltered.filter { $0.pinned }

        let unpinned = allFiltered.filter { !$0.pinned }
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
    
    func saveCredentials() {
        userDefaults.set(serverURL, forKey: serverURLKey)
        userDefaults.set(accessToken, forKey: accessTokenKey)
        
        if let user = currentUser,
           let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: currentUserKey)
        }
    }
    
    func clearCredentials() {
        userDefaults.removeObject(forKey: serverURLKey)
        userDefaults.removeObject(forKey: accessTokenKey)
        userDefaults.removeObject(forKey: currentUserKey)
        
        serverURL = ""
        accessToken = ""
        currentUser = nil
        isLoggedIn = false
        memos = []
        tags = []
    }
    
    private func computeFilteredMemos() -> [Memo] {
        print(
            "Computing filters: total memos: \(memos.count), searchText: '\(searchText)', selectedTag: '\(selectedTag ?? "nil")'")
        var result = memos
        let (keywordTerms, pinnedFilter, visibilityFilter, createdFilter) = parseSearchFilters(from: searchText)
        
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
        
        print("Final filtered memos: \(result.count)")
        return result.sorted { $0.pinned && !$1.pinned || ($0.pinned == $1.pinned && $0.createdAt > $1.createdAt) }
    }
    
    private func parseSearchFilters(from rawSearch: String) -> ([String], Bool?, MemoVisibility?, CreatedFilter?) {
        let terms = rawSearch
            .split(whereSeparator: \.isWhitespace)
            .map { String($0) }
        
        var keywordTerms: [String] = []
        var pinnedFilter: Bool?
        var visibilityFilter: MemoVisibility?
        var createdFilter: CreatedFilter?
        
        for term in terms {
            let normalized = term.lowercased()
            switch normalized {
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
                // Check for specific date pattern: created:YYYY-MM-DD
                if normalized.hasPrefix("created:") {
                    let dateStr = String(normalized.dropFirst("created:".count))
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    if let date = formatter.date(from: dateStr) {
                        createdFilter = .specificDate(date)
                    } else {
                        keywordTerms.append(term)
                    }
                } else {
                    keywordTerms.append(term)
                }
            }
        }
        
        return (keywordTerms, pinnedFilter, visibilityFilter, createdFilter)
    }

    private enum CreatedFilter {
        case today
        case last7Days
        case specificDate(Date)
    }
}
