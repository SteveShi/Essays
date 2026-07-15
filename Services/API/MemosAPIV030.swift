import Foundation

/// Memos API v0.30 实现。
///
/// v0.30 主要重构了编辑器、增加了 OpenAPI MCP 模块并强制私有，
/// 其核心 API 与 v0.29 兼容。本实现通过组合复用 v0.29 实现。
struct MemosAPIV030: MemosAPIProtocol {
    private let inner: MemosAPIV029

    init(baseURL: String, accessToken: String) {
        self.inner = MemosAPIV029(baseURL: baseURL, accessToken: accessToken)
    }

    func checkServerStatus() async throws -> String {
        try await inner.checkServerStatus()
    }

    func signIn(username: String, password: String) async throws -> (user: User, accessToken: String?) {
        try await inner.signIn(username: username, password: password)
    }

    func getCurrentUser() async throws -> User {
        try await inner.getCurrentUser()
    }

    func fetchMemos() async throws -> [Memo] {
        try await inner.fetchMemos()
    }

    func fetchTags() async throws -> [Tag] {
        try await inner.fetchTags()
    }

    func createMemo(
        content: String, visibility: MemoVisibility?, tags: [String]?,
        pinned: Bool?, attachmentNames: [String]?, location: LocationDTO?
    ) async throws -> Memo {
        try await inner.createMemo(
            content: content, visibility: visibility, tags: tags,
            pinned: pinned, attachmentNames: attachmentNames, location: location)
    }

    func updateMemo(
        memoName: String, content: String, visibility: MemoVisibility?,
        tags: [String]?, pinned: Bool?, attachmentNames: [String]?, location: LocationDTO?
    ) async throws -> Memo {
        try await inner.updateMemo(
            memoName: memoName, content: content, visibility: visibility,
            tags: tags, pinned: pinned, attachmentNames: attachmentNames, location: location)
    }

    func deleteMemo(memoId: String) async throws {
        try await inner.deleteMemo(memoId: memoId)
    }

    func archiveMemo(memoName: String) async throws -> Memo {
        try await inner.archiveMemo(memoName: memoName)
    }

    func unarchiveMemo(memoName: String) async throws -> Memo {
        try await inner.unarchiveMemo(memoName: memoName)
    }

    func togglePinMemo(pinned: Bool, memoName: String) async throws -> Memo {
        try await inner.togglePinMemo(pinned: pinned, memoName: memoName)
    }

    func uploadAttachment(data: Data, filename: String, mimeType: String) async throws -> Attachment {
        try await inner.uploadAttachment(data: data, filename: filename, mimeType: mimeType)
    }

    func fetchComments(parentId: String) async throws -> [Memo] {
        try await inner.fetchComments(parentId: parentId)
    }

    func createComment(parentId: String, content: String, visibility: MemoVisibility) async throws -> Memo {
        try await inner.createComment(parentId: parentId, content: content, visibility: visibility)
    }
}
