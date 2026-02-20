import SwiftUI

enum Theme {
    // MARK: - PostrBoard-Inspired Palette
    // Spectrum: salmon → dusty mauve → teal → green on icy blue backgrounds

    // Warm end of the spectrum
    static let peach = Color(red: 0.91, green: 0.52, blue: 0.42)       // #E8856C — salmon
    static let coral = Color(red: 0.85, green: 0.44, blue: 0.38)       // #D97060 — deeper salmon

    // Mid spectrum
    static let lavender = Color(red: 0.61, green: 0.56, blue: 0.66)    // #9B8EA8 — dusty mauve
    static let lilac = Color(red: 0.70, green: 0.65, blue: 0.75)       // #B3A6BF — lighter mauve
    static let skyBlue = Color(red: 0.45, green: 0.65, blue: 0.78)     // #73A6C7 — muted blue

    // Cool end of the spectrum
    static let mint = Color(red: 0.36, green: 0.74, blue: 0.69)        // #5DBDAF — teal/seafoam
    static let sage = Color(red: 0.30, green: 0.69, blue: 0.49)        // #4CAF7D — green
    static let softPink = Color(red: 0.45, green: 0.78, blue: 0.58)    // #73C794 — soft green (spectrum end)

    // UI accents
    static let warmYellow = Color(red: 0.91, green: 0.52, blue: 0.42)  // Same as peach for pin icon
    static let cream = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.16, blue: 0.20, alpha: 1)    // Dark surface
            : UIColor(red: 0.94, green: 0.96, blue: 0.98, alpha: 1)    // #F0F5FA — icy blue-white
    })

    // Neutral tones
    static let charcoal = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.90, green: 0.92, blue: 0.95, alpha: 1)    // Light text for dark mode
            : UIColor(red: 0.12, green: 0.14, blue: 0.17, alpha: 1)    // #1F232B — dark navy
    })
    static let darkGray = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.70, green: 0.72, blue: 0.76, alpha: 1)    // Muted light for dark mode
            : UIColor(red: 0.22, green: 0.24, blue: 0.28, alpha: 1)    // #383D47
    })

    // MARK: - Gradients

    /// User message bubble gradient — salmon to teal (the PostrBoard spectrum)
    static let userBubbleGradient = LinearGradient(
        colors: [peach, skyBlue, mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Send button gradient — the full PostrBoard spectrum pill
    static let sendButtonGradient = LinearGradient(
        colors: [peach, lavender, mint, sage],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Accent gradient — the signature PostrBoard spectrum for icons/text
    static let accentGradient = LinearGradient(
        colors: [peach, lavender, skyBlue, mint, sage],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Background gradient — cool icy blue-white (matches PostrBoard bg)
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.94, green: 0.96, blue: 0.99),    // Icy blue-white
            Color(red: 0.92, green: 0.95, blue: 0.98),    // Slightly deeper icy blue
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Dark mode background gradient — cool dark
    static let darkBackgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.07, green: 0.08, blue: 0.11),
            Color(red: 0.09, green: 0.10, blue: 0.14),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Thinking indicator — cycles through the spectrum
    static let thinkingColors: [Color] = [peach, lavender, skyBlue, mint, sage]

    /// Toolbar/nav gradient
    static let toolbarGradient = LinearGradient(
        colors: [lavender.opacity(0.2), mint.opacity(0.15)],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Shadows

    static let bubbleShadowColor = Color.black.opacity(0.06)
    static let bubbleShadowRadius: CGFloat = 12
    static let bubbleShadowY: CGFloat = 4

    static let inputShadowColor = Color.black.opacity(0.05)
    static let inputShadowRadius: CGFloat = 8
    static let inputShadowY: CGFloat = 2

    // MARK: - Corner Radii

    static let bubbleRadius: CGFloat = 22
    static let inputRadius: CGFloat = 24
    static let cardRadius: CGFloat = 16
    static let smallRadius: CGFloat = 12

    // MARK: - Spacing

    static let messagePaddingHorizontal: CGFloat = 16
    static let messagePaddingVertical: CGFloat = 12
    static let messageSpacing: CGFloat = 16

    // MARK: - Typography helpers

    static let assistantFont: Font = .body
    static let userFont: Font = .body
    static let timestampFont: Font = .caption2
    static let tokenFont: Font = .caption2
}

// MARK: - Adaptive Background Modifier

struct AdaptiveBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                Group {
                    if colorScheme == .dark {
                        Theme.darkBackgroundGradient
                    } else {
                        Theme.backgroundGradient
                    }
                }
                .ignoresSafeArea()
            )
    }
}

extension View {
    func adaptiveBackground() -> some View {
        modifier(AdaptiveBackground())
    }
}

// MARK: - Gradient Icon Modifier

struct GradientIcon: ViewModifier {
    let gradient: LinearGradient

    func body(content: Content) -> some View {
        content
            .foregroundStyle(gradient)
    }
}

extension View {
    func gradientIcon(_ gradient: LinearGradient = Theme.accentGradient) -> some View {
        modifier(GradientIcon(gradient: gradient))
    }
}
