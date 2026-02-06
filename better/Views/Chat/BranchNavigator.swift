import SwiftUI

struct BranchNavigator: View {
    let current: Int
    let total: Int
    let onSwitch: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onSwitch(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption2)
            }
            .disabled(current <= 1)

            Text("\(current) / \(total)")
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button {
                onSwitch(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .disabled(current >= total)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
    }
}
