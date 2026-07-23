import Foundation

/// 表示使用的 Memos API 规范版本
enum MemosAPIVersion: String, Codable, Sendable, CaseIterable {
    case v1 = "v1"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        if let version = MemosAPIVersion(rawValue: rawValue) {
            self = version
        } else {
            // 兼容历史版本字符串 (v0.26 / v0.27 / v0.30 等) 统一归纳为 v1 规范
            self = .v1
        }
    }
}

/// 表示一个已保存的账户（本地模式或远程模式）
struct Account: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var mode: AccountMode
    /// 每个账户独立的数据目录（数据库文件会存储在该目录下）
    var dataDirectoryPath: String? = nil

    // MARK: - 远程模式字段
    var serverURL: String?
    // 注意：accessToken 已移至 Keychain 存储，使用 KeychainManager 访问
    var username: String?
    var apiVersion: MemosAPIVersion?

    enum AccountMode: String, Codable, Sendable {
        case local
        case remote
    }

    /// 创建本地模式账户
    static func localAccount(
        displayName: String = String(localized: "Local Account", comment: "Default local account name"),
        dataDirectoryPath: String? = nil
    ) -> Account {
        Account(
            id: UUID(),
            displayName: displayName,
            mode: .local,
            dataDirectoryPath: dataDirectoryPath
        )
    }

    /// 创建远程模式账户
    static func remoteAccount(
        displayName: String,
        serverURL: String,
        apiVersion: MemosAPIVersion = .v1,
        username: String? = nil,
        dataDirectoryPath: String? = nil
    ) -> Account {
        Account(
            id: UUID(),
            displayName: displayName,
            mode: .remote,
            dataDirectoryPath: dataDirectoryPath,
            serverURL: serverURL,
            username: username,
            apiVersion: apiVersion
        )
    }
}
