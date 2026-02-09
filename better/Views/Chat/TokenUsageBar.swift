import SwiftUI

struct TokenUsageBar: View {
    let inputTokens: Int
    let outputTokens: Int
    let cachedTokens: Int
    let estimatedCost: Double
    let isStreaming: Bool

    @State private var isExpanded = false

    private var totalTokens: Int { inputTokens + outputTokens }

    private var costString: String {
        if estimatedCost < 0.01 {
            return String(format: "$%.4f", estimatedCost)
        }
        return String(format: "$%.2f", estimatedCost)
    }

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                // Streaming pulse indicator
                if isStreaming {
                    Circle()
                        .fill(Theme.mint)
                        .frame(width: 5, height: 5)
                        .opacity(isStreaming ? 1 : 0)
                }

                Image(systemName: "flame")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.peach)

                Text(costString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.charcoal)
                    .contentTransition(.numericText())

                if isExpanded {
                    Text("·")
                        .foregroundStyle(Theme.lavender)

                    Text(formatTokenCount(totalTokens) + " tokens")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.lavender)

                    if cachedTokens > 0 {
                        Text("·")
                            .foregroundStyle(Theme.lavender)
                        
                        Image(systemName: "memorychip")
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.mint)

                        Text(formatTokenCount(cachedTokens))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.mint)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Theme.lavender.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.default, value: isStreaming)
    }

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}
