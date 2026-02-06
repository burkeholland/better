import SwiftUI

struct BranchNavigator: View {
    let current: Int
    let total: Int
    let onSwitch: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                switchBranch(-1)
            } label: {
                chevron("chevron.left", isEnabled: current > 1)
            }
            .disabled(current <= 1)

            Image(systemName: "arrow.triangle.branch")
                .font(.caption2)
                .foregroundStyle(Theme.lavender)

            Text("\(current) / \(total)")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.lavender)

            Button {
                switchBranch(1)
            } label: {
                chevron("chevron.right", isEnabled: current < total)
            }
            .disabled(current >= total)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: [Theme.lavender.opacity(0.18), Theme.lilac.opacity(0.12)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Theme.lavender.opacity(0.3), lineWidth: 1)
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: current)
    }

    private func switchBranch(_ delta: Int) {
        Haptics.selection()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            onSwitch(delta)
        }
    }

    @ViewBuilder
    private func chevron(_ name: String, isEnabled: Bool) -> some View {
        if isEnabled {
            Image(systemName: name)
                .font(.caption2)
                .gradientIcon()
        } else {
            Image(systemName: name)
                .font(.caption2)
                .foregroundStyle(Theme.darkGray.opacity(0.6))
        }
    }
}
