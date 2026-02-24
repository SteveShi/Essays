import Foundation

struct Memo: Identifiable, Hashable {
    let name: String          // Full resource name, e.g. "memos/123" or "memos/uid"
    let id: Int               // Extracted numeric ID from name for legacy compat
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let visibility: MemoVisibility
    let pinned: Bool
    let tags: [String]
    let resources: [Resource]
    
    init(
        name: String = "",
        id: Int,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        visibility: MemoVisibility = .private,
        pinned: Bool = false,
        tags: [String] = [],
        resources: [Resource] = []
    ) {
        self.name = name.isEmpty ? "memos/\(id)" : name
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.visibility = visibility
        self.pinned = pinned
        self.tags = tags
        self.resources = resources
    }
}

enum MemoVisibility: String, Codable, CaseIterable {
    case `public` = "PUBLIC"
    case `protected` = "PROTECTED"
    case `private` = "PRIVATE"
    
    var displayName: String {
        switch self {
        case .public: return String(localized: "Public")
        case .protected: return String(localized: "Protected")
        case .private: return String(localized: "Private")
        }
    }
    
    var icon: String {
        switch self {
        case .public: return "globe"
        case .protected: return "lock.shield"
        case .private: return "lock"
        }
    }
}

struct Resource: Codable, Identifiable, Hashable {
    let name: String
    let filename: String
    let type: String
    let size: Int
    var externalLink: String?
    let createTime: Date?
    let memo: String?
    
    var id: String { name }
    
    var isImage: Bool {
        type.hasPrefix("image/")
    }
    
    var thumbnailURL: String? {
        externalLink
    }
}

struct Tag: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var count: Int
    
    init(name: String, count: Int = 0) {
        self.name = name
        self.count = count
    }
}

struct User: Codable, Identifiable {
    let name: String          // Resource name, e.g. "users/1"
    let role: UserRole
    let username: String
    let email: String?
    let displayName: String?
    let avatarUrl: String?
    let description: String?
    let state: String?
    let createTime: String?
    let updateTime: String?
    
    var id: String { name }
    
    var displayNameResolved: String {
        if let dn = displayName, !dn.isEmpty {
            return dn
        }
        return username
    }
}

enum UserRole: String, Codable {
    case roleUnspecified = "ROLE_UNSPECIFIED"
    case admin = "ADMIN"
    case user = "USER"
}

struct ServerInfo: Codable {
    let version: String
    let mode: String
    let allowSignUp: Bool
    let disablePasswordLogin: Bool
    let dbType: String
}
