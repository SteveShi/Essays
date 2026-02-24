import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var serverURL: String = ""
    @Published var accessToken: String = ""
    @Published var memos: [Memo] = []
    @Published var tags: [Tag] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedMemo: Memo?
    @Published var searchText: String = ""
    @Published var selectedTag: String?
    @Published var showArchived: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let serverURLKey = "memos_server_url"
    private let accessTokenKey = "memos_access_token"
    private let currentUserKey = "memos_current_user"
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSavedCredentials()
    }
    
    func loadSavedCredentials() {
        serverURL = userDefaults.string(forKey: serverURLKey) ?? ""
        accessToken = userDefaults.string(forKey: accessTokenKey) ?? ""
        
        if let userData = userDefaults.data(forKey: currentUserKey),
           let user = try? JSONDecoder().decode(User.self, from: userData),
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
    
    var filteredMemos: [Memo] {
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
    
    var pinnedMemos: [Memo] {
        filteredMemos.filter { $0.pinned }
    }
    
    var unpinnedMemos: [Memo] {
        filteredMemos.filter { !$0.pinned }
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
