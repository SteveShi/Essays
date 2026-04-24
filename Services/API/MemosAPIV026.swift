import Foundation
import SwiftData
import Observation

struct MemosAPIV026: MemosAPIProtocol {
    private let baseURL: String
    private let accessToken: String
    private let session: URLSession
    
    init(baseURL: String, accessToken: String) {
        var normalizedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
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
        self.accessToken = accessToken
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    private func buildURL(_ path: String) -> URL? {
        URL(string: "\(baseURL)\(path)")
    }
    
    private func buildRequest(url: URL, method: String = "GET", body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
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
        let nextPageToken: String?
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
        
        var extractedId: String {
            return name.split(separator: "/").last.map(String.init) ?? ""
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

    struct InstanceProfile: Decodable {
        let version: String
        let demo: Bool?
        let instanceUrl: String?
        let admin: User?
    }

    func checkServerStatus() async throws -> String {
        guard let url = buildURL("/api/v1/instance/profile") else {
            throw MemosAPIError.invalidURL
        }
        let request = buildRequest(url: url)
        let profile: InstanceProfile = try await performRequest(request)
        return profile.version
    }
    
    func signIn(username: String, password: String) async throws -> (user: User, accessToken: String?) {
        guard let url = buildURL("/api/v1/auth/signin") else {
            throw MemosAPIError.invalidURL
        }
        
        let body: [String: Any] = [
            "passwordCredentials": [
                "username": username,
                "password": password
            ]
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
        
        struct SignInResponse: Decodable {
            let user: User
            let accessToken: String?
        }
        
        let signInResponse = try makeDecoder().decode(SignInResponse.self, from: data)
        
        let tokenFromHeader: String? = {
            guard let authHeader = httpResponse.value(forHTTPHeaderField: "Authorization") else {
                return nil
            }
            let prefix = "Bearer "
            if authHeader.hasPrefix(prefix) {
                return String(authHeader.dropFirst(prefix.count))
            }
            return authHeader.isEmpty ? nil : authHeader
        }()

        return (signInResponse.user, signInResponse.accessToken ?? tokenFromHeader)
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
        print("Starting full memo sync...")
        
        let normalMemos = try await fetchMemosByState("NORMAL")
        let archivedMemos = try await fetchMemosByState("ARCHIVED")
        
        let allMemosData = normalMemos + archivedMemos
        
        // Map all collected pages to models
        let memos = allMemosData.map { mapMemoDataToModel($0) }
        print("Sync complete. Total memos to save: \(memos.count)")
        
        // Save to local database and return the managed versions
        return memos
    }

    private func fetchMemosByState(_ state: String) async throws -> [MemoData] {
        var allMemosData: [MemoData] = []
        var nextPageToken: String? = nil
        
        print("Fetching memos with state: \(state)...")
        
        repeat {
            guard var urlComponents = URLComponents(string: "\(baseURL)/api/v1/memos") else {
                throw MemosAPIError.invalidURL
            }
            
            var queryItems = [
                URLQueryItem(name: "state", value: state),
                URLQueryItem(name: "pageSize", value: "200")
            ]
            
            if let token = nextPageToken, !token.isEmpty {
                queryItems.append(URLQueryItem(name: "pageToken", value: token))
            }
            
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else { throw MemosAPIError.invalidURL }
            let request = buildRequest(url: url)
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw MemosAPIError.invalidResponse
            }
            
            let decoder = makeDecoder()
            
            if let memoResponse = try? decoder.decode(MemoResponse.self, from: data) {
                let filtered = (memoResponse.memos ?? []).filter { ($0.state ?? "NORMAL").uppercased() == state }
                allMemosData.append(contentsOf: filtered)
                nextPageToken = memoResponse.nextPageToken
            } else if let directMemos = try? decoder.decode([MemoData].self, from: data) {
                let filtered = directMemos.filter { ($0.state ?? "NORMAL").uppercased() == state }
                allMemosData.append(contentsOf: filtered)
                nextPageToken = nil
            } else {
                throw MemosAPIError.decodingError(NSError(domain: "MemosAPIClient", code: 0, 
                                                        userInfo: [NSLocalizedDescriptionKey: "Failed to decode memo response"]))
            }
        } while nextPageToken != nil && !nextPageToken!.isEmpty
        
        return allMemosData
    }

    private func fetchMemoAttachments(memoName: String) async throws -> [Attachment] {
        let primaryEncodedMemoName =
            memoName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? memoName
        
        var allAttachments: [Attachment] = []
        var nextPageToken: String? = nil
        
        repeat {
            guard var urlComponents = URLComponents(string: "\(baseURL)/api/v1/\(primaryEncodedMemoName)/attachments") else {
                throw MemosAPIError.invalidURL
            }
            
            var queryItems = [URLQueryItem(name: "pageSize", value: "100")]
            if let token = nextPageToken, !token.isEmpty {
                queryItems.append(URLQueryItem(name: "pageToken", value: token))
            }
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else { throw MemosAPIError.invalidURL }
            let request = buildRequest(url: url)
            
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
            allAttachments.append(contentsOf: attachments)
            nextPageToken = response.nextPageToken
        } while nextPageToken != nil && !nextPageToken!.isEmpty
        
        return try await hydrateAttachmentsIfNeeded(allAttachments)
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
        attachmentNames: [String]? = nil, location: LocationDTO? = nil
    ) async throws -> Memo {

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
        memoName: String, content: String, visibility: MemoVisibility? = nil,
        tags: [String]? = nil,
        pinned: Bool? = nil,
        attachmentNames: [String]? = nil, location: LocationDTO? = nil
    ) async throws -> Memo {
        let resourceName = memoName
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
    
    func deleteMemo(memoId: String) async throws {
        let memoName = memoId
        let resourceName = memoName
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
    
    func archiveMemo(memoName: String) async throws -> Memo {
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
        return mapMemoDataToModel(data)
    }

    func unarchiveMemo(memoName: String) async throws -> Memo {
        let encodedName = memoName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? memoName
        guard var urlComponents = URLComponents(string: "\(baseURL)/api/v1/\(encodedName)") else {
            throw MemosAPIError.invalidURL
        }

        urlComponents.queryItems = [URLQueryItem(name: "updateMask", value: "state")]
        guard let url = urlComponents.url else {
            throw MemosAPIError.invalidURL
        }

        let body: [String: Any] = ["name": memoName, "state": "NORMAL"]
        let request = buildRequest(url: url, method: "PATCH", body: try? JSONSerialization.data(withJSONObject: body))

        let data: MemoData = try await performRequest(request)
        return mapMemoDataToModel(data)
    }
    
    func togglePinMemo(pinned: Bool, memoName: String) async throws -> Memo {
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
        return mapMemoDataToModel(data)
    }
    
    func fetchTags() async throws -> [Tag] {
        // v0.26 no longer has a dedicated /api/v1/tags endpoint.
        // Tags are extracted dynamically from memos in the UI.
        return []
    }
    
    func uploadAttachment(data: Data, filename: String, mimeType: String) async throws -> Attachment
    {

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
        var allMemosData: [MemoData] = []
        var nextPageToken: String? = nil
        
        repeat {
            guard var urlComponents = URLComponents(string: "\(baseURL)/api/v1/\(parentId)/comments") else {
                throw MemosAPIError.invalidURL
            }
            
            var queryItems = [URLQueryItem(name: "pageSize", value: "100")]
            if let token = nextPageToken, !token.isEmpty {
                queryItems.append(URLQueryItem(name: "pageToken", value: token))
            }
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else { throw MemosAPIError.invalidURL }
            let request = buildRequest(url: url)
            
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw MemosAPIError.invalidResponse
            }
            
            let decoder = makeDecoder()
            if let memoResponse = try? decoder.decode(MemoResponse.self, from: data) {
                allMemosData.append(contentsOf: memoResponse.memos ?? [])
                nextPageToken = memoResponse.nextPageToken
            } else if let directMemos = try? decoder.decode([MemoData].self, from: data) {
                allMemosData.append(contentsOf: directMemos)
                nextPageToken = nil
            } else {
                nextPageToken = nil
            }
        } while nextPageToken != nil && !nextPageToken!.isEmpty
        
        return allMemosData.map { mapMemoDataToModel($0) }
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
}
