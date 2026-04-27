import Foundation

/// 标准的 Memos API 错误
enum MemosAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case unauthorized
    case serverError(String)
    case decodingError(Error)
    case unsupportedVersion
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return String(localized: "Invalid URL")
        case .invalidResponse: return String(localized: "Invalid server response")
        case .httpError(let code): return String(localized: "HTTP Error: \(code)")
        case .unauthorized: return String(localized: "Unauthorized. Please check your credentials.")
        case .serverError(let msg): return String(localized: "Server Error: \(msg)")
        case .decodingError(let err): return String(localized: "Data decoding failed: \(err.localizedDescription)")
        case .unsupportedVersion: return String(localized: "Unsupported Memos API version")
        }
    }
}

/// Memos API 协议定义，支持多版本适配

/// 数据传输对象：位置
struct LocationDTO: Sendable {
    let placeholder: String?
    let latitude: Double
    let longitude: Double
    
    init(placeholder: String?, latitude: Double, longitude: Double) {
        self.placeholder = placeholder
        self.latitude = latitude
        self.longitude = longitude
    }
}


protocol MemosAPIProtocol: Sendable {
    func checkServerStatus() async throws -> String
    func signIn(username: String, password: String) async throws -> (user: User, accessToken: String?)
    func getCurrentUser() async throws -> User
    func fetchMemos() async throws -> [Memo]
    func fetchTags() async throws -> [Tag]
    
    func createMemo(
        content: String, visibility: MemoVisibility?, tags: [String]?,
        pinned: Bool?, attachmentNames: [String]?, location: LocationDTO?
    ) async throws -> Memo
    
    func updateMemo(
        memoName: String, content: String, visibility: MemoVisibility?,
        tags: [String]?, pinned: Bool?, attachmentNames: [String]?, location: LocationDTO?
    ) async throws -> Memo
    
    func deleteMemo(memoId: String) async throws
    
    
    func uploadAttachment(data: Data, filename: String, mimeType: String) async throws -> Attachment
    
    
    func archiveMemo(memoName: String) async throws -> Memo
    func unarchiveMemo(memoName: String) async throws -> Memo
    func togglePinMemo(pinned: Bool, memoName: String) async throws -> Memo

    func fetchComments(parentId: String) async throws -> [Memo]
    func createComment(parentId: String, content: String, visibility: MemoVisibility) async throws -> Memo
}

/// 跨 Memos API 版本共享的 JSON 解码器。
///
/// `convertFromSnakeCase` + ISO8601 多格式 + DateFormatter 兜底是 Memos
/// gRPC-gateway 通用 wire format，跨版本一致。如未来某版本需要不同配置，
/// 可在该版本实现内定义私有 decoder 直接覆盖使用，与本 shared 实例共存。
enum MemosAPIDecoder {
    static let shared: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let formatters: [ISO8601DateFormatter] = [
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    return f
                }(),
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }

            // Memos Go 后端偶尔返回更长精度的小数秒，ISO8601DateFormatter 无法识别。
            let commonDateFormatter = DateFormatter()
            commonDateFormatter.calendar = Calendar(identifier: .iso8601)
            commonDateFormatter.locale = Locale(identifier: "en_US_POSIX")
            commonDateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            let possibleFormats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
                "yyyy-MM-dd'T'HH:mm:ssXXXXX",
            ]

            for format in possibleFormats {
                commonDateFormatter.dateFormat = format
                if let date = commonDateFormatter.date(from: dateString) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }()
}

extension Relation.RelationType {
    /// 将服务端返回的字符串归一化到本地枚举；未知值落入 `.unspecified`。
    static func parse(_ rawValue: String) -> Relation.RelationType {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if normalized.contains("COMMENT") {
            return .comment
        }
        if normalized.contains("REFERENCE") {
            return .reference
        }
        return Relation.RelationType(rawValue: normalized) ?? .unspecified
    }
}
