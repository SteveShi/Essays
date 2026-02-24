import SwiftUI
import Foundation

struct LiquidGlassTheme {
    static let colors = ThemeColors()
    static let typography = ThemeTypography()
    static let spacing = ThemeSpacing()
    static let animation = ThemeAnimation()
    static let glass = GlassEffect()
}

struct ThemeColors {
    let background = Color(nsColor: .windowBackgroundColor)
    let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    let tertiaryBackground = Color(nsColor: .underPageBackgroundColor)
    
    let text = Color(nsColor: .textColor)
    let secondaryText = Color(nsColor: .secondaryLabelColor)
    let tertiaryText = Color(nsColor: .tertiaryLabelColor)
    
    let accent = Color.accentColor
    let accentHover = Color.accentColor.opacity(0.8)
    
    let separator = Color(nsColor: .separatorColor)
    let border = Color(nsColor: .gridColor)
    
    let success = Color.green
    let warning = Color.orange
    let error = Color.red
    let info = Color.blue
    
    let tagBackground = Color.accentColor.opacity(0.15)
    let tagText = Color.accentColor
    
    let pinnedBackground = Color.yellow.opacity(0.1)
    let pinnedBorder = Color.yellow.opacity(0.3)
    
    let glassBackground = Color.white.opacity(0.08)
    let glassBorder = Color.white.opacity(0.12)
    
    let sidebarBackground = Color(nsColor: .controlBackgroundColor).opacity(0.95)
    let cardBackground = Color(nsColor: .controlBackgroundColor)
    
    let hoverOverlay = Color.white.opacity(0.05)
    let pressedOverlay = Color.white.opacity(0.08)
    
    func gradient(for scheme: ColorScheme) -> LinearGradient {
        switch scheme {
        case .dark:
            return LinearGradient(
                colors: [
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.1),
                    Color.black.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .light:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.5),
                    Color.white.opacity(0.3),
                    Color.white.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        @unknown default:
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.5),
                    Color.white.opacity(0.3),
                    Color.white.opacity(0.4)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct ThemeTypography {
    let largeTitle = Font.system(size: 28, weight: .semibold, design: .default)
    let title = Font.system(size: 20, weight: .semibold, design: .default)
    let title2 = Font.system(size: 17, weight: .semibold, design: .default)
    let title3 = Font.system(size: 15, weight: .semibold, design: .default)
    let headline = Font.system(size: 14, weight: .semibold, design: .default)
    let body = Font.system(size: 14, weight: .regular, design: .default)
    let callout = Font.system(size: 13, weight: .regular, design: .default)
    let subheadline = Font.system(size: 12, weight: .regular, design: .default)
    let footnote = Font.system(size: 11, weight: .regular, design: .default)
    let caption = Font.system(size: 10, weight: .medium, design: .default)
    let caption2 = Font.system(size: 9, weight: .medium, design: .default)
    
    let monoBody = Font.system(size: 13, weight: .regular, design: .monospaced)
    let monoCaption = Font.system(size: 11, weight: .regular, design: .monospaced)
}

struct ThemeSpacing {
    let extraSmall: CGFloat = 4
    let small: CGFloat = 8
    let medium: CGFloat = 12
    let standard: CGFloat = 16
    let large: CGFloat = 20
    let extraLarge: CGFloat = 24
    let huge: CGFloat = 32
    
    let cardPadding: CGFloat = 16
    let sectionSpacing: CGFloat = 24
    let listItemSpacing: CGFloat = 12
    
    let sidebarWidth: CGFloat = 260
    let sidebarItemHeight: CGFloat = 36
    let memoCardMinHeight: CGFloat = 80
}

struct ThemeAnimation {
    let fast: Double = 0.15
    let standard: Double = 0.25
    let slow: Double = 0.35
    
    let spring = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0)
    let easeInOut = Animation.easeInOut(duration: 0.25)
    let easeOut = Animation.easeOut(duration: 0.2)
}

struct GlassEffect {
    func material() -> some View {
        Rectangle()
            .fill(.ultraThinMaterial)
    }
    
    func cardBackground(isHovered: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(LiquidGlassTheme.colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isHovered
                            ? LiquidGlassTheme.colors.accent.opacity(0.4)
                            : LiquidGlassTheme.colors.border.opacity(0.3),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    func sidebarItemBackground(isSelected: Bool = false, isHovered: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected
                ? LiquidGlassTheme.colors.accent.opacity(0.15)
                : isHovered
                    ? LiquidGlassTheme.colors.hoverOverlay
                    : Color.clear
            )
    }
    
    func buttonBackground(isPressed: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isPressed
                ? LiquidGlassTheme.colors.pressedOverlay
                : LiquidGlassTheme.colors.glassBackground
            )
    }
    
    func tagBackground() -> some View {
        Capsule()
            .fill(LiquidGlassTheme.colors.tagBackground)
    }
}

struct ThemedButtonStyle: ButtonStyle {
    var isPrimary: Bool = false
    var size: Size = .medium
    
    enum Size {
        case small, medium, large
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }
        
        var verticalPadding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 13
            case .large: return 15
            }
        }
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .medium, design: .rounded))
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isPrimary
                        ? LiquidGlassTheme.colors.accent
                        : configuration.isPressed
                            ? LiquidGlassTheme.colors.pressedOverlay
                            : LiquidGlassTheme.colors.glassBackground
                    )
            )
            .foregroundColor(isPrimary ? .white : LiquidGlassTheme.colors.text)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(LiquidGlassTheme.animation.easeOut, value: configuration.isPressed)
    }
}

struct CardStyle: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background(LiquidGlassTheme.glass.cardBackground(isHovered: isHovered))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onHover { hovering in
                withAnimation(LiquidGlassTheme.animation.easeOut) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
    
    func glassEffect() -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
