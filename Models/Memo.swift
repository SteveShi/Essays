import Foundation
import SwiftData

@Model
final class Memo: Identifiable {
    @Attribute(.unique) var name: String  // Full resource name, e.g. "memos/123"
    var numericID: Int
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var visibilityRaw: String
    var pinned: Bool
    var tags: [String]
    var isPendingSync: Bool = false

    // Relationships
    @Relationship(deleteRule: .cascade, inverse: \Attachment.parentMemo) var attachments:
        [Attachment]
    @Relationship(deleteRule: .cascade, inverse: \Location.parentMemo) var location: Location?
    @Relationship(deleteRule: .cascade, inverse: \Relation.parentMemo) var relations: [Relation]
    
    var id: String { name }
    
    var visibility: MemoVisibility {
        get { MemoVisibility(rawValue: visibilityRaw) ?? .private }
        set { visibilityRaw = newValue.rawValue }
    }

    init(
        name: String = "",
        numericID: Int,
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        visibility: MemoVisibility = .private,
        pinned: Bool = false,
        tags: [String] = [],
        attachments: [Attachment] = [],
        location: Location? = nil,
        relations: [Relation] = [],
        isPendingSync: Bool = false
    ) {
        self.name = name.isEmpty ? "memos/pending-\(UUID().uuidString)" : name
        self.numericID = numericID
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.visibilityRaw = visibility.rawValue
        self.pinned = pinned
        self.tags = tags
        self.attachments = attachments
        self.location = location
        self.relations = relations
        self.isPendingSync = isPendingSync
    }
    func extractTagsFromContent() {
        self.tags = MemoUtility.extractTags(from: self.content)
    }
}

extension Memo {
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

@Model
final class Relation: Identifiable {
    var memo: String
    var relatedMemo: String
    var typeRaw: String
    var parentMemo: Memo?

    var type: RelationType {
        get { RelationType(rawValue: typeRaw) ?? .unspecified }
        set { typeRaw = newValue.rawValue }
    }

    init(memo: String, relatedMemo: String, type: RelationType, parentMemo: Memo? = nil) {
        self.memo = memo
        self.relatedMemo = relatedMemo
        self.typeRaw = type.rawValue
        self.parentMemo = parentMemo
    }

    var id: String {
        "\(memo)-\(relatedMemo)-\(typeRaw)"
    }

    enum RelationType: String, Codable, CaseIterable, Sendable {
        case reference = "REFERENCE"
        case comment = "COMMENT"
        case unspecified = "RELATION_TYPE_UNSPECIFIED"
    }
}

enum MemoVisibility: String, Codable, CaseIterable, Sendable {
    case `public` = "PUBLIC"
    case `protected` = "PROTECTED"
    case `private` = "PRIVATE"
    
    var displayName: String {
        switch self {
        case .public: return String(localized: "Public", comment: "Visibility status: Public")
        case .protected:
            return String(localized: "Workspace", comment: "Visibility status: Workspace")
        case .private: return String(localized: "Private", comment: "Visibility status: Private")
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

@Model
final class Attachment: Identifiable {
    @Attribute(.unique) var name: String
    var filename: String
    var type: String
    var size: Int64
    var content: String?
    var externalLink: String?
    var createTime: Date?
    var memoName: String?
    var parentMemo: Memo?

    init(
        name: String,
        filename: String,
        type: String,
        size: Int64,
        content: String? = nil,
        externalLink: String? = nil,
        createTime: Date? = nil,
        memoName: String? = nil,
        parentMemo: Memo? = nil
    ) {
        self.name = name
        self.filename = filename
        self.type = type
        self.size = size
        self.content = content
        self.externalLink = externalLink
        self.createTime = createTime
        self.memoName = memoName
        self.parentMemo = parentMemo
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
        let normalizedBaseURL = serverURL.trimmingCharacters(in: .whitespaces).trimmingCharacters(
            in: CharacterSet(charactersIn: "/"))
        var candidates: [URL] = []

        if let link = externalLink?.trimmingCharacters(in: .whitespaces), !link.isEmpty {
            if let absoluteURL = URL(string: link), absoluteURL.scheme != nil {
                candidates.append(absoluteURL)
            } else if !normalizedBaseURL.isEmpty {
                let separator = link.hasPrefix("/") ? "" : "/"
                if let url = URL(string: normalizedBaseURL + separator + link) {
                    candidates.append(url)
                }
            }
        }

        guard !normalizedBaseURL.isEmpty else { return candidates }
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let encodedFilename =
            filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename

        if !encodedFilename.isEmpty {
            let thumbnailQuery = "?thumbnail=true"
            if let url = URL(
                string: normalizedBaseURL + "/file/" + encodedName + "/" + encodedFilename
                    + thumbnailQuery)
            {
                candidates.append(url)
            }
        }
        if let url = URL(string: normalizedBaseURL + "/file/" + encodedName) {
            candidates.append(url)
        }

        var deduped: [URL] = []
        var seen: Set<String> = []
        for url in candidates {
            if !seen.contains(url.absoluteString) {
                seen.insert(url.absoluteString)
                deduped.append(url)
            }
        }
        return deduped
    }

    func resolvedURL(serverURL: String) -> URL? {
        resolvedURLs(serverURL: serverURL).first
    }
}
