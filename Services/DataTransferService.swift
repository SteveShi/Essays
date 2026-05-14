import Foundation

@MainActor
enum DataTransferService {
    static let archiveFileExtension = "json"

    static func exportArchive(forAccountID accountID: String) throws -> Data {
        let memos = LocalDatabase.shared.fetchMemos(forAccountID: accountID)
        let archive = EssaysDataArchive(
            metadata: .init(
                exportedAt: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                accountID: accountID
            ),
            memos: memos.map { EssaysDataArchive.MemoRecord(memo: $0) }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    @discardableResult
    static func importArchive(
        from data: Data,
        intoAccountID accountID: String,
        replaceExisting: Bool
    ) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(EssaysDataArchive.self, from: data)
        let memos = archive.memos.map { $0.makeMemo(accountID: accountID) }
        LocalDatabase.shared.importMemos(memos, forAccountID: accountID, replaceExisting: replaceExisting)
        return memos.count
    }
}

struct EssaysDataArchive: Codable {
    let formatVersion: Int
    let metadata: Metadata
    let memos: [MemoRecord]

    init(formatVersion: Int = 1, metadata: Metadata, memos: [MemoRecord]) {
        self.formatVersion = formatVersion
        self.metadata = metadata
        self.memos = memos
    }

    struct Metadata: Codable {
        let exportedAt: Date
        let appVersion: String?
        let accountID: String
    }

    struct MemoRecord: Codable {
        let name: String
        let numericID: String
        let content: String
        let createdAt: Date
        let updatedAt: Date
        let visibilityRaw: String
        let pinned: Bool
        let tags: [String]
        let stateRaw: String
        let accountID: String?
        let isPendingSync: Bool
        let attachments: [AttachmentRecord]
        let location: LocationRecord?
        let relations: [RelationRecord]

        init(memo: Memo) {
            self.name = memo.name
            self.numericID = memo.numericID
            self.content = memo.content
            self.createdAt = memo.createdAt
            self.updatedAt = memo.updatedAt
            self.visibilityRaw = memo.visibilityRaw
            self.pinned = memo.pinned
            self.tags = memo.tags
            self.stateRaw = memo.stateRaw
            self.accountID = memo.accountID
            self.isPendingSync = memo.isPendingSync
            self.attachments = memo.attachments.map { AttachmentRecord(attachment: $0) }
            self.location = memo.location.map { LocationRecord(location: $0) }
            self.relations = memo.relations.map { RelationRecord(relation: $0) }
        }

        func makeMemo(accountID: String) -> Memo {
            let memo = Memo(
                name: name,
                numericID: numericID,
                content: content,
                createdAt: createdAt,
                updatedAt: updatedAt,
                visibility: MemoVisibility(rawValue: visibilityRaw) ?? .private,
                pinned: pinned,
                state: MemoState(rawValue: stateRaw) ?? .normal,
                tags: tags,
                attachments: [],
                location: nil,
                relations: [],
                accountID: accountID,
                isPendingSync: false
            )

            memo.attachments = attachments.map { $0.makeAttachment(parentMemo: memo) }
            memo.location = location?.makeLocation(parentMemo: memo)
            memo.relations = relations.map { $0.makeRelation(parentMemo: memo) }
            return memo
        }
    }

    struct AttachmentRecord: Codable {
        let name: String
        let filename: String
        let type: String
        let size: Int64
        let content: String?
        let externalLink: String?
        let createTime: Date?
        let memoName: String?

        init(attachment: Attachment) {
            self.name = attachment.name
            self.filename = attachment.filename
            self.type = attachment.type
            self.size = attachment.size
            self.content = attachment.content
            self.externalLink = attachment.externalLink
            self.createTime = attachment.createTime
            self.memoName = attachment.memoName
        }

        func makeAttachment(parentMemo: Memo) -> Attachment {
            Attachment(
                name: name,
                filename: filename,
                type: type,
                size: size,
                content: content,
                externalLink: externalLink,
                createTime: createTime,
                memoName: memoName ?? parentMemo.name,
                parentMemo: parentMemo
            )
        }
    }

    struct LocationRecord: Codable {
        let placeholder: String?
        let latitude: Double
        let longitude: Double

        init(location: Location) {
            self.placeholder = location.placeholder
            self.latitude = location.latitude
            self.longitude = location.longitude
        }

        func makeLocation(parentMemo: Memo) -> Location {
            Location(
                placeholder: placeholder,
                latitude: latitude,
                longitude: longitude,
                parentMemo: parentMemo
            )
        }
    }

    struct RelationRecord: Codable {
        let memo: String
        let relatedMemo: String
        let typeRaw: String

        init(relation: Relation) {
            self.memo = relation.memo
            self.relatedMemo = relation.relatedMemo
            self.typeRaw = relation.typeRaw
        }

        func makeRelation(parentMemo: Memo) -> Relation {
            Relation(
                memo: memo,
                relatedMemo: relatedMemo,
                type: Relation.RelationType(rawValue: typeRaw) ?? .unspecified,
                parentMemo: parentMemo
            )
        }
    }
}
