import Foundation
import OSLog

/// Memos API v0.29 实现。
///
/// v0.29 在核心 memo API 上与 v0.27 完全兼容，无破坏性变更。
/// 主要新增：Link metadata 端点（Web 功能）、SMTP 通知设置、Shortcut 服务、
/// InstanceProfile.commit 字段、资源统计扩展。
/// 本实现通过组合复用 v0.27 实现，并在 InstanceProfile 中添加 commit 字段解码。
struct MemosAPIV029: MemosAPIProtocol {
    private let inner: MemosAPIV027

    init(baseURL: String, accessToken: String) {
        self.inner = MemosAPIV027(baseURL: baseURL, accessToken: accessToken)
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
