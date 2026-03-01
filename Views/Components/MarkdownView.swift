import SwiftUI

struct MarkdownView: View {
    @Environment(AppState.self) var appState
    let content: String
    var fontSize: CGFloat = 14
    var lineSpacing: CGFloat = 8

    // Cache the rendered result within the view instance to avoid re-parsing on every body call
    @State private var cachedResult: AttributedString?
    @State private var lastParsedContent: String = ""

    var body: some View {
        Group {
            if let result = cachedResult, lastParsedContent == content {
                Text(result)
            } else {
                Text(render(content))
                    .onAppear { updateCache() }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: content) { updateCache() }
    }

    private func updateCache() {
        cachedResult = render(content)
        lastParsedContent = content
    }

    private func render(_ text: String) -> AttributedString {
        let lines = text.components(separatedBy: "\n")
        var finalAttrString = AttributedString("")
        var isFirst = true

        for line in lines {
            if !isFirst {
                var newline = AttributedString("\n")
                newline.font = .system(size: fontSize, design: .rounded)
                finalAttrString.append(newline)
            }
            isFirst = false
            finalAttrString.append(renderLine(line))
        }
        return finalAttrString
    }

    private func renderLine(_ line: String) -> AttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return AttributedString("") }

        // Headers
        if trimmed.hasPrefix("#") {
            var level = 0
            for ch in trimmed {
                if ch == "#" { level += 1 } else { break }
            }
            if level >= 1 && level <= 6 && trimmed.count > level {
                let checkIndex = trimmed.index(trimmed.startIndex, offsetBy: level)
                if trimmed[checkIndex] == " " {
                    let headerContent = String(trimmed.dropFirst(level + 1))
                    let headerSize: CGFloat = {
                        switch level {
                        case 1: return fontSize + 10
                        case 2: return fontSize + 8
                        case 3: return fontSize + 6
                        case 4: return fontSize + 4
                        case 5: return fontSize + 2
                        default: return fontSize
                        }
                    }()
                    var attrStr = AttributedString(headerContent)
                    attrStr.font = .system(size: headerSize, weight: .bold, design: .rounded)
                    attrStr.foregroundColor = LiquidGlassTheme.colors.text
                    return attrStr
                }
            }
        }

        // Code block fence lines
        if trimmed.hasPrefix("```") {
            let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if lang.isEmpty { return AttributedString("") }
            var codeAttr = AttributedString(lang)
            codeAttr.font = .system(size: fontSize - 2, weight: .medium, design: .monospaced)
            codeAttr.foregroundColor = LiquidGlassTheme.colors.secondaryText
            return codeAttr
        }

        return parseInline(line)  // Use full line for inline to preserve leading spaces if needed
    }

    private func parseInline(_ text: String) -> AttributedString {
        var result = AttributedString("")
        var input = text
        
        while !input.isEmpty {
            // Bold **text**
            if input.hasPrefix("**"),
                let range = input.range(
                    of: "**", options: [],
                    range: input.index(input.startIndex, offsetBy: 2)..<input.endIndex)
            {
                let startPos = input.index(input.startIndex, offsetBy: 2)
                let boldContent = String(input[startPos..<range.lowerBound])
                var boldAttr = AttributedString(boldContent)
                boldAttr.font = .system(size: fontSize, weight: .semibold, design: .rounded)
                boldAttr.foregroundColor = LiquidGlassTheme.colors.text
                result.append(boldAttr)
                input = String(input[range.upperBound...])
                continue
            }

            // Inline code `code`
            if input.hasPrefix("`"),
                let range = input.range(
                    of: "`", options: [],
                    range: input.index(after: input.startIndex)..<input.endIndex)
            {
                let startPos = input.index(after: input.startIndex)
                let code = String(input[startPos..<range.lowerBound])
                var codeAttr = AttributedString(code)
                codeAttr.font = .system(size: fontSize - 1, design: .monospaced)
                codeAttr.foregroundColor = LiquidGlassTheme.colors.accent
                result.append(codeAttr)
                input = String(input[range.upperBound...])
                continue
            }

            // Tag #tag - Use pre-compiled regex
            if input.hasPrefix("#"),
                let match = MarkdownView.tagRegex?.firstMatch(
                    in: input, range: NSRange(input.startIndex..., in: input)),
                let range = Range(match.range, in: input)
            {
                let tag = String(input[range])
                var tagAttr = AttributedString(tag)
                tagAttr.font = .system(size: fontSize - 1, weight: .medium, design: .rounded)
                tagAttr.foregroundColor = LiquidGlassTheme.colors.accent
                result.append(tagAttr)
                input = String(input[range.upperBound...])
                continue
            }

            // Image ![alt](url)
            if input.hasPrefix("!["), let altEnd = input.firstIndex(of: "]"),
                input.index(after: altEnd) < input.endIndex,
                input[input.index(after: altEnd)] == "(", let parenEnd = input.firstIndex(of: ")")
            {
                let alt = String(input[input.index(input.startIndex, offsetBy: 2)..<altEnd])
                let label = alt.isEmpty ? "📷" : "📷 \(alt)"
                var imageAttr = AttributedString(label)
                imageAttr.font = .system(size: fontSize - 1, design: .rounded)
                imageAttr.foregroundColor = LiquidGlassTheme.colors.secondaryText
                result.append(imageAttr)
                input = String(input[input.index(after: parenEnd)...])
                continue
            }

            // Link [text](url)
            if input.hasPrefix("["), let textEnd = input.firstIndex(of: "]"),
                input.index(after: textEnd) < input.endIndex,
                input[input.index(after: textEnd)] == "(", let parenEnd = input.firstIndex(of: ")")
            {
                let linkText = String(input[input.index(after: input.startIndex)..<textEnd])
                var linkAttr = AttributedString(linkText)
                linkAttr.font = .system(size: fontSize, design: .rounded)
                linkAttr.foregroundColor = LiquidGlassTheme.colors.accent
                linkAttr.underlineStyle = .single
                result.append(linkAttr)
                input = String(input[input.index(after: parenEnd)...])
                continue
            }

            // Fallback for plain text
            let nextIndex = input.index(after: input.startIndex)
            let part = String(input[..<nextIndex])
            var plainAttr = AttributedString(part)
            plainAttr.font = .system(size: fontSize, design: .rounded)
            plainAttr.foregroundColor = LiquidGlassTheme.colors.text
            result.append(plainAttr)
            input = String(input[nextIndex...])
        }

        return result
    }

    private static let tagRegex = try? NSRegularExpression(
        pattern: "^#[a-zA-Z0-9_\\u{4e00}-\\u{9fff}]+")
}
