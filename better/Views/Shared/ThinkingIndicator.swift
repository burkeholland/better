import SwiftUI

struct ThinkingIndicator: View {
    @State private var phase: CGFloat = 0

    private let dotCount = 3
    private let dotSize: CGFloat = 8
    private let spacing: CGFloat = 6

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(dotGradient(for: index))
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(scale(for: index))
                    .opacity(opacity(for: index))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.4)
                .repeatForever(autoreverses: true)
            ) {
                phase = 1
            }
        }
    }

    private func dotGradient(for index: Int) -> some ShapeStyle {
        let colors = Theme.thinkingColors
        let colorIndex = index % colors.count
        let nextIndex = (index + 1) % colors.count
        return LinearGradient(
            colors: [colors[colorIndex], colors[nextIndex]],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func scale(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.2
        let adjustedPhase = max(0, min(1, (phase * 1.4) - delay))
        return 0.5 + (adjustedPhase * 0.7)
    }

    private func opacity(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.2
        let adjustedPhase = max(0, min(1, (phase * 1.4) - delay))
        return 0.4 + (adjustedPhase * 0.6)
    }
}

/// A more elaborate thinking animation with a text label
struct ThinkingView: View {
    var label: String = "Thinking"
    @State private var isAnimating = false
    @State private var textOpacity: Double = 0.4

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Animated bloom icon
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accentGradient)
                .scaleEffect(isAnimating ? 1.15 : 0.85)
                .opacity(isAnimating ? 1.0 : 0.5)

            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .opacity(textOpacity)

            ThinkingIndicator()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.6)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
                textOpacity = 0.8
            }
        }
    }

    private var iconName: String {
        if label.contains("image") {
            return "photo"
        } else if label.contains("video") {
            return "film"
        } else {
            return "sparkle"
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        ThinkingIndicator()
        ThinkingView()
    }
    .padding()
}
