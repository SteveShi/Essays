import Foundation

enum MemoUtility {
    /// 从 Markdown 文本中提取标签 (#标签)
    /// 符合 Memos 规范: 支持中文、数字、字母、下划线，且标签前后需有空格或处于行首尾
    static func extractTags(from content: String) -> [String] {
        // 正则表达式说明:
        // (?<=^|\s) -> 前面是行首或空白字符 (零宽断言)
        // #          -> 匹配井号
        // ([^\s#]+)  -> 匹配非空白且非井号的字符 (标签内容)
        // (?=$|\s)   -> 后面是行尾或空白字符 (零宽断言)
        // 注意：这里为了支持中文等字符，使用更宽泛的匹配
        let pattern = "(?<=^|\\s)#([^\\s#]+)(?=$|\\s)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
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
        let pattern = "(?<=^|\\s)#([^\\s#]+)(?=$|\\s)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return content
        }
        
        let range = NSRange(content.startIndex..., in: content)
        var result = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: "")
        
        // 清理多余空格
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 从 Markdown 链接中提取引用的 Memo 资源名，供本地 Relation 同步使用。
    static func extractReferencedMemoNames(from content: String) -> [String] {
        let pattern = #"\[[^\]]+\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        var names: Set<String> = []
        for match in matches {
            guard let targetRange = Range(match.range(at: 1), in: content) else { continue }
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
        let pattern = #"!?\[([^\]]+)\]\([^)]+\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return content
        }

        let range = NSRange(content.startIndex..., in: content)
        return regex.stringByReplacingMatches(
            in: content,
            options: [],
            range: range,
            withTemplate: "$1"
        )
    }
}
