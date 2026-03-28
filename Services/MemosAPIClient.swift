import Foundation
import SwiftData
import Observation

@MainActor
@Observable
class MemosAPIClient {
    static let shared = MemosAPIClient()
    
    private var baseURL: String = ""
    private var _accessToken: String = ""
    
    var accessToken: String {
        _accessToken
    }
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    func configure(serverURL: String, accessToken: String) {
        var normalizedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure protocol prefix
        if !normalizedURL.isEmpty {
            if !normalizedURL.lowercased().hasPrefix("http://") && !normalizedURL.lowercased().hasPrefix("https://") {
                if normalizedURL.lowercased().contains("localhost") || normalizedURL.range(of: "^[0-9.]+$", options: .regularExpression) != nil {
                    normalizedURL = "http://" + normalizedURL
                } else {
                    normalizedURL = "https://" + normalizedURL
                }
            }
        }
        
        if normalizedURL.hasSuffix("/") {
            normalizedURL.removeLast()
        }
        self.baseURL = normalizedURL
        self._accessToken = accessToken
    }
    
    func setAccessToken(_ token: String) {
        self._accessToken = token
    }
    
    private func buildURL(_ path: String) -> URL? {
        URL(string: "\(baseURL)\(path)")
    }
    
    private func buildRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !_accessToken.isEmpty {
            request.setValue("Bearer \(_accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return request
    }
    

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Standard ISO8601 variants
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

            // Fallback for more aggressive fractional seconds (Memos Go backend sometimes returns many digits)
            // Using a more manual approach if ISO8601DateFormatter fails
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

    private func makeDecoder() -> JSONDecoder {
        return decoder
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MemosAPIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw MemosAPIError.unauthorized
            }
            if let errorString = String(data: data, encoding: .utf8) {
                throw MemosAPIError.serverError(errorString)
            }
            throw MemosAPIError.httpError(httpResponse.statusCode)
        }
        
        do {
            return try makeDecoder().decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("JSON: \(jsonString)")
            }
            throw MemosAPIError.decodingError(error)
        }
    }
    
    struct MemoResponse: Decodable {
        let memos: [MemoData]?
        let nextPageToken: String?
    }

    struct MemoAttachmentResponse: Decodable {
        let attachments: [AttachmentData]
    }

    struct MemoData: Decodable {
        let name: String
        let content: String
        let createTime: Date
        let updateTime: Date
        let visibility: String
        let state: String?
        let pinned: Bool?
        let tags: [String]?
        let attachments: [AttachmentData]?
        let resources: [AttachmentData]?
        let location: LocationData?
        let relations: [RelationData]?
        
        var extractedId: Int {
            if let idString = name.split(separator: "/").last, let id = Int(idString) {
                return id
            }
            return 0
        }
    }

    struct AttachmentData: Decodable {
        let name: String
        let filename: String
        let type: String
        let size: FlexibleSize
        let content: String?
        let externalLink: String?
        let createTime: Date?

        var sizeInt: Int64 {
            size.value
        }

        enum FlexibleSize: Decodable {
            case string(String)
            case int(Int64)

            var value: Int64 {
                switch self {
                case .string(let s): return Int64(s) ?? 0
                case .int(let i): return i
                }
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let s = try? container.decode(String.self) {
                    self = .string(s)
                } else if let i = try? container.decode(Int64.self) {
                    self = .int(i)
                } else {
                    self = .int(0)
                }
            }
        }
    }

    struct LocationData: Decodable {
        let placeholder: String?
        let latitude: Double
        let longitude: Double
    }

    struct RelationData: Decodable {
        let memo: FlexibleMemoReference
        let relatedMemo: FlexibleMemoReference
        let type: String

        enum FlexibleMemoReference: Decodable {
            case string(String)
            case object(ResourceReference)

            var value: String {
                switch self {
                case .string(let s): return s
                case .object(let obj): return obj.name
                }
            }

            struct ResourceReference: Decodable {
                let name: String
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let s = try? container.decode(String.self) {
                    self = .string(s)
                } else if let obj = try? container.decode(ResourceReference.self) {
                    self = .object(obj)
                } else {
                    throw DecodingError.typeMismatch(
                        FlexibleMemoReference.self,
                        DecodingError.Context(
                            codingPath: decoder.codingPath,
                            debugDescription: "Expected String or Object with 'name'"))
                }
            }
        }
    }

    struct WorkspaceProfile: Decodable {
        let name: String
        let owner: String
        let version: String
    }

    func checkServerStatus() async throws -> String {
        guard let url = buildURL("/api/v1/workspace/profile") else {
            throw MemosAPIError.invalidURL
        }
        let request = buildRequest(url: url)
        let profile: WorkspaceProfile = try await performRequest(request)
        return profile.version
    }
    
    func signIn(username: String, password: String) async throws -> User {
        guard let url = buildURL("/api/v1/auth/signin") else {
            throw MemosAPIError.invalidURL
        }
        
        let body: [String: Any] = [
            "username": username,
            "password": password
        ]
        
        var request = buildRequest(
            url: url, method: "POST", body: try? JSONSerialization.data(withJSONObject: body))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MemosAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw MemosAPIError.unauthorized
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw MemosAPIError.httpError(httpResponse.statusCode)
        }
        
        let user = try makeDecoder().decode(User.self, from: data)
        
        if let accessTokenValue = httpResponse.value(forHTTPHeaderField: "Authorization") {
            self._accessToken = accessTokenValue
        }
        
        return user
    }
    
    func getCurrentUser() async throws -> User {
        guard let url = buildURL("/api/v1/auth/me") else {
            throw MemosAPIError.invalidURL
        }
        let request = buildRequest(url: url)
        
        struct GetCurrentUserResponse: Decodable {
            let user: User
        }
        
        let response: GetCurrentUserResponse = try await performRequest(request)
        return response.user
    }
    
    /// Implementation of full pagination sync.
    /// Fetches ALL memos from the server by following 'nextPageToken' before saving to local database.
    func fetchMemos() async throws -> [Memo] {
        var allMemosData: [MemoData] = []
        var nextPageToken: String? = nil
        
        print("Starting full memo sync...")
        
        repeat {
            guard var urlComponents = URLComponents(string: "\(baseURL)/api/v1/memos") else {
                throw MemosAPIError.invalidURL
            }
            
            var queryItems = [
                URLQueryItem(name: "view", value: "MEMO_VIEW_FULL"),
                URLQueryItem(name: "pageSize", value: "200")
            ]
            
            if let token = nextPageToken, !token.isEmpty {
                queryItems.append(URLQueryItem(name: "pageToken", value: token))
            }
            
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else { throw MemosAPIError.invalidURL }
            let request = buildRequest(url: url)
            
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw MemosAPIError.invalidResponse
                }
                
                let decoder = makeDecoder()
                
                // Handle different possible response formats
                if let memoResponse = try? decoder.decode(MemoResponse.self, from: data) {
                    allMemosData.append(contentsOf: memoResponse.memos ?? [])
                    nextPageToken = memoResponse.nextPageToken
                    print("Fetched page. Current total count: \(allMemosData.count). Next token: \(nextPageToken ?? "none")")
                } else if let directMemos = try? decoder.decode([MemoData].self, from: data) {
                    // Legacy or direct array response doesn't support pagination in the body
                    allMemosData.append(contentsOf: directMemos)
                    nextPageToken = nil
                } else {
                    // Critical failure in decoding
                    throw MemosAPIError.decodingError(NSError(domain: "MemosAPIClient", code: 0, 
                                                            userInfo: [NSLocalizedDescriptionKey: "Failed to decode memo response"]))
                }
            } catch {
                print("Pagination fetch failed: \(error). Aborting sync to protect local data.")
                // 🚨 CRITICAL: We THROW here to abort the sync. 
                // This ensures LocalDatabase.saveMemos is NEVER called with a partial list.
                throw error
            }
        } while nextPageToken != nil && !nextPageToken!.isEmpty
        
        // Map all collected pages to models
        let memos = allMemosData.map { mapMemoDataToModel($0) }
        print("Sync complete. Total memos to save: \(memos.count)")
        
        // Save to local database and return the managed versions
        return LocalDatabase.shared.saveMemos(memos)
    }

    private func fetchMemoAttachments(memoName: String) async throws -> [Attachment] {
        let primaryEncodedMemoName =
            memoName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? memoName
        let fallbackMemoId = memoName.split(separator: "/").last.map(String.init) ?? memoName
        let fallbackEncodedMemoId =
            fallbackMemoId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? fallbackMemoId

        let candidatePaths = [
            "/api/v1/\(primaryEncodedMemoName)/attachments",
            "/api/v1/memos/\(fallbackEncodedMemoId)/attachments",
        ]

        var lastError: Error?
        for path in candidatePaths {
            guard let url = buildURL(path) else { continue }
            let request = buildRequest(url: url)
            do {
                let response: MemoAttachmentResponse = try await performRequest(request)
                let attachments = response.attachments.map { data in
                    Attachment(
                        name: data.name,
                        filename: data.filename,
                        type: data.type,
                        size: data.sizeInt,
                        content: data.content,
                        externalLink: data.externalLink,
                        createTime: data.createTime
                    )
                }
                return try await hydrateAttachmentsIfNeeded(attachments)
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }
        throw MemosAPIError.invalidURL
    }

    private func hydrateAttachmentsIfNeeded(_ attachments: [Attachment]) async throws
        -> [Attachment]
    {
        var results = attachments
        for index in results.indices {
            let attachment = results[index]
            let hasInlineContent = !(attachment.content?.isEmpty ?? true)
            let hasExternalLink = !(attachment.externalLink?.isEmpty ?? true)

            if (hasInlineContent || hasExternalLink) || attachment.name.isEmpty {
                continue
            }

            do {
                let detailed = try await self.fetchAttachment(resourceName: attachment.name)
                results[index] = detailed
            } catch {
                print("Failed to hydrate attachment: \(error)")
            }
        }
        return results
    }

    private func fetchAttachment(resourceName: String) async throws -> Attachment {
        let encodedResourceName =
            resourceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? resourceName
        guard let url = buildURL("/api/v1/\(encodedResourceName)") else {
            throw MemosAPIError.invalidURL
        }
        let request = buildRequest(url: url)
        let data: AttachmentData = try await performRequest(request)
        return Attachment(
            name: data.name,
            filename: data.filename,
            type: data.type,
            size: data.sizeInt,
            content: data.content,
            externalLink: data.externalLink,
            createTime: data.createTime
        )
    }
    
    func createMemo(
        content: String, visibility: MemoVisibility? = nil, tags: [String]? = nil,
        pinned: Bool? = nil,
        attachmentNames: [String]? = nil, location: Location? = nil
    ) async throws -> Memo {
        // Handle Offline State
        if !NetworkMonitor.shared.isConnected {
            let pendingMemo = Memo(
                numericID: Int.random(in: 1000000...9999999),
                content: content,
                visibility: visibility ?? .private,
                pinned: pinned ?? false,
                tags: tags ?? [],
                attachments: [],  // Simplified for offline
                location: location,
                isPendingSync: true
            )
            _ = LocalDatabase.shared.saveMemos([pendingMemo])
            return pendingMemo
        }

        guard let url = buildURL("/api/v1/memos") else {
            throw MemosAPIError.invalidURL
        }

        var body: [String: Any] = ["content": content]
        if let visibility = visibility {
            body["visibility"] = visibility.rawValue
        }
        if let tags = tags {
            body["tags"] = tags
        }
        if let pinned = pinned {
            body["pinned"] = pinned
        }
        if let attachmentNames = attachmentNames {
            body["attachments"] = attachmentNames.map { ["name": $0] }
        }
        
        if let location = location {
            body["location"] = [
                "placeholder": location.placeholder ?? "",
                "latitude": location.latitude,
                "longitude": location.longitude,
            ]
        }

        let request = buildRequest(url: url, method: "POST", body: try? JSONSerialization.data(withJSONObject: body))
        
        let data: MemoData = try await performRequest(request)
        return mapMemoDataToModel(data)
    }
    
    func updateMemo(
        id: Int, memoName: String? = nil, content: String, visibility: MemoVisibility? = nil,
        tags: [String]? = nil,
        pinned: Bool? = nil,
        attachmentNames: [String]? = nil, location: Location? = nil
    ) async throws -> Memo {
        let resourceName = memoName ?? "memos/\(id)"
        let encodedResourceName =
            resourceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? resourceName
        guard var urlComponents = URLComponents(string: "\(baseURL)/api/v1/\(encodedResourceName)")
        else {
            throw MemosAPIError.invalidURL
        }
        
        var body: [String: Any] = ["content": content, "name": resourceName]
        var updateMasks: [String] = ["content"]
        
        if let visibility = visibility {
            body["visibility"] = visibility.rawValue
            updateMasks.append("visibility")
        }
        if let tags = tags {
            body["tags"] = tags
            updateMasks.append("tags")
        }
        if let pinned = pinned {
            body["pinned"] = pinned
            updateMasks.append("pinned")
        }
        if let attachmentNames = attachmentNames {
            body["attachments"] = attachmentNames.map { ["name": $0] }
            updateMasks.append("attachments")
        }
        
        if let location = location {
            body["location"] = [
                "placeholder": location.placeholder ?? "",
                "latitude": location.latitude,
                "longitude": location.longitude,
            ]
            updateMasks.append("location")
        }

        urlComponents.queryItems = [URLQueryItem(name: "updateMask", value: updateMasks.joined(separator: ","))]
        
        guard let url = urlComponents.url else {
            throw MemosAPIError.invalidURL
        }
        
        let request = buildRequest(url: url, method: "PATCH", body: try? JSONSerialization.data(withJSONObject: body))
        
        let data: MemoData = try await performRequest(request)
        let memoVisibility = MemoVisibility(rawValue: data.visibility) ?? .private
        
        let localAttachments = ((data.attachments ?? []) + (data.resources ?? [])).map {
            Attachment(
                name: $0.name, filename: $0.filename, type: $0.type, size: $0.sizeInt,
                content: $0.content, externalLink: $0.externalLink, createTime: $0.createTime)
        }

        let locationValue = data.location.map {
            Location(placeholder: $0.placeholder, latitude: $0.latitude, longitude: $0.longitude)
        }

        let localRelations = (data.relations ?? []).map {
            Relation(
                memo: $0.memo.value, relatedMemo: $0.relatedMemo.value,
                type: Relation.RelationType(rawValue: $0.type) ?? .unspecified)
        }

        let memoModel = Memo(
            name: data.name,
            numericID: data.extractedId,
            content: data.content,
            createdAt: data.createTime,
            updatedAt: data.updateTime,
            visibility: memoVisibility,
            pinned: data.pinned ?? false,
            state: MemoState(rawValue: data.state ?? "NORMAL") ?? .normal,
            tags: data.tags ?? [],
            attachments: localAttachments,
            location: locationValue,
            relations: localRelations
        )
        
        if memoModel.tags.isEmpty {
            memoModel.extractTagsFromContent()
        }

        return memoModel
    }
    
    func deleteMemo(id: Int, memoName: String? = nil) async throws {
        let resourceName = memoName ?? "memos/\(id)"
        let encodedResourceName =
            resourceName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
            ?? resourceName
        guard let url = buildURL("/api/v1/\(encodedResourceName)") else {
            throw MemosAPIError.invalidURL
        }
        let request = buildRequest(url: url, method: "DELETE")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MemosAPIError.invalidResponse
        }
    }
    
    func archiveMemo(id: Int, memoName: String) async throws -> Memo {
        let encodedName = memoName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? memoName
        guard var urlComponents = URLComponents(string: "\(baseURL)/api/v1/\(encodedName)") else {
            throw MemosAPIError.invalidURL
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "updateMask", value: "state")]
        guard let url = urlComponents.url else {
            throw MemosAPIError.invalidURL
        }
        
        let body: [String: Any] = ["name": memoName, "state": "ARCHIVED"]
        let request = buildRequest(url: url, method: "PATCH", body: try? JSONSerialization.data(withJSONObject: body))
        
        let data: MemoData = try await performRequest(request)
        let visibility = MemoVisibility(rawValue: data.visibility) ?? .private
        
        let attachments = (data.attachments ?? []).map {
            Attachment(
                name: $0.name, filename: $0.filename, type: $0.type, size: $0.sizeInt,
                content: $0.content, externalLink: $0.externalLink, createTime: $0.createTime)
        }

        let locationValue = data.location.map {
            Location(placeholder: $0.placeholder, latitude: $0.latitude, longitude: $0.longitude)
        }

        let relations = (data.relations ?? []).map {
            Relation(
                memo: $0.memo.value, relatedMemo: $0.relatedMemo.value,
                type: Relation.RelationType(rawValue: $0.type) ?? .unspecified)
        }

        let memoModel = Memo(
            name: data.name,
            numericID: data.extractedId,
            content: data.content,
            createdAt: data.createTime,
            updatedAt: data.updateTime,
            visibility: visibility,
            pinned: data.pinned ?? false,
            state: MemoState(rawValue: data.state ?? "NORMAL") ?? .normal,
            tags: data.tags ?? [],
            attachments: attachments,
            location: locationValue,
            relations: relations,
        )
        
        if memoModel.tags.isEmpty {
            memoModel.extractTagsFromContent()
        }

        return memoModel
    }
    
    func togglePinMemo(id: Int, pinned: Bool, memoName: String) async throws -> Memo {
        // memoName is like "memos/123" - use it directly as the resource path
        let encodedName = memoName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? memoName
        guard var urlComponents = URLComponents(string: "\(baseURL)/api/v1/\(encodedName)") else {
            throw MemosAPIError.invalidURL
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "updateMask", value: "pinned")]
        guard let url = urlComponents.url else {
            throw MemosAPIError.invalidURL
        }
        
        let body: [String: Any] = ["name": memoName, "pinned": pinned]
        let request = buildRequest(url: url, method: "PATCH", body: try? JSONSerialization.data(withJSONObject: body))
        
        let data: MemoData = try await performRequest(request)
        let visibility = MemoVisibility(rawValue: data.visibility) ?? .private
        
        let attachments = (data.attachments ?? []).map {
            Attachment(
                name: $0.name, filename: $0.filename, type: $0.type, size: $0.sizeInt,
                content: $0.content, externalLink: $0.externalLink, createTime: $0.createTime)
        }

        let locationValue = data.location.map {
            Location(placeholder: $0.placeholder, latitude: $0.latitude, longitude: $0.longitude)
        }

        let relations = (data.relations ?? []).map {
            Relation(
                memo: $0.memo.value, relatedMemo: $0.relatedMemo.value,
                type: Relation.RelationType(rawValue: $0.type) ?? .unspecified)
        }

        let memoModel = Memo(
            name: data.name,
            numericID: data.extractedId,
            content: data.content,
            createdAt: data.createTime,
            updatedAt: data.updateTime,
            visibility: visibility,
            pinned: data.pinned ?? false,
            state: MemoState(rawValue: data.state ?? "NORMAL") ?? .normal,
            tags: data.tags ?? [],
            attachments: attachments,
            location: locationValue,
            relations: relations,
        )
        
        if memoModel.tags.isEmpty {
            memoModel.extractTagsFromContent()
        }

        return memoModel
    }
    
    func fetchTags() async throws -> [Tag] {
        // v0.26 no longer has a dedicated /api/v1/tags endpoint.
        // Tags are extracted dynamically from memos in the UI.
        return []
    }
    
    func uploadAttachment(data: Data, filename: String, mimeType: String) async throws -> Attachment
    {
        guard NetworkMonitor.shared.isConnected else {
            throw MemosAPIError.serverError(String(localized: "Cannot upload attachment while offline", comment: "Error message when uploading attachment without network"))
        }

        guard let url = buildURL("/api/v1/attachments") else {
            throw MemosAPIError.invalidURL
        }
        
        let body: [String: Any] = [
            "filename": filename,
            "type": mimeType,
            "content": data.base64EncodedString(),
        ]
        
        // buildRequest automatically adds the Bearer token and Application/JSON headers
        let request = buildRequest(
            url: url, method: "POST", body: try? JSONSerialization.data(withJSONObject: body))
        
        let response: AttachmentData = try await performRequest(request)
        return Attachment(
            name: response.name,
            filename: response.filename,
            type: response.type,
            size: response.sizeInt,
            content: response.content,
            externalLink: response.externalLink,
            createTime: response.createTime
        )
    }

    func fetchComments(parentId: String) async throws -> [Memo] {
        guard let url = buildURL("/api/v1/\(parentId)/comments") else {
            throw MemosAPIError.invalidURL
        }
        let request = buildRequest(url: url)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MemosAPIError.invalidResponse
        }
        
        let decoder = makeDecoder()
        let memosData: [MemoData]
        
        if let memoResponse = try? decoder.decode(MemoResponse.self, from: data) {
            memosData = memoResponse.memos ?? []
        } else if let directMemos = try? decoder.decode([MemoData].self, from: data) {
            memosData = directMemos
        } else {
            memosData = []
        }
        
        return memosData.map { mapMemoDataToModel($0) }
    }

    func syncPendingMemos() async {
        guard NetworkMonitor.shared.isConnected else { return }

        let pending = LocalDatabase.shared.fetchAllMemos().filter { $0.isPendingSync }
        guard !pending.isEmpty else { return }

        print("Syncing \(pending.count) pending memos...")

        for memo in pending {
            do {
                _ = try await createMemo(
                    content: memo.content,
                    visibility: memo.visibility,
                    pinned: memo.pinned,
                    location: memo.location
                )
                // Success! Delete the pending one or update it
                LocalDatabase.shared.deleteMemo(memo)
            } catch {
                print("Failed to sync memo: \(error)")
            }
        }
    }

    func createComment(parentId: String, content: String, visibility: MemoVisibility = .private) async throws -> Memo {
        guard let url = buildURL("/api/v1/\(parentId)/comments") else {
            throw MemosAPIError.invalidURL
        }
        
        let body: [String: Any] = [
            "content": content,
            "visibility": visibility.rawValue
        ]
        
        let request = buildRequest(url: url, method: "POST", body: try? JSONSerialization.data(withJSONObject: body))
        let data: MemoData = try await performRequest(request)
        return mapMemoDataToModel(data)
    }
    
    private func mapMemoDataToModel(_ data: MemoData) -> Memo {
        let memoVisibility = MemoVisibility(rawValue: data.visibility) ?? .private
        
        let localAttachments = ((data.attachments ?? []) + (data.resources ?? [])).map {
            Attachment(
                name: $0.name, filename: $0.filename, type: $0.type, size: $0.sizeInt,
                content: $0.content, externalLink: $0.externalLink, createTime: $0.createTime)
        }

        let locationValue = data.location.map {
            Location(placeholder: $0.placeholder, latitude: $0.latitude, longitude: $0.longitude)
        }

        let localRelations = (data.relations ?? []).map {
            Relation(
                memo: $0.memo.value, relatedMemo: $0.relatedMemo.value,
                type: Relation.RelationType(rawValue: $0.type) ?? .unspecified)
        }

        let memoModel = Memo(
            name: data.name,
            numericID: data.extractedId,
            content: data.content,
            createdAt: data.createTime,
            updatedAt: data.updateTime,
            visibility: memoVisibility,
            pinned: data.pinned ?? false,
            tags: data.tags ?? [],
            attachments: localAttachments,
            location: locationValue,
            relations: localRelations
        )
        
        if memoModel.tags.isEmpty {
            memoModel.extractTagsFromContent()
        }

        return memoModel
    }
}

enum MemosAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(Int)
    case serverError(String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "Invalid server URL")
        case .invalidResponse:
            return String(localized: "Invalid server response")
        case .unauthorized:
            return String(localized: "Authentication required")
        case .httpError(let code):
            return String(localized: "HTTP Error \(code)")
        case .serverError(let message):
            return message
        case .decodingError(let error):
            return error.localizedDescription
        }
    }
}
