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
