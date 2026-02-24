import Foundation

actor MemosAPIClient {
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
        var normalizedURL = serverURL.trimmingCharacters(in: .whitespaces)
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
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatters: [ISO8601DateFormatter] = {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let formatter2 = ISO8601DateFormatter()
                formatter2.formatOptions = [.withInternetDateTime]
                return [formatter, formatter2]
            }()
            
            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("JSON: \(jsonString)")
            }
            throw MemosAPIError.decodingError(error)
        }
    }
    
    struct MemoResponse: Decodable {
        let memos: [MemoData]
    }
    
    struct MemoData: Decodable {
        let name: String
        let content: String
        let createTime: Date
        let updateTime: Date
        let visibility: String
        let pinned: Bool?
        let tags: [String]?
        let attachments: [Resource]?
        
        var extractedId: Int {
            if let idString = name.split(separator: "/").last, let id = Int(idString) {
                return id
            }
            return 0
        }
    }
    
    func checkServerStatus() async throws -> ServerInfo {
        guard let url = buildURL("/api/v1/status") else {
            throw MemosAPIError.invalidURL
        }
        let request = buildRequest(url: url)
        return try await performRequest(request)
    }
    
    func signIn(username: String, password: String) async throws -> User {
        guard let url = buildURL("/api/v1/auth/signin") else {
            throw MemosAPIError.invalidURL
        }
        
        let body: [String: String] = [
            "username": username,
            "password": password
        ]
        
        var request = buildRequest(url: url, method: "POST", body: try? JSONEncoder().encode(body))
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
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let user = try decoder.decode(User.self, from: data)
        
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
    
    func fetchMemos() async throws -> [Memo] {
        guard let url = buildURL("/api/v1/memos") else {
            throw MemosAPIError.invalidURL
        }
        let request = buildRequest(url: url)
        
        let response: MemoResponse = try await performRequest(request)
        
        return response.memos.map { data in
            let visibility = MemoVisibility(rawValue: data.visibility) ?? .private
            return Memo(
                name: data.name,
                id: data.extractedId,
                content: data.content,
                createdAt: data.createTime,
                updatedAt: data.updateTime,
                visibility: visibility,
                pinned: data.pinned ?? false,
                tags: data.tags ?? [],
                resources: data.attachments ?? []
            )
        }
    }
    
    func createMemo(content: String, visibility: MemoVisibility = .private) async throws -> Memo {
        guard let url = buildURL("/api/v1/memos") else {
            throw MemosAPIError.invalidURL
        }
        
        let body: [String: Any] = [
            "content": content,
            "visibility": visibility.rawValue
        ]
        
        let request = buildRequest(url: url, method: "POST", body: try? JSONSerialization.data(withJSONObject: body))
        
        let data: MemoData = try await performRequest(request)
        let memoVisibility = MemoVisibility(rawValue: data.visibility) ?? .private
        
        return Memo(
            name: data.name,
            id: data.extractedId,
            content: data.content,
            createdAt: data.createTime,
            updatedAt: data.updateTime,
            visibility: memoVisibility,
            pinned: data.pinned ?? false,
            tags: data.tags ?? [],
            resources: data.attachments ?? []
        )
    }
    
    func updateMemo(id: Int, content: String, visibility: MemoVisibility? = nil, pinned: Bool? = nil) async throws -> Memo {
        guard var urlComponents = URLComponents(string: "\(baseURL)/api/v1/memos/\(id)") else {
            throw MemosAPIError.invalidURL
        }
        
        var body: [String: Any] = ["content": content, "name": "memos/\(id)"]
        var updateMasks: [String] = ["content"]
        
        if let visibility = visibility {
            body["visibility"] = visibility.rawValue
            updateMasks.append("visibility")
        }
        if let pinned = pinned {
            body["pinned"] = pinned
            updateMasks.append("pinned")
        }
        
        urlComponents.queryItems = [URLQueryItem(name: "updateMask", value: updateMasks.joined(separator: ","))]
        
        guard let url = urlComponents.url else {
            throw MemosAPIError.invalidURL
        }
        
        let request = buildRequest(url: url, method: "PATCH", body: try? JSONSerialization.data(withJSONObject: body))
        
        let data: MemoData = try await performRequest(request)
        let memoVisibility = MemoVisibility(rawValue: data.visibility) ?? .private
        
        return Memo(
            name: data.name,
            id: data.extractedId,
            content: data.content,
            createdAt: data.createTime,
            updatedAt: data.updateTime,
            visibility: memoVisibility,
            pinned: data.pinned ?? false,
            tags: data.tags ?? [],
            resources: data.attachments ?? []
        )
    }
    
    func deleteMemo(id: Int) async throws {
        guard let url = buildURL("/api/v1/memos/\(id)") else {
            throw MemosAPIError.invalidURL
        }
        let request = buildRequest(url: url, method: "DELETE")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw MemosAPIError.invalidResponse
        }
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
        
        return Memo(
            name: data.name,
            id: data.extractedId,
            content: data.content,
            createdAt: data.createTime,
            updatedAt: data.updateTime,
            visibility: visibility,
            pinned: data.pinned ?? false,
            tags: data.tags ?? [],
            resources: data.attachments ?? []
        )
    }
    
    func fetchTags() async throws -> [Tag] {
        // v0.26 no longer has a dedicated /api/v1/tags endpoint.
        // Tags are extracted dynamically from memos in the UI.
        return []
    }
    
    func uploadAttachment(data: Data, filename: String, mimeType: String) async throws -> Resource {
        guard let url = buildURL("/api/v1/attachments") else {
            throw MemosAPIError.invalidURL
        }
        
        var request = buildRequest(url: url, method: "POST")
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        return try await performRequest(request)
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
            return String(format: String(localized: "HTTP error: %@"), String(code))
        case .serverError(let message):
            return String(format: String(localized: "Server error: %@"), message)
        case .decodingError(let error):
            return String(format: String(localized: "Data decoding error: %@"), error.localizedDescription)
        }
    }
}
