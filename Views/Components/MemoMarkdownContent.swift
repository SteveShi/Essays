import SwiftUI
import MarkdownView

/// 对 mudkipme/MarkdownView 库的轻量封装
struct MemoMarkdownContent: View {
    let content: String

    var body: some View {
        MarkdownView(content)
            .textSelection(.enabled)
            .foregroundStyle(LiquidGlassTheme.colors.text)
            .tint(LiquidGlassTheme.colors.accent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
