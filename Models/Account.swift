import Foundation

/// 表示使用的 Memos API 版本
enum MemosAPIVersion: String, Codable, Sendable, CaseIterable {
    case v027 = "v0.27"
    case v026 = "v0.26"
}

/// 表示一个已保存的账户（本地模式或远程模式）
struct Account: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var mode: AccountMode

    // MARK: - 远程模式字段
    var serverURL: String?
    var accessToken: String?
    var username: String?
    var apiVersion: MemosAPIVersion?

    enum AccountMode: String, Codable, Sendable {
        case local
        case remote
    }

    /// 创建本地模式账户
    static func localAccount(
        displayName: String = String(localized: "Local Account", comment: "Default local account name")
    ) -> Account {
        Account(
            id: UUID(),
            displayName: displayName,
            mode: .local
        )
    }

    /// 创建远程模式账户
    static func remoteAccount(
        displayName: String,
        serverURL: String,
        apiVersion: MemosAPIVersion = .v027,
        accessToken: String? = nil,
        username: String? = nil
    ) -> Account {
        Account(
            id: UUID(),
            displayName: displayName,
            mode: .remote,
            serverURL: serverURL,
            accessToken: accessToken,
            username: username,
            apiVersion: apiVersion
        )
    }
}
