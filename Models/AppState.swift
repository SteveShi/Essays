import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class AppState {
    var isLoggedIn: Bool = false
    var currentUser: User?
    var serverURL: String = ""
    var accessToken: String = ""
    var memos: [Memo] = [] {
        didSet { updateFilteredState() }
    }
    var tags: [Tag] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedMemo: Memo?
    var searchText: String = "" {
        didSet { updateFilteredState() }
    }
    var selectedTag: String? {
        didSet { updateFilteredState() }
    }
    var showArchived: Bool = false

    // Pre-computed filtered and grouped results
    private(set) var filteredMemos: [Memo] = []
    private(set) var pinnedMemosList: [Memo] = []
    private(set) var timelineGroups: [(date: Date, memos: [Memo])] = []
    private(set) var memoDateComponents: Set<DateComponents> = []
    private(set) var todayMemosCount: Int = 0
    private(set) var recentWeekMemosCount: Int = 0

    private let userDefaults = UserDefaults.standard
    private let serverURLKey = "memos_server_url"
    private let accessTokenKey = "memos_access_token"
    private let currentUserKey = "memos_current_user"
    
    init() {
        loadSavedCredentials()
        updateFilteredState()  // Initial computation
    }

    private func updateFilteredState() {
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
            .map { (date: $0.key, memos: $0.value.sorted { $0.createdAt > $1.createdAt }) }
            .sorted { $0.date > $1.date }

        // Date components for the sidebar calendar
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
        var result = memos
        let (keywordTerms, pinnedFilter, visibilityFilter, createdFilter) = parseSearchFilters(from: searchText)
        
        if let pinnedFilter {
            result = result.filter { $0.pinned == pinnedFilter }
        }
        
        if let visibilityFilter {
            result = result.filter { $0.visibility == visibilityFilter }
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
        }
        
        if !keywordTerms.isEmpty {
            result = result.filter { memo in
                keywordTerms.allSatisfy { term in
                    memo.content.localizedCaseInsensitiveContains(term) ||
                    memo.tags.contains { $0.localizedCaseInsensitiveContains(term) }
                }
            }
        }
        
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }
        
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
            case "visibility:protected":
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
