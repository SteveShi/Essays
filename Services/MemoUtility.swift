import Foundation

enum MemoUtility {
    // MARK: - Cached Regex
    // SwiftUI 列表行频繁调用这些方法，将 NSRegularExpression 预编译为静态常量，
    // 避免每次访问 `truncatedContent` / `relationPreviewContent` 时重新构造。

    /// 标签匹配：行首或空白之后的 `#xxx`，xxx 中不含空白或 `#`。
    private static let tagPattern = "(?<=^|\\s)#([^\\s#]+)(?=$|\\s)"
    private static let tagRegex: NSRegularExpression? = try? NSRegularExpression(pattern: tagPattern)

    /// Markdown 链接 `[text](url)`，可选前导 `!`（图片）。
    private static let markdownLinkRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: #"!?\[([^\]]+)\]\(([^)]+)\)"#)

    /// 多余空格折叠。
    private static let extraWhitespaceRegex: NSRegularExpression? =
        try? NSRegularExpression(pattern: "  +")

    /// 从 Markdown 文本中提取标签 (#标签)
    /// 符合 Memos 规范: 支持中文、数字、字母、下划线，且标签前后需有空格或处于行首尾
    static func extractTags(from content: String) -> [String] {
        guard let regex = tagRegex else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        var tags: Set<String> = []
        for match in matches {
            if let tagRange = Range(match.range(at: 1), in: content) {
                let tag = String(content[tagRange])
                if !tag.isEmpty {
                    tags.insert(tag)
                }
            }
        }
        return Array(tags).sorted()
    }

    /// 从文本中移除标签 (#标签)
    static func stripTags(from content: String) -> String {
        guard let regex = tagRegex else { return content }
        let range = NSRange(content.startIndex..., in: content)
        var result = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: "")

        if let whitespaceRegex = extraWhitespaceRegex {
            let resultRange = NSRange(result.startIndex..., in: result)
            result = whitespaceRegex.stringByReplacingMatches(
                in: result, options: [], range: resultRange, withTemplate: " ")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 从 Markdown 链接中提取引用的 Memo 资源名，供本地 Relation 同步使用。
    static func extractReferencedMemoNames(from content: String) -> [String] {
        guard let regex = markdownLinkRegex else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        var names: Set<String> = []
        for match in matches {
            guard let targetRange = Range(match.range(at: 2), in: content) else { continue }
            var candidate = String(content[targetRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            candidate = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            guard !candidate.isEmpty else { continue }

            // 只接受 Memo 资源名，避免把普通 URL 误判成引用关系。
            if candidate.hasPrefix("memos/") || candidate.hasPrefix("local_") {
                names.insert(candidate)
            } else if let memosRange = candidate.range(of: "memos/") {
                names.insert(String(candidate[memosRange.lowerBound...]))
            }
        }

        return Array(names).sorted()
    }

    /// 将 Markdown 链接语法转换为可读文本，例如 `[Memo](memos/123)` -> `Memo`。
    static func stripMarkdownLinks(from content: String) -> String {
        guard let regex = markdownLinkRegex else { return content }
        let range = NSRange(content.startIndex..., in: content)
        return regex.stringByReplacingMatches(
            in: content,
            options: [],
            range: range,
            withTemplate: "$1"
        )
    }
}
