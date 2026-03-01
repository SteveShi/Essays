import Foundation

struct Memo: Identifiable, Hashable, Equatable, Sendable {
    let name: String          // Full resource name, e.g. "memos/123" or "memos/uid"
    let numericID: Int  // Extracted numeric ID from name for legacy compat
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
        self.numericID = id
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

    var id: String { name }

    var truncatedContent: String {
        let lines = content.components(separatedBy: "\n")
        let limitedLines = lines.prefix(10)
        let joined = limitedLines.joined(separator: "\n")
        if joined.count > 500 {
            return String(joined.prefix(500)) + "…"
        }
        if lines.count > 10 {
            return joined + "\n…"
        }
        return joined
    }

    @MainActor
    var relativeCreatedAtDescription: String {
        Memo.relativeFormatter.localizedString(for: createdAt, relativeTo: Date())
    }

    @MainActor
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

struct Relation: Codable, Hashable, Equatable, Sendable {
    let memo: String  // The memo that has the relation
    let relatedMemo: String  // The memo that is related
    let type: RelationType

    enum CodingKeys: String, CodingKey {
        case memo, relatedMemo, type
    }

    // Struct to handle the dict format returned in Memos v0.22
    struct MemoRef: Codable {
        let name: String
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(RelationType.self, forKey: .type)

        if let memoStr = try? container.decode(String.self, forKey: .memo) {
            self.memo = memoStr
        } else {
            let ref = try container.decode(MemoRef.self, forKey: .memo)
            self.memo = ref.name
        }

        if let relatedMemoStr = try? container.decode(String.self, forKey: .relatedMemo) {
            self.relatedMemo = relatedMemoStr
        } else {
            let ref = try container.decode(MemoRef.self, forKey: .relatedMemo)
            self.relatedMemo = ref.name
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(memo, forKey: .memo)
        try container.encode(relatedMemo, forKey: .relatedMemo)
    }

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

struct Attachment: Codable, Identifiable, Hashable, Sendable {
    let name: String
    let filename: String
    let type: String
    let size: Int64
    let content: String?
    var externalLink: String?
    let createTime: Date?
    let memo: String?

    enum CodingKeys: String, CodingKey {
        case name, filename, type, size, content, externalLink, createTime, memo
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
        content = try container.decodeIfPresent(String.self, forKey: .content)
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
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(externalLink, forKey: .externalLink)
        try container.encodeIfPresent(createTime, forKey: .createTime)
        try container.encodeIfPresent(memo, forKey: .memo)
    }
    
    var id: String { name }
    
    var isImage: Bool {
        let normalizedType = type.lowercased()
        if normalizedType.hasPrefix("image/") {
            return true
        }
        let lowerFilename = filename.lowercased()
        return [".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".bmp", ".svg"].contains {
            lowerFilename.hasSuffix($0)
        }
    }

    var embeddedContentData: Data? {
        guard let content, !content.isEmpty else { return nil }
        let raw = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let commaIndex = raw.firstIndex(of: ","), raw[..<commaIndex].contains("base64") {
            let payload = String(raw[raw.index(after: commaIndex)...])
            return Data(base64Encoded: payload, options: [.ignoreUnknownCharacters])
        }
        return Data(base64Encoded: raw, options: [.ignoreUnknownCharacters])
    }

    func resolvedURLs(serverURL: String) -> [URL] {
        let normalizedBaseURL =
            serverURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var candidates: [URL] = []

        if let link = externalLink?.trimmingCharacters(in: .whitespacesAndNewlines), !link.isEmpty {
            if let absoluteURL = URL(string: link), absoluteURL.scheme != nil {
                candidates.append(absoluteURL)
            } else if !normalizedBaseURL.isEmpty {
                if link.hasPrefix("/") {
                    if let url = URL(string: normalizedBaseURL + link) {
                        candidates.append(url)
                    }
                } else if let url = URL(string: normalizedBaseURL + "/" + link) {
                    candidates.append(url)
                }
            } else if let url = URL(string: link) {
                candidates.append(url)
            }
        }

        guard !normalizedBaseURL.isEmpty else { return candidates }
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let encodedFilename =
            filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename

        if !encodedFilename.isEmpty {
            if let url = URL(
                string: normalizedBaseURL + "/file/" + encodedName + "/" + encodedFilename)
            {
                candidates.append(url)
            }
            if name.hasPrefix("resources/"), let uid = name.split(separator: "/").last {
                if let url = URL(string: normalizedBaseURL + "/o/r/\(uid)") {
                    candidates.append(url)
                }
                if let url = URL(string: normalizedBaseURL + "/o/r/\(uid)/" + encodedFilename) {
                    candidates.append(url)
                }
                if let url = URL(
                    string: normalizedBaseURL + "/file/attachments/\(uid)/" + encodedFilename)
                {
                    candidates.append(url)
                }
            }
            if name.hasPrefix("attachments/"), let uid = name.split(separator: "/").last {
                if let url = URL(string: normalizedBaseURL + "/o/r/\(uid)") {
                    candidates.append(url)
                }
                if let url = URL(string: normalizedBaseURL + "/o/r/\(uid)/" + encodedFilename) {
                    candidates.append(url)
                }
                if let url = URL(
                    string: normalizedBaseURL + "/file/attachments/\(uid)/" + encodedFilename)
                {
                    candidates.append(url)
                }
            }
        }
        if let url = URL(string: normalizedBaseURL + "/file/" + encodedName) {
            candidates.append(url)
        }

        var deduped: [URL] = []
        var seen: Set<String> = []
        for url in candidates {
            let key = url.absoluteString
            if !seen.contains(key) {
                seen.insert(key)
                deduped.append(url)
            }
        }
        return deduped
    }

    func resolvedURL(serverURL: String) -> URL? {
        resolvedURLs(serverURL: serverURL).first
    }
}

struct Tag: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    var count: Int
    
    init(name: String, count: Int = 0) {
        self.id = UUID()
        self.name = name
        self.count = count
    }
}

struct User: Codable, Identifiable, Sendable {
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
