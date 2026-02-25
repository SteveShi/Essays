import Foundation

struct Memo: Identifiable, Hashable, Equatable {
    let name: String          // Full resource name, e.g. "memos/123" or "memos/uid"
    let id: Int               // Extracted numeric ID from name for legacy compat
    let content: String
    let createdAt: Date
    let updatedAt: Date
    let visibility: MemoVisibility
    let pinned: Bool
    let tags: [String]
    let attachments: [Attachment]
    let location: Location?
    let relations: [Relation]
    
    init(
        name: String = "",
        id: Int,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        visibility: MemoVisibility = .private,
        pinned: Bool = false,
        tags: [String] = [],
        attachments: [Attachment]? = [],
        location: Location? = nil,
        relations: [Relation] = []
    ) {
        self.name = name.isEmpty ? "memos/\(id)" : name
        self.id = id
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.visibility = visibility
        self.pinned = pinned
        self.tags = tags
        self.attachments = attachments ?? []
        self.location = location
        self.relations = relations
    }
}

struct Relation: Codable, Hashable, Equatable {
    let memo: String  // The memo that has the relation
    let relatedMemo: String  // The memo that is related
    let type: RelationType

    enum RelationType: String, Codable {
        case reference = "REFERENCE"
        case comment = "COMMENT"
        case unspecified = "RELATION_TYPE_UNSPECIFIED"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let label = try container.decode(String.self)
            self = RelationType(rawValue: label) ?? .unspecified
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(self.rawValue)
        }
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

struct Attachment: Codable, Identifiable, Hashable {
    let name: String
    let filename: String
    let type: String
    let size: Int64
    var externalLink: String?
    let createTime: Date?
    let memo: String?

    enum CodingKeys: String, CodingKey {
        case name, filename, type, size, externalLink, createTime, memo
        case create_time, external_link  // Legacy compat if needed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        filename = try container.decodeIfPresent(String.self, forKey: .filename) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""

        // Handle size as Int64 or String
        if let intSize = try? container.decode(Int64.self, forKey: .size) {
            size = intSize
        } else if let stringSize = try? container.decode(String.self, forKey: .size),
            let intSize = Int64(stringSize)
        {
            size = intSize
        } else {
            size = 0
        }

        externalLink =
            try container.decodeIfPresent(String.self, forKey: .externalLink)
            ?? container.decodeIfPresent(String.self, forKey: .external_link)
        createTime =
            try container.decodeIfPresent(Date.self, forKey: .createTime)
            ?? container.decodeIfPresent(Date.self, forKey: .create_time)
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(filename, forKey: .filename)
        try container.encode(type, forKey: .type)
        try container.encode(size, forKey: .size)
        try container.encodeIfPresent(externalLink, forKey: .externalLink)
        try container.encodeIfPresent(createTime, forKey: .createTime)
        try container.encodeIfPresent(memo, forKey: .memo)
    }
    
    var id: String { name }
    
    var isImage: Bool {
        type.hasPrefix("image/")
    }
    
    var thumbnailURL: String? {
        if let link = externalLink, !link.isEmpty {
            return link
        }
        // Fallback to internal file path: /file/resources/uid/filename
        // We'll need to prepend the server URL in the UI layer or here if we have context.
        // For now, return the internal path and handle it in the UI.
        return "/file/\(name)"
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
