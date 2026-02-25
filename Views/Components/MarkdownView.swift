import SwiftUI

struct MarkdownView: View {
    let content: String
    var fontSize: CGFloat = 14
    var lineSpacing: CGFloat = 6
    
    var body: some View {
        VStack(alignment: .leading, spacing: lineSpacing) {
            ForEach(parseMarkdown(), id: \.self) { segment in
                renderSegment(segment)
            }
        }
    }
    
    private func parseMarkdown() -> [MarkdownSegment] {
        var segments: [MarkdownSegment] = []
        var currentText = content
        
        while !currentText.isEmpty {
            if let codeBlock = parseCodeBlock(&currentText) {
                segments.append(codeBlock)
            } else if let header = parseHeader(&currentText) {
                segments.append(header)
            } else if let bold = parseBold(&currentText) {
                segments.append(bold)
            } else if let link = parseLink(&currentText) {
                segments.append(link)
            } else if let tag = parseTag(&currentText) {
                segments.append(tag)
            } else if let inlineCode = parseInlineCode(&currentText) {
                segments.append(inlineCode)
            } else {
                let char = String(currentText.prefix(1))
                currentText.removeFirst()
                
                if let lastSegment = segments.last, lastSegment.type == .text {
                    segments[segments.count - 1] = MarkdownSegment(
                        type: .text,
                        content: lastSegment.content + char
                    )
                } else {
                    segments.append(MarkdownSegment(type: .text, content: char))
                }
            }
        }
        
        return segments
    }
    
    private func parseCodeBlock(_ text: inout String) -> MarkdownSegment? {
        guard text.hasPrefix("```") else { return nil }
        
        let startIndex = text.index(text.startIndex, offsetBy: 3)
        guard let endIndex = text[startIndex...].firstIndex(of: "\n") else { return nil }
        
        let language = String(text[text.startIndex..<endIndex].dropFirst(3))
        let remaining = text[text.index(after: endIndex)...]
        
        guard let closeRange = remaining.range(of: "\n```") else { return nil }
        
        let code = String(remaining[..<closeRange.lowerBound])
        text = String(remaining[closeRange.upperBound...])
        return MarkdownSegment(type: .codeBlock(language: language), content: code)
    }
    
    private func parseHeader(_ text: inout String) -> MarkdownSegment? {
        let lines = text.split(separator: "\n", maxSplits: 1)
        guard let firstLine = lines.first else { return nil }
        
        let headerPattern = "^(#{1,6})\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: headerPattern) else { return nil }
        let range = NSRange(firstLine.startIndex..., in: firstLine)
        guard let match = regex.firstMatch(in: String(firstLine), range: range) else { return nil }
        
        let levelRange = Range(match.range(at: 1), in: firstLine)!
        let contentRange = Range(match.range(at: 2), in: firstLine)!
        let level = firstLine[levelRange].count
        let headerContent = String(firstLine[contentRange])
        
        if lines.count > 1 {
            text = String(lines[1])
        } else {
            text = ""
        }
        
        return MarkdownSegment(type: .header(level: level), content: headerContent)
    }
    
    private func parseBold(_ text: inout String) -> MarkdownSegment? {
        guard text.hasPrefix("**") || text.hasPrefix("__") else { return nil }
        
        let delimiter = text.hasPrefix("**") ? "**" : "__"
        let searchStart = text.index(text.startIndex, offsetBy: 2)
        
        guard let closeRange = text[searchStart...].range(of: delimiter) else { return nil }
        
        let content = String(text[searchStart..<closeRange.lowerBound])
        text = String(text[closeRange.upperBound...])
        
        return MarkdownSegment(type: .bold, content: content)
    }
    
    private func parseLink(_ text: inout String) -> MarkdownSegment? {
        guard text.hasPrefix("[") else { return nil }
        
        guard let textEnd = text.dropFirst().firstIndex(of: "]") else { return nil }
        let afterBracket = text.index(after: textEnd)
        
        guard afterBracket < text.endIndex && text[afterBracket] == "(" else { return nil }
        
        let linkText = String(text[text.index(after: text.startIndex)..<textEnd])
        let parenStart = text.index(after: afterBracket)
        
        guard let parenEnd = text[parenStart...].firstIndex(of: ")") else { return nil }
        
        let url = String(text[parenStart..<parenEnd])
        text = String(text[text.index(after: parenEnd)...])
        
        return MarkdownSegment(type: .link(url: url), content: linkText)
    }
    
    private func parseTag(_ text: inout String) -> MarkdownSegment? {
        guard text.hasPrefix("#") else { return nil }
        
        let tagPattern = "^#([a-zA-Z0-9_\\u4e00-\\u9fff]+)"
        guard let regex = try? NSRegularExpression(pattern: tagPattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        
        let tagRange = Range(match.range(at: 0), in: text)!
        let tag = String(text[tagRange])
        text = String(text[tagRange.upperBound...])
        
        return MarkdownSegment(type: .tag, content: tag)
    }
    
    private func parseInlineCode(_ text: inout String) -> MarkdownSegment? {
        guard text.hasPrefix("`") else { return nil }
        
        let searchStart = text.index(after: text.startIndex)
        guard let closeIndex = text[searchStart...].firstIndex(of: "`") else { return nil }
        
        let code = String(text[searchStart..<closeIndex])
        text = String(text[text.index(after: closeIndex)...])
        
        return MarkdownSegment(type: .inlineCode, content: code)
    }
    
    @ViewBuilder
    private func renderSegment(_ segment: MarkdownSegment) -> some View {
        switch segment.type {
        case .text:
            Text(segment.content)
                .font(.system(size: fontSize, design: .rounded))
                .foregroundColor(LiquidGlassTheme.colors.text)
        
        case .bold:
            Text(segment.content)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundColor(LiquidGlassTheme.colors.text)
        
        case .header(let level):
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
            
            Text(segment.content)
                .font(.system(size: headerSize, weight: .bold, design: .rounded))
                .foregroundColor(LiquidGlassTheme.colors.text)
        
        case .link(let url):
            if url.contains("@memos/") {
                Text(segment.content)
                    .font(.system(size: fontSize, design: .rounded))
                    .foregroundColor(LiquidGlassTheme.colors.accent)
                    .underline()
                    .onTapGesture {
                        // Optional: trigger navigation if we have access to AppState
                    }
            } else {
                Link(segment.content, destination: URL(string: url) ?? URL(string: "about:blank")!)
                    .font(.system(size: fontSize, design: .rounded))
                    .foregroundColor(LiquidGlassTheme.colors.accent)
            }
        
        case .tag:
            Text(segment.content)
                .font(.system(size: fontSize - 1, weight: .medium, design: .rounded))
                .foregroundColor(LiquidGlassTheme.colors.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(LiquidGlassTheme.colors.tagBackground)
                )
        
        case .inlineCode:
            Text(segment.content)
                .font(.system(size: fontSize - 1, design: .monospaced))
                .foregroundColor(LiquidGlassTheme.colors.accent)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LiquidGlassTheme.colors.tertiaryBackground)
                )
        
        case .codeBlock(let language):
            VStack(alignment: .leading, spacing: 4) {
                if !language.isEmpty {
                    Text(language)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(LiquidGlassTheme.colors.secondaryText)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(segment.content)
                        .font(.system(size: fontSize - 1, design: .monospaced))
                        .foregroundColor(LiquidGlassTheme.colors.text)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(LiquidGlassTheme.colors.tertiaryBackground)
            )
        }
    }
}

struct MarkdownSegment: Equatable, Hashable {
    let type: SegmentType
    let content: String
    
    enum SegmentType: Equatable, Hashable {
        case text
        case bold
        case header(level: Int)
        case link(url: String)
        case tag
        case inlineCode
        case codeBlock(language: String)
    }
    
    static func == (lhs: MarkdownSegment, rhs: MarkdownSegment) -> Bool {
        lhs.type == rhs.type && lhs.content == rhs.content
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(content)
    }
}
