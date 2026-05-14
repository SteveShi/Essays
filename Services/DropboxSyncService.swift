import AuthenticationServices
import CryptoKit
import Foundation
import Observation

#if os(macOS)
import AppKit
#endif

@MainActor
@Observable
final class DropboxSyncService: NSObject {
    static let shared = DropboxSyncService()

    private static let appKeyKey = "Essays.Dropbox.AppKey"
    private static let refreshTokenKey = "Essays.Dropbox.RefreshToken"
    private static let cursorKey = "Essays.Dropbox.Cursor"
    private static let enabledKey = "Essays.Dropbox.Enabled"
    private static let rootPath = "/Essays"

    private let apiBaseURL = URL(string: "https://api.dropboxapi.com/2")!
    private let contentBaseURL = URL(string: "https://content.dropboxapi.com/2")!
    private let oauthURL = URL(string: "https://www.dropbox.com/oauth2/authorize")!
    private let tokenURL = URL(string: "https://api.dropboxapi.com/oauth2/token")!
    private let urlSession = URLSession.shared

    var appKey: String {
        didSet {
            UserDefaults.standard.set(appKey, forKey: Self.appKeyKey)
        }
    }
    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
        }
    }
    var isSyncing = false
    var lastSyncDate: Date?
    var lastStatusMessage: String?
    var lastErrorMessage: String?

    private var authSession: ASWebAuthenticationSession?
    private var authContinuation: CheckedContinuation<String, Error>?
    private var codeVerifier: String?

    var isAuthorized: Bool {
        refreshToken?.isEmpty == false
    }

    private var refreshToken: String? {
        get {
            UserDefaults.standard.string(forKey: Self.refreshTokenKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.refreshTokenKey)
        }
    }

    private var cursor: String? {
        get {
            UserDefaults.standard.string(forKey: Self.cursorKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.cursorKey)
        }
    }

    private override init() {
        self.appKey = UserDefaults.standard.string(forKey: Self.appKeyKey) ?? ""
        self.isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        super.init()
    }

    func authorize() async {
        let trimmedAppKey = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppKey.isEmpty else {
            lastErrorMessage = String(localized: "Please enter a Dropbox app key first.", comment: "Dropbox sync missing app key error")
            return
        }

        do {
            let code = try await requestAuthorizationCode(appKey: trimmedAppKey)
            let token = try await exchangeAuthorizationCode(code, appKey: trimmedAppKey)
            refreshToken = token.refreshToken
            isEnabled = true
            lastErrorMessage = nil
            lastStatusMessage = String(localized: "Dropbox connected.", comment: "Dropbox sync connected status")
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        refreshToken = nil
        cursor = nil
        isEnabled = false
        lastStatusMessage = String(localized: "Dropbox disconnected.", comment: "Dropbox sync disconnected status")
        lastErrorMessage = nil
    }

    func syncNow() async {
        guard AccountManager.shared.isLocalMode else {
            lastErrorMessage = String(localized: "Dropbox sync is only available in local mode.", comment: "Dropbox sync local mode only error")
            return
        }
        guard isEnabled, isAuthorized else {
            lastErrorMessage = String(localized: "Connect Dropbox before syncing.", comment: "Dropbox sync unauthorized error")
            return
        }
        guard !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let accessToken = try await accessToken()
            try await ensureRootFolder(accessToken: accessToken)
            try await pullRemoteChanges(accessToken: accessToken)
            try await uploadLocalChanges(accessToken: accessToken)
            LocalDatabase.shared.context.processPendingChanges()
            try? LocalDatabase.shared.context.save()
            lastSyncDate = Date()
            lastErrorMessage = nil
            lastStatusMessage = String(localized: "Dropbox sync completed.", comment: "Dropbox sync completed status")
            NotificationCenter.default.post(name: .syncCompleted, object: nil)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func recordLocalDeletion(memoName: String) {
        guard AccountManager.shared.isLocalMode, isEnabled, isAuthorized else { return }
        Task {
            do {
                let accessToken = try await accessToken()
                let tombstone = DropboxTombstoneRecord(
                    name: memoName,
                    deletedAt: Date(),
                    accountID: AccountManager.shared.activeAccount.map { AppState.accountIdentifier(for: $0) } ?? "local"
                )
                let data = try Self.encoder.encode(tombstone)
                try await upload(data: data, path: Self.tombstonePath(forMemoName: memoName), accessToken: accessToken)
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    func preferredDropboxEssaysFolder() -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/CloudStorage/Dropbox/Essays", isDirectory: true),
            home.appendingPathComponent("Dropbox/Essays", isDirectory: true)
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0.deletingLastPathComponent().path) }
    }

    private func requestAuthorizationCode(appKey: String) async throws -> String {
        let verifier = Self.randomCodeVerifier()
        codeVerifier = verifier

        var components = URLComponents(url: oauthURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: appKey),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "token_access_type", value: "offline"),
            URLQueryItem(name: "code_challenge", value: Self.codeChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "redirect_uri", value: "essays://dropbox-auth")
        ]
        guard let authorizationURL = components?.url else {
            throw DropboxSyncError.invalidAuthorizationURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            authContinuation = continuation
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: "essays"
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.authSession = nil
                    if let error {
                        self.authContinuation?.resume(throwing: error)
                        self.authContinuation = nil
                        return
                    }
                    guard let callbackURL,
                          let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                          let code = components.queryItems?.first(where: { $0.name == "code" })?.value
                    else {
                        self.authContinuation?.resume(throwing: DropboxSyncError.missingAuthorizationCode)
                        self.authContinuation = nil
                        return
                    }
                    self.authContinuation?.resume(returning: code)
                    self.authContinuation = nil
                }
            }
            #if os(macOS)
            session.presentationContextProvider = self
            #endif
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            session.start()
        }
    }

    private func exchangeAuthorizationCode(_ code: String, appKey: String) async throws -> DropboxTokenResponse {
        guard let verifier = codeVerifier else {
            throw DropboxSyncError.missingCodeVerifier
        }
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody([
            "code": code,
            "grant_type": "authorization_code",
            "client_id": appKey,
            "code_verifier": verifier,
            "redirect_uri": "essays://dropbox-auth"
        ])
        return try await performJSONRequest(request)
    }

    private func accessToken() async throws -> String {
        guard let refreshToken, !refreshToken.isEmpty else {
            throw DropboxSyncError.missingRefreshToken
        }
        let trimmedAppKey = appKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAppKey.isEmpty else {
            throw DropboxSyncError.missingAppKey
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody([
            "refresh_token": refreshToken,
            "grant_type": "refresh_token",
            "client_id": trimmedAppKey
        ])
        let response: DropboxTokenResponse = try await performJSONRequest(request)
        return response.accessToken
    }

    private func uploadLocalChanges(accessToken: String) async throws {
        let accountID = AccountManager.shared.activeAccount.map { AppState.accountIdentifier(for: $0) } ?? "local"
        let memos = LocalDatabase.shared.fetchMemos(forAccountID: accountID)
        for memo in memos {
            let record = DropboxMemoRecord(memo: memo)
            let data = try Self.encoder.encode(record)
            try await upload(data: data, path: Self.memoPath(forMemoName: memo.name), accessToken: accessToken)
        }
    }

    private func pullRemoteChanges(accessToken: String) async throws {
        let changes = try await listChanges(accessToken: accessToken)
        let accountID = AccountManager.shared.activeAccount.map { AppState.accountIdentifier(for: $0) } ?? "local"
        var incomingMemos: [Memo] = []
        var deletedMemoNames: [String] = []

        for entry in changes.entries where entry.tag == "file" {
            if entry.pathLower.hasPrefix("/essays/memos/") {
                let data = try await download(path: entry.pathDisplay, accessToken: accessToken)
                let record = try Self.decoder.decode(DropboxMemoRecord.self, from: data)
                incomingMemos.append(record.makeMemo(accountID: accountID))
            } else if entry.pathLower.hasPrefix("/essays/tombstones/") {
                let data = try await download(path: entry.pathDisplay, accessToken: accessToken)
                let tombstone = try Self.decoder.decode(DropboxTombstoneRecord.self, from: data)
                deletedMemoNames.append(tombstone.name)
            }
        }

        if !incomingMemos.isEmpty {
            LocalDatabase.shared.importMemos(incomingMemos, forAccountID: accountID, replaceExisting: false)
        }
        for memoName in deletedMemoNames {
            LocalDatabase.shared.deleteMemo(named: memoName)
        }
    }

    private func ensureRootFolder(accessToken: String) async throws {
        try await createFolderIfNeeded(path: Self.rootPath, accessToken: accessToken)
        try await createFolderIfNeeded(path: Self.rootPath + "/memos", accessToken: accessToken)
        try await createFolderIfNeeded(path: Self.rootPath + "/tombstones", accessToken: accessToken)
    }

    private func createFolderIfNeeded(path: String, accessToken: String) async throws {
        do {
            try await createFolder(path: path, accessToken: accessToken)
        } catch DropboxSyncError.apiError(let message) where message.contains("path/conflict/folder") {
            return
        }
    }

    private func createFolder(path: String, accessToken: String) async throws {
        var request = URLRequest(url: apiBaseURL.appendingPathComponent("files/create_folder_v2"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(DropboxCreateFolderRequest(path: path, autorename: false))
        _ = try await performDataRequest(request)
    }

    private func listChanges(accessToken: String) async throws -> DropboxListFolderResponse {
        let firstResponse: DropboxListFolderResponse
        if let cursor, !cursor.isEmpty {
            var request = URLRequest(url: apiBaseURL.appendingPathComponent("files/list_folder/continue"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(DropboxListFolderContinueRequest(cursor: cursor))
            firstResponse = try await performJSONRequest(request)
        } else {
            var request = URLRequest(url: apiBaseURL.appendingPathComponent("files/list_folder"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(
                DropboxListFolderRequest(path: Self.rootPath, recursive: true, includeDeleted: false)
            )
            firstResponse = try await performJSONRequest(request)
        }

        var allEntries = firstResponse.entries
        var nextCursor = firstResponse.cursor
        var hasMore = firstResponse.hasMore
        while hasMore {
            var request = URLRequest(url: apiBaseURL.appendingPathComponent("files/list_folder/continue"))
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try Self.encoder.encode(DropboxListFolderContinueRequest(cursor: nextCursor))
            let response: DropboxListFolderResponse = try await performJSONRequest(request)
            allEntries.append(contentsOf: response.entries)
            nextCursor = response.cursor
            hasMore = response.hasMore
        }
        cursor = nextCursor
        return DropboxListFolderResponse(entries: allEntries, cursor: nextCursor, hasMore: false)
    }

    private func upload(data: Data, path: String, accessToken: String) async throws {
        var request = URLRequest(url: contentBaseURL.appendingPathComponent("files/upload"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(
            Self.dropboxArg([
                "path": path,
                "mode": "overwrite",
                "autorename": false,
                "mute": true
            ]),
            forHTTPHeaderField: "Dropbox-API-Arg"
        )
        request.httpBody = data
        _ = try await performDataRequest(request)
    }

    private func download(path: String, accessToken: String) async throws -> Data {
        var request = URLRequest(url: contentBaseURL.appendingPathComponent("files/download"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.dropboxArg(["path": path]), forHTTPHeaderField: "Dropbox-API-Arg")
        return try await performDataRequest(request)
    }

    private func performJSONRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await performDataRequest(request)
        return try Self.decoder.decode(T.self, from: data)
    }

    private func performDataRequest(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DropboxSyncError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
                ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw DropboxSyncError.apiError(message)
        }
        return data
    }
}

#if os(macOS)
extension DropboxSyncService: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
        }
    }
}
#endif

private struct DropboxTokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

private struct DropboxMemoRecord: Codable {
    let formatVersion: Int
    let updatedAt: Date
    let memo: EssaysDataArchive.MemoRecord

    init(memo: Memo) {
        self.formatVersion = 1
        self.updatedAt = memo.updatedAt
        self.memo = EssaysDataArchive.MemoRecord(memo: memo)
    }

    func makeMemo(accountID: String) -> Memo {
        memo.makeMemo(accountID: accountID)
    }
}

private struct DropboxTombstoneRecord: Codable {
    let formatVersion: Int
    let name: String
    let deletedAt: Date
    let accountID: String

    init(formatVersion: Int = 1, name: String, deletedAt: Date, accountID: String) {
        self.formatVersion = formatVersion
        self.name = name
        self.deletedAt = deletedAt
        self.accountID = accountID
    }
}

private struct DropboxCreateFolderRequest: Encodable {
    let path: String
    let autorename: Bool
}

private struct DropboxListFolderRequest: Encodable {
    let path: String
    let recursive: Bool
    let includeDeleted: Bool

    enum CodingKeys: String, CodingKey {
        case path
        case recursive
        case includeDeleted = "include_deleted"
    }
}

private struct DropboxListFolderContinueRequest: Encodable {
    let cursor: String
}

private struct DropboxListFolderResponse: Decodable {
    let entries: [DropboxMetadata]
    let cursor: String
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case entries
        case cursor
        case hasMore = "has_more"
    }
}

private struct DropboxMetadata: Decodable {
    let tag: String
    let pathLower: String
    let pathDisplay: String

    enum CodingKeys: String, CodingKey {
        case tag = ".tag"
        case pathLower = "path_lower"
        case pathDisplay = "path_display"
    }
}

private enum DropboxSyncError: LocalizedError {
    case missingAppKey
    case invalidAuthorizationURL
    case missingAuthorizationCode
    case missingCodeVerifier
    case missingRefreshToken
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAppKey:
            String(localized: "Please enter a Dropbox app key first.", comment: "Dropbox sync missing app key error")
        case .invalidAuthorizationURL:
            String(localized: "Could not create the Dropbox authorization URL.", comment: "Dropbox sync invalid auth URL error")
        case .missingAuthorizationCode:
            String(localized: "Dropbox did not return an authorization code.", comment: "Dropbox sync missing auth code error")
        case .missingCodeVerifier:
            String(localized: "Dropbox authorization state expired. Please try again.", comment: "Dropbox sync missing code verifier error")
        case .missingRefreshToken:
            String(localized: "Connect Dropbox before syncing.", comment: "Dropbox sync unauthorized error")
        case .invalidResponse:
            String(localized: "Dropbox returned an invalid response.", comment: "Dropbox sync invalid response error")
        case .apiError(let message):
            String(
                format: String(localized: "Dropbox error: %@", comment: "Dropbox sync API error"),
                message
            )
        }
    }
}

private extension DropboxSyncService {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func formBody(_ values: [String: String]) -> Data {
        let body = values.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        .joined(separator: "&")
        return Data(body.utf8)
    }

    static func dropboxArg(_ values: [String: Any]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: values, options: [])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func memoPath(forMemoName memoName: String) -> String {
        rootPath + "/memos/" + safeFileName(for: memoName) + ".json"
    }

    static func tombstonePath(forMemoName memoName: String) -> String {
        rootPath + "/tombstones/" + safeFileName(for: memoName) + ".json"
    }

    static func safeFileName(for memoName: String) -> String {
        Data(memoName.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }

    static func randomCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
