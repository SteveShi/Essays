import SwiftUI
import SwiftData

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
#endif
struct AIAssistantView: View {
    let memo: Memo
    @Environment(\.dismiss) private var dismiss
    
    enum AIAction: String, CaseIterable {
        case summarize
        case improve
        case expand
        case generateTags
        case relatedIdeas
        case translate
        
        var title: String {
            switch self {
            case .summarize: return String(localized: "Summarize", comment: "AI action: summarize memo")
            case .improve: return String(localized: "Improve Writing", comment: "AI action: improve writing")
            case .expand: return String(localized: "Expand", comment: "AI action: expand memo")
            case .generateTags: return String(localized: "Generate Tags", comment: "AI action: generate tags")
            case .relatedIdeas: return String(localized: "Related Ideas", comment: "AI action: related ideas")
            case .translate: return String(localized: "Translate", comment: "AI action: translate memo")
            }
        }
        
        var icon: String {
            switch self {
            case .summarize: return "text.quote"
            case .improve: return "pencil.and.outline"
            case .expand: return "text.append"
            case .generateTags: return "tag"
            case .relatedIdeas: return "lightbulb"
            case .translate: return "globe"
            }
        }
        
        var description: String {
            switch self {
            case .summarize: return String(localized: "Generate a brief summary", comment: "AI action description")
            case .improve: return String(localized: "Polish grammar and clarity", comment: "AI action description")
            case .expand: return String(localized: "Add more details and examples", comment: "AI action description")
            case .generateTags: return String(localized: "Suggest relevant tags", comment: "AI action description")
            case .relatedIdeas: return String(localized: "Discover related topics", comment: "AI action description")
            case .translate: return String(localized: "Translate to another language", comment: "AI action description")
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider().opacity(0.3)
                
                // Content preview
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.5))
                        .frame(width: 3)
                    
                    Text(memo.content)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider().opacity(0.3)
                
                // Action Links
                VStack(spacing: 0) {
                    ForEach(AIAction.allCases, id: \.self) { action in
                        NavigationLink(value: action) {
                            HStack(spacing: 12) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 24)
                                    .foregroundColor(.accentColor)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.title)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text(action.description)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if action != AIAction.allCases.last {
                            Divider().padding(.leading, 52).opacity(0.2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationDestination(for: AIAction.self) { action in
                AIAssistantDetailView(memo: memo, action: action)
            }
        }
        #if os(macOS)
        .frame(width: 320)
        .frame(minHeight: 100, maxHeight: 600)
        #endif
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
#endif
struct AIAssistantDetailView: View {
    let memo: Memo
    let action: AIAssistantView.AIAction
    
    @State private var result: String = ""
    @State private var resultTags: [String] = []
    @State private var isProcessing = true
    @State private var errorMessage: String?
    @AppStorage("targetTranslationLanguage") private var targetTranslationLanguage = "auto"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isProcessing {
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.regular)
                            Text(String(localized: "AI is thinking...", comment: "AI processing indicator"))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                        Spacer()
                    }
                } else if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                    .padding()
                } else {
                    if !resultTags.isEmpty {
                        FlowLayoutAI(spacing: 8) {
                            ForEach(resultTags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.accentColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.1))
                                    )
                            }
                        }
                        .padding(16)
                    } else {
                        Text(result)
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .padding(16)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(action.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !isProcessing && errorMessage == nil {
                    Button {
                        let text = resultTags.isEmpty ? result : resultTags.map { "#\($0)" }.joined(separator: " ")
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        #else
                        UIPasteboard.general.string = text
                        #endif
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    #if os(macOS)
                    .help(String(localized: "Copy to Clipboard", comment: "Copy AI result"))
                    #endif
                }
            }
        }
        .task {
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
                case .translate:
                    result = try await MemosAIAssistant.shared.translate(memo.content, to: targetTranslationLanguage)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            
            isProcessing = false
        }
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
