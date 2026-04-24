import Foundation
import SwiftData
import Observation

@MainActor
@Observable
class MemosAPIClient {
    static let shared = MemosAPIClient()
    
    private var strategy: (any MemosAPIProtocol)?
    private var _serverURL: String = ""
    private var _accessToken: String = ""
    
    var serverURL: String { _serverURL }
    var accessToken: String { _accessToken }
    
    private init() {}
    
    func configure(serverURL: String, accessToken: String, apiVersion: MemosAPIVersion = .v027) {
        self._serverURL = serverURL
        self._accessToken = accessToken
        
        switch apiVersion {
        case .v027:
            self.strategy = MemosAPIV027(baseURL: serverURL, accessToken: accessToken)
        case .v026:
            self.strategy = MemosAPIV026(baseURL: serverURL, accessToken: accessToken)
        }
    }
    
    private var activeStrategy: any MemosAPIProtocol {
        get throws {
            guard let strategy = strategy else {
                throw MemosAPIError.invalidURL
            }
            return strategy
        }
    }
    
    func checkServerStatus() async throws -> String {
        return try await activeStrategy.checkServerStatus()
    }
    
    func signIn(username: String, password: String) async throws -> User {
        let result = try await activeStrategy.signIn(username: username, password: password)
        if let token = result.accessToken, !token.isEmpty {
            self._accessToken = token
        }
        return result.user
    }
    
    func getCurrentUser() async throws -> User {
        return try await activeStrategy.getCurrentUser()
    }
    
    func fetchMemos() async throws -> [Memo] {
        let memos = try await activeStrategy.fetchMemos()
        return LocalDatabase.shared.syncMemosSnapshot(memos)
    }
    
    func fetchTags() async throws -> [Tag] {
        return try await activeStrategy.fetchTags()
    }
    
    func createMemo(
        content: String, visibility: MemoVisibility? = nil, tags: [String]? = nil,
        pinned: Bool? = nil, attachmentNames: [String]? = nil, location: Location? = nil
    ) async throws -> Memo {
        let memo = try await activeStrategy.createMemo(
            content: content,
            visibility: visibility,
            tags: tags,
            pinned: pinned,
            attachmentNames: attachmentNames,
            location: location.map { LocationDTO(placeholder: $0.placeholder, latitude: $0.latitude, longitude: $0.longitude) }
        )
        return LocalDatabase.shared.upsertMemos([memo]).first(where: { $0.name == memo.name }) ?? memo
    }
    
    func updateMemo(
        memoName: String, content: String, visibility: MemoVisibility? = nil,
        tags: [String]? = nil, pinned: Bool? = nil, attachmentNames: [String]? = nil, location: Location? = nil
    ) async throws -> Memo {
        let memo = try await activeStrategy.updateMemo(
            memoName: memoName,
            content: content,
            visibility: visibility,
            tags: tags,
            pinned: pinned,
            attachmentNames: attachmentNames,
            location: location.map { LocationDTO(placeholder: $0.placeholder, latitude: $0.latitude, longitude: $0.longitude) }
        )
        return LocalDatabase.shared.upsertMemos([memo]).first(where: { $0.name == memo.name }) ?? memo
    }
    
    func deleteMemo(memoName: String) async throws {
        try await activeStrategy.deleteMemo(memoId: memoName)
    }
    
    func togglePinMemo(pinned: Bool, memoName: String) async throws -> Memo {
        let memo = try await activeStrategy.togglePinMemo(pinned: pinned, memoName: memoName)
        return LocalDatabase.shared.upsertMemos([memo]).first(where: { $0.name == memo.name }) ?? memo
    }
    
    func archiveMemo(memoName: String) async throws -> Memo {
        let memo = try await activeStrategy.archiveMemo(memoName: memoName)
        return LocalDatabase.shared.upsertMemos([memo]).first(where: { $0.name == memo.name }) ?? memo
    }
    
    func unarchiveMemo(memoName: String) async throws -> Memo {
        let memo = try await activeStrategy.unarchiveMemo(memoName: memoName)
        return LocalDatabase.shared.upsertMemos([memo]).first(where: { $0.name == memo.name }) ?? memo
    }
    func uploadAttachment(data: Data, filename: String, mimeType: String) async throws -> Attachment {
        return try await activeStrategy.uploadAttachment(data: data, filename: filename, mimeType: mimeType)
    }
    

    func fetchComments(parentId: String) async throws -> [Memo] {
        return try await activeStrategy.fetchComments(parentId: parentId)
    }
    
    func createComment(parentId: String, content: String, visibility: MemoVisibility = .private) async throws -> Memo {
        let memo = try await activeStrategy.createComment(parentId: parentId, content: content, visibility: visibility)
        return LocalDatabase.shared.upsertMemos([memo]).first(where: { $0.name == memo.name }) ?? memo
    }
}
