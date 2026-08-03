import Foundation
import Observation

/// 多账户管理器，负责账户的持久化存储、切换和生命周期管理
@MainActor
@Observable
final class AccountManager {
    static let shared = AccountManager()

    private static let accountsKey = "Essays.savedAccounts"
    private static let activeAccountIDKey = "Essays.activeAccountID"

    private(set) var accounts: [Account] = []
    private(set) var activeAccountID: UUID?

    var activeAccount: Account? {
        guard let id = activeAccountID else { return nil }
        return accounts.first { $0.id == id }
    }

    /// 获取活跃账户的访问令牌（从 Keychain 读取）
    var activeAccessToken: String? {
        guard let id = activeAccountID else { return nil }
        return try? KeychainManager.getToken(for: id)
    }

    var isLocalMode: Bool {
        activeAccount?.mode == .local
    }

    private init() {
        loadAccounts()
    }

    // MARK: - 持久化

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: Self.accountsKey),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = decoded
        }

        if let idString = UserDefaults.standard.string(forKey: Self.activeAccountIDKey),
           let id = UUID(uuidString: idString) {
            activeAccountID = id
        }

        sanitizeAccounts()
    }

    private func sanitizeAccounts() {
        var uniqueAccounts: [Account] = []
        var removedIDs: [UUID] = []

        for acc in accounts {
            if let existingIndex = uniqueAccounts.firstIndex(where: { $0.isSameAccount(as: acc) }) {
                var preserved = uniqueAccounts[existingIndex]
                if preserved.displayName.isEmpty && !acc.displayName.isEmpty {
                    preserved.displayName = acc.displayName
                }
                if (preserved.dataDirectoryPath?.isEmpty ?? true) && !(acc.dataDirectoryPath?.isEmpty ?? true) {
                    preserved.dataDirectoryPath = acc.dataDirectoryPath
                }
                uniqueAccounts[existingIndex] = preserved
                removedIDs.append(acc.id)
            } else {
                uniqueAccounts.append(acc)
            }
        }

        if !removedIDs.isEmpty || uniqueAccounts.count != accounts.count {
            accounts = uniqueAccounts
            saveAccounts()
            for id in removedIDs {
                try? KeychainManager.deleteToken(for: id)
            }
            if let activeID = activeAccountID, removedIDs.contains(activeID) {
                activeAccountID = accounts.first(where: { $0.id != activeID })?.id ?? accounts.first?.id
                saveActiveID()
            }
        }
    }

    private func saveAccounts() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: Self.accountsKey)
        }
    }

    private func saveActiveID() {
        UserDefaults.standard.set(activeAccountID?.uuidString, forKey: Self.activeAccountIDKey)
    }

    // MARK: - CRUD

    /// 添加或更新账户（依据 UUID 或账户核心属性自动判重去重）
    @discardableResult
    func addAccount(_ account: Account, accessToken: String? = nil) -> Account {
        if let index = accounts.firstIndex(where: { $0.id == account.id || $0.isSameAccount(as: account) }) {
            var existing = accounts[index]
            existing.displayName = account.displayName
            if let dataDir = account.dataDirectoryPath, !dataDir.isEmpty {
                existing.dataDirectoryPath = dataDir
            }
            if let serverURL = account.serverURL, !serverURL.isEmpty {
                existing.serverURL = serverURL
            }
            if let username = account.username, !username.isEmpty {
                existing.username = username
            }
            if let apiVersion = account.apiVersion {
                existing.apiVersion = apiVersion
            }
            accounts[index] = existing
            saveAccounts()

            if let token = accessToken {
                try? KeychainManager.saveToken(token, for: existing.id)
            }
            return existing
        } else {
            accounts.append(account)
            saveAccounts()

            if let token = accessToken {
                try? KeychainManager.saveToken(token, for: account.id)
            }
            return account
        }
    }

    func removeAccount(_ account: Account) {
        accounts.removeAll { $0.id == account.id }
        if activeAccountID == account.id {
            activeAccountID = nil
            saveActiveID()
        }
        saveAccounts()

        // 从 Keychain 删除令牌
        try? KeychainManager.deleteToken(for: account.id)
    }

    func updateAccount(_ account: Account) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()
        } else {
            _ = addAccount(account)
        }
    }

    /// 更新账户并保存访问令牌到 Keychain
    func updateAccount(_ account: Account, accessToken: String?) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
            saveAccounts()

            if let token = accessToken {
                try? KeychainManager.saveToken(token, for: account.id)
            }
        } else {
            _ = addAccount(account, accessToken: accessToken)
        }
    }

    // MARK: - 切换账户

    /// 设置活跃账户并触发配置刷新
    func setActiveAccount(_ account: Account) {
        let targetAccount = addAccount(account)
        activeAccountID = targetAccount.id
        saveActiveID()
    }

    /// 退出当前活跃账户（不删除，仅解除活跃状态）
    func deactivateCurrentAccount() {
        activeAccountID = nil
        saveActiveID()
    }

    /// 退出并删除当前活跃账户
    func signOutCurrentAccount() {
        if let id = activeAccountID {
            accounts.removeAll { $0.id == id }
            saveAccounts()
            // 从 Keychain 删除令牌
            try? KeychainManager.deleteToken(for: id)
        }
        activeAccountID = nil
        saveActiveID()
    }

    /// 清除所有账户数据
    func clearAllAccounts() {
        accounts = []
        activeAccountID = nil
        saveAccounts()
        saveActiveID()
        // 清除所有 Keychain 令牌
        try? KeychainManager.deleteAllTokens()
    }
}

