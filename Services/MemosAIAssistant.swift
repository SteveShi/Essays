import Foundation
#if os(macOS)
import FoundationModels
#endif

#if os(macOS)
@available(macOS 26.0, *)
actor MemosAIAssistant {
    static let shared = MemosAIAssistant()
    
    private var session: LanguageModelSession?
    
    private init() {}
    
    func initialize() async {
        let instructions = """
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
        
        session = LanguageModelSession(instructions: instructions)
    }
    
    func generateTags(for content: String) async throws -> [String] {
        guard let session = session else {
            throw AIError.notInitialized
        }
        
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
        guard let session = session else {
            throw AIError.notInitialized
        }
        
        let prompt = """
        Summarize the following memo in 1-2 sentences.
        IMPORTANT: Respond in the same language as the content.
        
        \(content)
        """
        
        let response = try await session.respond(to: prompt)
        return response.content
    }
    
    func improve(_ content: String) async throws -> String {
        guard let session = session else {
            throw AIError.notInitialized
        }
        
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
        guard let session = session else {
            throw AIError.notInitialized
        }
        
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
        guard let session = session else {
            throw AIError.notInitialized
        }
        
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
        guard let session = session else {
            throw AIError.notInitialized
        }
        
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
}
#else
actor MemosAIAssistant {
    static let shared = MemosAIAssistant()
    private init() {}
    func initialize() async {}
    func generateTags(for content: String) async throws -> [String] { return [] }
    func summarize(_ content: String) async throws -> String { return "" }
    func improve(_ content: String) async throws -> String { return "" }
    func expand(_ content: String) async throws -> String { return "" }
    func generateRelatedIdeas(for content: String) async throws -> [String] { return [] }
    func answerQuestion(_ question: String, context: [String]) async throws -> String { return "" }
}
#endif

enum AIError: Error, LocalizedError {
    case notInitialized
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return String(localized: "AI assistant not initialized")
        case .generationFailed(let message):
            return String(format: String(localized: "AI generation failed: %@"), message)
        }
    }
}
