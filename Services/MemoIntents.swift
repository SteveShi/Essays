import Foundation
import AppIntents

struct MemoIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Memo"
    static let description: IntentDescription = "Create a new memo in Essays"
    
    @Parameter(title: "Content", description: "The content of the memo")
    var content: String
    
    @Parameter(title: "Tags", description: "Tags for the memo (comma-separated)")
    var tags: String?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Create a memo with \(\.$content)") {
            \.$tags
        }
    }
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        var memoContent = content
        let userDefaults = UserDefaults.standard
        let serverURL = userDefaults.string(forKey: "memos_server_url")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let accessToken = userDefaults.string(forKey: "memos_access_token")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard !serverURL.isEmpty, !accessToken.isEmpty else {
            throw MemoIntentError.missingCredentials
        }
        
        await MemosAPIClient.shared.configure(serverURL: serverURL, accessToken: accessToken)
        
        if let tags = tags, !tags.isEmpty {
            let tagList = tags.split(separator: ",").map { "#\($0.trimmingCharacters(in: .whitespaces))" }
            memoContent += "\n\n" + tagList.joined(separator: " ")
        }
        
        do {
            let memo = try await MemosAPIClient.shared.createMemo(content: memoContent)
            return .result(value: "Memo created successfully: \(memo.name)")
        } catch {
            throw error
        }
    }
}

enum MemoIntentError: Error, LocalizedError {
    case missingCredentials
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return String(localized: "Please sign in within the app first")
        }
    }
}
