import Foundation
import SwiftData

@Model
final class Memo: Identifiable {
    @Attribute(.unique) var name: String  // Full resource name, e.g. "memos/123"
    var numericID: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var visibilityRaw: String
    var pinned: Bool
    var tags: [String]
    var stateRaw: String = "NORMAL"
    var accountID: String?
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
    
    var state: MemoState {
        get { MemoState(rawValue: stateRaw) ?? .normal }
        set { stateRaw = newValue.rawValue }
    }

    init(
        name: String = "",
        numericID: String = "",
        content: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        visibility: MemoVisibility = .private,
        pinned: Bool = false,
        state: MemoState = .normal,
        tags: [String] = [],
        attachments: [Attachment] = [],
        location: Location? = nil,
        relations: [Relation] = [],
        accountID: String? = nil,
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
        self.stateRaw = state.rawValue
        self.accountID = accountID
        self.isPendingSync = isPendingSync
    }
    
    var commentCount: Int {
        // Defensive check: ensure the memo is still valid and connected to a context
        guard let context = modelContext, !name.isEmpty else { return 0 }
        
        let memoName = self.name
        let commentType = Relation.RelationType.comment.rawValue
        
        let descriptor = FetchDescriptor<Relation>(
            predicate: #Predicate<Relation> { rel in
                rel.typeRaw == commentType && (rel.memo == memoName || rel.relatedMemo == memoName)
            }
        )
        
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// A safe collection of relations that are currently valid and attached to a context
    var validRelations: [Relation] {
        guard let context = modelContext, !name.isEmpty else { return [] }
        
        let memoName = self.name
        
        let descriptor = FetchDescriptor<Relation>(
            predicate: #Predicate<Relation> { rel in
                rel.memo == memoName || rel.relatedMemo == memoName
            }
        )
        
        return (try? context.fetch(descriptor)) ?? []
    }
    func extractTagsFromContent() {
        self.tags = MemoUtility.extractTags(from: self.content)
    }
}

extension Memo {
    var isSystemCommentMemo: Bool {
        name.hasPrefix("local_comment_")
    }

    var contentWithoutTags: String {
        MemoUtility.stripTags(from: content)
    }

    var truncatedContent: String {
        Self.truncate(contentWithoutTags)
    }

    var relationPreviewContent: String {
        Self.truncate(MemoUtility.stripMarkdownLinks(from: contentWithoutTags))
    }

    /// Truncates content to at most `lineLimit` lines and `charLimit` characters, appending an ellipsis when clipped.
    private static func truncate(_ input: String, lineLimit: Int = 10, charLimit: Int = 500) -> String {
        let lines = input.components(separatedBy: "\n")
        let joined = lines.prefix(lineLimit).joined(separator: "\n")
        if joined.count > charLimit {
            return String(joined.prefix(charLimit)) + "…"
        }
        if lines.count > lineLimit {
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
    @Attribute(.unique) var relationID: String
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
        self.relationID = Self.identifier(memo: memo, relatedMemo: relatedMemo, type: type)
    }

    var id: String { relationID }

    static func identifier(memo: String, relatedMemo: String, type: RelationType) -> String {
        "\(memo)-\(relatedMemo)-\(type.rawValue)"
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

        var seen: Set<String> = []
        return candidates.filter { seen.insert($0.absoluteString).inserted }
    }

    func resolvedURL(serverURL: String) -> URL? {
        resolvedURLs(serverURL: serverURL).first
    }
}

enum MemoState: String, Codable, CaseIterable, Sendable {
    case normal = "NORMAL"
    case archived = "ARCHIVED"
}
