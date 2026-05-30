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

    func addAccount(_ account: Account) {
        accounts.append(account)
        saveAccounts()
    }

    /// 添加账户并保存访问令牌到 Keychain
    func addAccount(_ account: Account, accessToken: String?) {
        accounts.append(account)
        saveAccounts()

        if let token = accessToken {
            try? KeychainManager.saveToken(token, for: account.id)
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
        }
    }

    // MARK: - 切换账户

    /// 设置活跃账户并触发配置刷新
    func setActiveAccount(_ account: Account) {
        activeAccountID = account.id
        saveActiveID()

        // 确保账户已保存
        if !accounts.contains(where: { $0.id == account.id }) {
            addAccount(account)
        }
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
