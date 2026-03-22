import SwiftUI

public struct FrostTheme {
    // Background gradient for light mode
    public static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.91, green: 0.92, blue: 0.96),   // #E8EAF6
            Color(red: 0.96, green: 0.97, blue: 0.98)    // #F5F7FA
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Background gradient for dark mode
    public static let darkBackgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.09, blue: 0.14),   // #141724
            Color(red: 0.11, green: 0.12, blue: 0.18)    // #1C1F2E
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Accent gradient (Indigo -> Purple)
    public static let accentGradient = LinearGradient(
        colors: [
            Color(red: 0.39, green: 0.40, blue: 0.95),   // #6366F1
            Color(red: 0.66, green: 0.33, blue: 0.97)    // #A855F7
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

public struct FrostCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public var cornerRadius: CGFloat
    
    public init(cornerRadius: CGFloat = 20) {
        self.cornerRadius = cornerRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .shadow(
                color: colorScheme == .dark ? .black.opacity(0.3) : .black.opacity(0.06),
                radius: 16,
                y: 6
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        colorScheme == .dark ? .white.opacity(0.1) : .white.opacity(0.25),
                        lineWidth: 1
                    )
            )
    }
}

public extension View {
    func frostCard(cornerRadius: CGFloat = 20) -> some View {
        self.modifier(FrostCardModifier(cornerRadius: cornerRadius))
    }
    
    // Background applying dynamic frost gradient
    func frostBackground() -> some View {
        self.modifier(FrostBackgroundModifier())
    }
}

public struct FrostBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    public func body(content: Content) -> some View {
        ZStack {
            if colorScheme == .dark {
                FrostTheme.darkBackgroundGradient.ignoresSafeArea()
            } else {
                FrostTheme.backgroundGradient.ignoresSafeArea()
            }
            content
        }
    }
}

public struct FrostPrimaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(FrostTheme.accentGradient)
            .foregroundColor(.white)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 2 : 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

public struct FrostSecondaryButtonStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(.ultraThinMaterial)
            .foregroundColor(.primary)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.1), radius: configuration.isPressed ? 2 : 4, y: configuration.isPressed ? 1 : 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == FrostPrimaryButtonStyle {
    static var frostPrimary: FrostPrimaryButtonStyle { FrostPrimaryButtonStyle() }
}

public extension ButtonStyle where Self == FrostSecondaryButtonStyle {
    static var frostSecondary: FrostSecondaryButtonStyle { FrostSecondaryButtonStyle() }
}
