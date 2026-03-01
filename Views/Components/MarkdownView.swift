import SwiftUI

struct MarkdownView: View {
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
        // Step 1: 预处理任务列表 (Task Lists)
        let processedText = preprocessTaskLists(text)

        // Step 2: 使用系统原生的 AttributedString(markdown:)
        var options = AttributedString.MarkdownParsingOptions()
        options.allowsExtendedAttributes = true
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace

        do {
            var attributedString = try AttributedString(markdown: processedText, options: options)

            // 全局基础样式
            attributedString.font = .system(size: fontSize, design: .rounded)
            attributedString.foregroundColor = LiquidGlassTheme.colors.text

            // Step 3: 后处理样式 (Tags & Headers)
            var finalResult = attributedString
            finalResult = processTags(in: finalResult)
            finalResult = processHeaders(in: finalResult)

            return finalResult
        } catch {
            var fallback = AttributedString(text)
            fallback.font = .system(size: fontSize, design: .rounded)
            fallback.foregroundColor = LiquidGlassTheme.colors.text
            return fallback
        }
    }

    private func preprocessTaskLists(_ text: String) -> String {
        var result = text
        // [ ] -> 􀂒 (square), [x] -> 􀃈 (checkmark.square.fill)
        result = result.replacingOccurrences(of: "- [ ] ", with: "􀂒 ")
        result = result.replacingOccurrences(of: "- [x] ", with: "􀃈 ")
        result = result.replacingOccurrences(of: "* [ ] ", with: "􀂒 ")
        result = result.replacingOccurrences(of: "* [x] ", with: "􀃈 ")
        return result
    }

    private func processHeaders(in attributedString: AttributedString) -> AttributedString {
        var result = attributedString
        let text = String(result.characters)

        guard let regex = Self.headerRegex else { return result }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches.reversed() {
            if let headerRange = Range(match.range, in: result) {
                let matchString = String(text[Range(match.range, in: text)!])
                let hashes = matchString.prefix(while: { $0 == "#" }).count

                let headerSize: CGFloat = {
                    switch hashes {
                    case 1: return fontSize + 6
                    case 2: return fontSize + 4
                    case 3: return fontSize + 2
                    default: return fontSize
                    }
                }()
                
                result[headerRange].font = .system(
                    size: headerSize, weight: .bold, design: .rounded)
            }
        }
        return result
    }

    private func processTags(in attributedString: AttributedString) -> AttributedString {
        var result = attributedString
        let text = String(result.characters)
        let range = NSRange(text.startIndex..., in: text)

        guard let regex = Self.tagRegex else { return result }
        let matches = regex.matches(in: text, range: range)

        for match in matches.reversed() {
            if let tagRange = Range(match.range, in: result) {
                result[tagRange].foregroundColor = LiquidGlassTheme.colors.accent
                result[tagRange].font = .system(size: fontSize, weight: .medium, design: .rounded)
            }
        }
        
        return result
    }

    private static let tagRegex = try? NSRegularExpression(pattern: "#[^\\s#]+")
    private static let headerRegex = try? NSRegularExpression(pattern: "(?m)^#{1,6}\\s.*$")
}
