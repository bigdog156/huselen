import SwiftUI

// MARK: - Locket-inspired Cute Theme

enum Theme {
    // MARK: Colors - Warm, soft pastels with light/dark mode support
    enum Colors {
        // MARK: Accent Colors (same in both modes — used as brand/action accents)
        static let warmYellow  = Color(red: 1.0,  green: 0.82, blue: 0.20)
        static let softPink    = Color(red: 1.0,  green: 0.62, blue: 0.65)
        static let softOrange  = Color(red: 1.0,  green: 0.68, blue: 0.38)
        static let mintGreen   = Color(red: 0.56, green: 0.90, blue: 0.70)
        static let lavender    = Color(red: 0.73, green: 0.65, blue: 0.95)
        static let skyBlue     = Color(red: 0.55, green: 0.78, blue: 1.00)
        static let peach       = Color(red: 1.0,  green: 0.78, blue: 0.65)
        static let cream       = Color("ScreenBackground")

        // MARK: Semantic Colors (adaptive — from colorsets in Assets.xcassets)
        static let screenBackground        = Color("ScreenBackground")
        static let cardBackground          = Color("CardBackground")
        static let cardBackgroundSecondary = Color("CardBackgroundSecondary")
        static let textPrimary             = Color("TextPrimary")
        static let textSecondary           = Color("TextSecondary")
        static let textTertiary            = Color("TextTertiary")
        static let separator               = Color("Separator")
    }

    // MARK: Corner Radius
    enum Radius {
        static let small: CGFloat  = 14
        static let medium: CGFloat = 20
        static let large: CGFloat  = 26
        static let button: CGFloat = 16
    }

    // MARK: Fonts - Rounded design
    enum Fonts {
        static func largeTitle()  -> Font { .system(size: 32, weight: .bold,     design: .rounded) }
        static func title()       -> Font { .system(size: 24, weight: .bold,     design: .rounded) }
        static func title3()      -> Font { .system(size: 20, weight: .semibold, design: .rounded) }
        static func headline()    -> Font { .system(size: 17, weight: .semibold, design: .rounded) }
        static func body()        -> Font { .system(size: 16, weight: .regular,  design: .rounded) }
        static func subheadline() -> Font { .system(size: 14, weight: .medium,   design: .rounded) }
        static func caption()     -> Font { .system(size: 12, weight: .medium,   design: .rounded) }
    }
}

// MARK: - Cute Card Style

struct CuteCardModifier: ViewModifier {
    var padding: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .fill(Theme.Colors.cardBackground)
                    .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            )
    }
}

// MARK: - Cute Button Style

struct CuteButtonStyle: ButtonStyle {
    let color: Color
    let isFullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled

    init(color: Color = Theme.Colors.warmYellow, isFullWidth: Bool = true) {
        self.color = color
        self.isFullWidth = isFullWidth
    }

    func makeBody(configuration: Configuration) -> some View {
        let effectiveColor = isEnabled ? color : Color(UIColor.systemGray4)
        configuration.label
            .font(Theme.Fonts.headline())
            .foregroundStyle(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 16)
            .padding(.horizontal, isFullWidth ? 0 : 24)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    .fill(effectiveColor.gradient)
                    .shadow(color: effectiveColor.opacity(0.35), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Cute Text Field Style

struct CuteTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Fonts.body())
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(Color(UIColor.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                            .strokeBorder(Color(UIColor.systemGray4).opacity(0.5), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Cute Row / List Item Style

struct CuteRowModifier: ViewModifier {
    var color: Color = Theme.Colors.skyBlue

    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(Theme.Colors.cardBackground)
            )
    }
}

// MARK: - Cute Badge

struct CuteBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(Theme.Fonts.caption())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}

// MARK: - Cute Icon Circle

struct CuteIconCircle: View {
    let icon: String
    let color: Color
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(color.opacity(0.12))
            )
    }
}

// MARK: - Cute Stat Card

struct CuteStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(Theme.Fonts.title())
                .foregroundStyle(Theme.Colors.textPrimary)
            Text(title)
                .font(Theme.Fonts.caption())
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - View Extensions

extension View {
    func cuteCard(padding: CGFloat = 16) -> some View {
        modifier(CuteCardModifier(padding: padding))
    }

    func cuteTextField() -> some View {
        modifier(CuteTextFieldModifier())
    }

    func cuteRow(color: Color = Theme.Colors.skyBlue) -> some View {
        modifier(CuteRowModifier(color: color))
    }
}
