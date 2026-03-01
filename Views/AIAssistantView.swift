import SwiftUI

@available(macOS 26.0, *)
struct AIAssistantView: View {
    let memo: Memo
    @Environment(\.dismiss) private var dismiss
    
    @State private var result: String = ""
    @State private var resultTags: [String] = []
    @State private var isProcessing = false
    @State private var currentAction: AIAction?
    @State private var errorMessage: String?
    
    enum AIAction: String, CaseIterable {
        case summarize
        case improve
        case expand
        case generateTags
        case relatedIdeas
        
        var title: String {
            switch self {
            case .summarize: return String(localized: "Summarize", comment: "AI action: summarize memo")
            case .improve: return String(localized: "Improve Writing", comment: "AI action: improve writing")
            case .expand: return String(localized: "Expand", comment: "AI action: expand memo")
            case .generateTags: return String(localized: "Generate Tags", comment: "AI action: generate tags")
            case .relatedIdeas: return String(localized: "Related Ideas", comment: "AI action: related ideas")
            }
        }
        
        var icon: String {
            switch self {
            case .summarize: return "text.quote"
            case .improve: return "pencil.and.outline"
            case .expand: return "text.append"
            case .generateTags: return "tag"
            case .relatedIdeas: return "lightbulb"
            }
        }
        
        var description: String {
            switch self {
            case .summarize: return String(localized: "Generate a brief summary", comment: "AI action description")
            case .improve: return String(localized: "Polish grammar and clarity", comment: "AI action description")
            case .expand: return String(localized: "Add more details and examples", comment: "AI action description")
            case .generateTags: return String(localized: "Suggest relevant tags", comment: "AI action description")
            case .relatedIdeas: return String(localized: "Discover related topics", comment: "AI action description")
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Text(String(localized: "AI Assistant", comment: "AI assistant panel title"))
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider().opacity(0.3)
            
            // Content preview
            Text(memo.content)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            
            Divider().opacity(0.3)
            
            // Action buttons
            VStack(spacing: 2) {
                ForEach(AIAction.allCases, id: \.self) { action in
                    Button {
                        Task {
                            await performAction(action)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: action.icon)
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 20)
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(action.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text(action.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if currentAction == action && isProcessing {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                }
            }
            .padding(.vertical, 4)
            
            // Result area
            if !result.isEmpty || !resultTags.isEmpty {
                Divider().opacity(0.3)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(currentAction?.title ?? "")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        Spacer()
                        
                        Button {
                            let text = resultTags.isEmpty ? result : resultTags.map { "#\($0)" }.joined(separator: " ")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "Copy to Clipboard", comment: "Copy AI result"))
                    }
                    
                    if !resultTags.isEmpty {
                        FlowLayoutAI(spacing: 6) {
                            ForEach(resultTags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.1))
                                    )
                            }
                        }
                    } else {
                        Text(result)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxHeight: 150)
            }
            
            // Error
            if let error = errorMessage {
                Divider().opacity(0.3)
                
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func performAction(_ action: AIAction) async {
        currentAction = action
        isProcessing = true
        result = ""
        resultTags = []
        errorMessage = nil
        
        do {
            switch action {
            case .summarize:
                result = try await MemosAIAssistant.shared.summarize(memo.content)
            case .improve:
                result = try await MemosAIAssistant.shared.improve(memo.content)
            case .expand:
                result = try await MemosAIAssistant.shared.expand(memo.content)
            case .generateTags:
                resultTags = try await MemosAIAssistant.shared.generateTags(for: memo.content)
            case .relatedIdeas:
                let ideas = try await MemosAIAssistant.shared.generateRelatedIdeas(for: memo.content)
                result = ideas.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isProcessing = false
    }
}

// Simple flow layout for tags
struct FlowLayoutAI: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }
        
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
