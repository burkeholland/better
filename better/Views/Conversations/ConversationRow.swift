import SwiftUI

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Capsule()
                .fill(Theme.accentGradient)
                .frame(width: 3)

            Image(systemName: "bubble.left.fill")
                .font(.title3)
                .foregroundStyle(Theme.accentGradient)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    if conversation.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(Theme.warmYellow)
                    }
                }

                HStack {
                    Text(conversation.modelName)
                        .font(.caption2)
                        .foregroundStyle(Theme.lavender)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.lavender.opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
