import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
actor MemosAIAssistant {
    static let shared = MemosAIAssistant()

    private var session: LanguageModelSession?

    private init() {}

    func availabilityState() -> AIAssistantAvailabilityState {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return .appleIntelligenceNotEnabled
            case .modelNotReady:
                return .modelNotReady
            case .deviceNotEligible:
                return .deviceNotEligible
            @unknown default:
                return .unavailable
            }
        @unknown default:
            return .unavailable
        }
    }

    func initialize() async {
        guard availabilityState().isAvailable else {
            session = nil
            return
        }

        session = LanguageModelSession(instructions: Self.instructions)
    }

    func generateTags(for content: String) async throws -> [String] {
        let session = try activeSession()

        let prompt = """
        Generate 3-5 relevant tags for the following memo content.
        Return only the tags as a comma-separated list, without the # symbol.
        IMPORTANT: Respond in the same language as the content.

        Content:
        \(content)
        """

        let response = try await session.respond(to: prompt)
        let tags = response.content
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return Array(tags.prefix(5))
    }

    func summarize(_ content: String) async throws -> String {
        let session = try activeSession()

        let prompt = """
        Summarize the following memo in 1-2 sentences.
        IMPORTANT: Respond in the same language as the content.

        \(content)
        """

        let response = try await session.respond(to: prompt)
        return response.content
    }

    func improve(_ content: String) async throws -> String {
        let session = try activeSession()

        let prompt = """
        Improve the following memo for clarity and readability.
        Keep the original meaning and style. Return only the improved text.
        IMPORTANT: Respond in the same language as the original content.

        Original:
        \(content)
        """

        let response = try await session.respond(to: prompt)
        return response.content
    }

    func expand(_ content: String) async throws -> String {
        let session = try activeSession()

        let prompt = """
        Expand on the following memo idea with more details and examples.
        Keep the same tone and style. Return only the expanded text.
        IMPORTANT: Respond in the same language as the original content.

        Original:
        \(content)
        """

        let response = try await session.respond(to: prompt)
        return response.content
    }

    func generateRelatedIdeas(for content: String) async throws -> [String] {
        let session = try activeSession()

        let prompt = """
        Based on the following memo, suggest 3 related ideas or topics the user might want to explore.
        Return each idea on a new line.
        IMPORTANT: Respond in the same language as the memo.

        Memo:
        \(content)
        """

        let response = try await session.respond(to: prompt)
        let ideas = response.content
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return Array(ideas.prefix(3))
    }

    func answerQuestion(_ question: String, context: [String]) async throws -> String {
        let session = try activeSession()

        let contextText = context.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")

        let prompt = """
        Based on the following memos, answer the question.
        If the answer cannot be found in the memos, say so.

        Memos:
        \(contextText)

        Question: \(question)
        """

        let response = try await session.respond(to: prompt)
        return response.content
    }

    func translate(_ content: String, to language: String) async throws -> String {
        let session = try activeSession()

        let languageName = Self.languageDisplayName(for: language)
        let prompt: String
        if language == "auto" {
            prompt = """
            Translate the following text to a different language.
            If the text is in Chinese, translate it to English.
            If the text is in English, translate it to Chinese.
            For other languages, translate to English.
            Return only the translated text without any explanation.

            Text:
            \(content)
            """
        } else {
            prompt = """
            Translate the following text to \(languageName).
            Return only the translated text without any explanation.

            Text:
            \(content)
            """
        }

        let response = try await session.respond(to: prompt)
        return response.content
    }

    private static func languageDisplayName(for code: String) -> String {
        switch code {
        case "en": return "English"
        case "zh-Hans": return "Simplified Chinese"
        case "zh-Hant": return "Traditional Chinese"
        case "ja": return "Japanese"
        case "es": return "Spanish"
        case "fr": return "French"
        default: return "English"
        }
    }

    private func activeSession() throws -> LanguageModelSession {
        let state = availabilityState()
        guard state.isAvailable else {
            session = nil
            throw AIError.unavailable(state.localizedDescription)
        }

        if let session {
            return session
        }

        let newSession = LanguageModelSession(instructions: Self.instructions)
        session = newSession
        return newSession
    }

    private static let instructions = """
    You are a helpful assistant for the Essays app, a macOS client for Memos.
    You MUST detect the language of the user's input and respond in the SAME language.
    If the user writes in Chinese (中文), you MUST respond in Chinese.
    If the user writes in English, respond in English.

    Your primary functions are:
    1. Help users write, edit, and improve their memos (帮助用户撰写、编辑和改进闪念)
    2. Summarize long memos (总结较长的闪念)
    3. Generate tags for memos based on content (根据内容生成标签)
    4. Help organize and categorize thoughts (帮助组织和分类想法)
    5. Answer questions about the user's notes (回答关于用户笔记的问题)

    Always be concise and helpful. When generating tags, provide 3-5 relevant tags.
    When summarizing, keep it brief but capture the key points.
    始终保持简洁和实用。生成标签时，提供 3-5 个相关标签。
    总结时，保持简短但捕捉关键要点。
    """
}
#else
actor MemosAIAssistant {
    static let shared = MemosAIAssistant()
    private init() {}
    func availabilityState() -> AIAssistantAvailabilityState { return .unsupportedOS }
    func initialize() async {}
    func generateTags(for content: String) async throws -> [String] { return [] }
    func summarize(_ content: String) async throws -> String { return "" }
    func improve(_ content: String) async throws -> String { return "" }
    func expand(_ content: String) async throws -> String { return "" }
    func generateRelatedIdeas(for content: String) async throws -> [String] { return [] }
    func answerQuestion(_ question: String, context: [String]) async throws -> String { return "" }
    func translate(_ content: String, to language: String) async throws -> String { return "" }
}
#endif

enum AIError: Error, LocalizedError {
    case notInitialized
    case generationFailed(String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return String(localized: "AI assistant not initialized")
        case .generationFailed(let message):
            return String(format: String(localized: "AI generation failed: %@"), message)
        case .unavailable(let message):
            return message
        }
    }
}

enum AIAssistantAvailabilityState: Equatable, Sendable {
    case checking
    case available
    case appleIntelligenceNotEnabled
    case modelNotReady
    case deviceNotEligible
    case unsupportedOS
    case unavailable

    var isAvailable: Bool {
        self == .available
    }

    var localizedTitle: String {
        switch self {
        case .checking:
            return String(localized: "Checking AI availability...", comment: "AI availability status")
        case .available:
            return String(localized: "AI Ready", comment: "AI ready status")
        case .appleIntelligenceNotEnabled:
            return String(localized: "Apple Intelligence Off", comment: "AI availability status")
        case .modelNotReady:
            return String(localized: "AI Model Not Ready", comment: "AI availability status")
        case .deviceNotEligible:
            return String(localized: "Device Not Eligible", comment: "AI availability status")
        case .unsupportedOS:
            return String(localized: "Unsupported macOS Version", comment: "AI availability status")
        case .unavailable:
            return String(localized: "AI Unavailable", comment: "AI availability status")
        }
    }

    var localizedDescription: String {
        switch self {
        case .checking:
            return String(localized: "Checking whether Apple Intelligence is available.", comment: "AI availability description")
        case .available:
            return String(localized: "Apple Intelligence is available.", comment: "AI availability description")
        case .appleIntelligenceNotEnabled:
            return String(localized: "Apple Intelligence is turned off in System Settings.", comment: "AI availability description")
        case .modelNotReady:
            return String(localized: "The Apple Intelligence model is not ready yet.", comment: "AI availability description")
        case .deviceNotEligible:
            return String(localized: "This device does not support Apple Intelligence.", comment: "AI availability description")
        case .unsupportedOS:
            return String(localized: "AI Assistant requires macOS 26.0+ or iOS 26.0+", comment: "AI assistant availability fallback")
        case .unavailable:
            return String(localized: "Apple Intelligence is not available right now.", comment: "AI availability description")
        }
    }

    @MainActor
    static func current() async -> AIAssistantAvailabilityState {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            return await MemosAIAssistant.shared.availabilityState()
        }
        return .unsupportedOS
        #else
        return .unsupportedOS
        #endif
    }
}
