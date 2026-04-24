import Foundation
import SwiftData

@Model
final class OutboxTask {
    @Attribute(.unique)
    var id: UUID
    
    /// 任务类型（例如：CREATE_MEMO, UPDATE_MEMO, DELETE_MEMO）
    var typeRaw: String
    
    /// 任务的负载数据，采用 JSON 编码
    var payload: Data
    
    /// 任务的当前状态（Pending: 0, Running: 1, Error: 2, Retry: 3）
    var stateRaw: Int
    
    /// 重试次数
    var attempts: Int
    
    /// 最后一次错误信息
    var lastError: String?
    
    /// 创建时间
    var createdAt: Date
    
    /// 下次重试时间
    var retryAt: Date?
    
    var memoId: String? // Optional reference to the local memo ID this task affects

    init(
        id: UUID = UUID(),
        type: OutboxTaskType,
        payload: Data,
        state: OutboxTaskState = .pending,
        attempts: Int = 0,
        lastError: String? = nil,
        createdAt: Date = Date(),
        retryAt: Date? = nil,
        memoId: String? = nil
    ) {
        self.id = id
        self.typeRaw = type.rawValue
        self.payload = payload
        self.stateRaw = state.rawValue
        self.attempts = attempts
        self.lastError = lastError
        self.createdAt = createdAt
        self.retryAt = retryAt
        self.memoId = memoId
    }
    
    var type: OutboxTaskType {
        get { OutboxTaskType(rawValue: typeRaw) ?? .unknown }
        set { typeRaw = newValue.rawValue }
    }
    
    var state: OutboxTaskState {
        get { OutboxTaskState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }
    
    var contentSummary: String? {
        switch type {
        case .createMemo:
            return (try? JSONDecoder().decode(CreateMemoPayload.self, from: payload))?.content
        case .updateMemo:
            return (try? JSONDecoder().decode(UpdateMemoPayload.self, from: payload))?.content
        case .togglePinMemo:
            return (try? JSONDecoder().decode(TogglePinPayload.self, from: payload))?.contentSummary
        default:
            return (try? JSONDecoder().decode(SimpleMemoPayload.self, from: payload))?.contentSummary
        }
    }
}

enum OutboxTaskType: String, Codable {
    case createMemo = "CREATE_MEMO"
    case updateMemo = "UPDATE_MEMO"
    case deleteMemo = "DELETE_MEMO"
    case togglePinMemo = "TOGGLE_PIN_MEMO"
    case archiveMemo = "ARCHIVE_MEMO"
    case unarchiveMemo = "UNARCHIVE_MEMO"
    case unknown = "UNKNOWN"
}

enum OutboxTaskState: Int, Codable {
    case pending = 0
    case running = 1
    case error = 2
    case retry = 3
    case completed = 4
}


// MARK: - Payloads

struct CreateMemoPayload: Codable {
    let content: String
    let visibility: String?
    let pinned: Bool?
    let tags: [String]?
    let attachmentNames: [String]?
    let locationPlaceholder: String?
    let locationLatitude: Double?
    let locationLongitude: Double?
    let accountID: String?

    init(
        content: String,
        visibility: String?,
        pinned: Bool?,
        tags: [String]?,
        attachmentNames: [String]?,
        locationPlaceholder: String?,
        locationLatitude: Double?,
        locationLongitude: Double?,
        accountID: String? = nil
    ) {
        self.content = content
        self.visibility = visibility
        self.pinned = pinned
        self.tags = tags
        self.attachmentNames = attachmentNames
        self.locationPlaceholder = locationPlaceholder
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.accountID = accountID
    }
}

struct UpdateMemoPayload: Codable {
    let content: String
    let visibility: String?
    let pinned: Bool?
    let tags: [String]?
    let attachmentNames: [String]?
    let locationPlaceholder: String?
    let locationLatitude: Double?
    let locationLongitude: Double?
    let accountID: String?

    init(
        content: String,
        visibility: String?,
        pinned: Bool?,
        tags: [String]?,
        attachmentNames: [String]?,
        locationPlaceholder: String?,
        locationLatitude: Double?,
        locationLongitude: Double?,
        accountID: String? = nil
    ) {
        self.content = content
        self.visibility = visibility
        self.pinned = pinned
        self.tags = tags
        self.attachmentNames = attachmentNames
        self.locationPlaceholder = locationPlaceholder
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.accountID = accountID
    }
}

struct TogglePinPayload: Codable {
    let pinned: Bool
    let contentSummary: String?
    let accountID: String?

    init(pinned: Bool, contentSummary: String?, accountID: String? = nil) {
        self.pinned = pinned
        self.contentSummary = contentSummary
        self.accountID = accountID
    }
}

struct SimpleMemoPayload: Codable {
    let contentSummary: String
    let accountID: String?

    init(contentSummary: String, accountID: String? = nil) {
        self.contentSummary = contentSummary
        self.accountID = accountID
    }
}
