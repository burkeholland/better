import SwiftUI

struct MessageInput: View {
    @Binding var text: String
    @Binding var isProMode: Bool
    let isGenerating: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                isProMode.toggle()
                Haptics.light()
            }) {
                HStack(spacing: 4) {
                    Group {
                        if isProMode {
                            Image(systemName: "sparkles")
                            Text("Pro")
                        } else {
                            Image(systemName: "bolt.fill")
                            Text("Flash")
                        }
                    }
                    .font(.caption.weight(.medium))
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .opacity(0.5)
                }
                .foregroundStyle(isProMode ? Theme.cream : Theme.charcoal.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isProMode ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.lavender.opacity(0.15)))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)

            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message...", text: $text)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.inputRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.inputRadius)
                            .stroke(Theme.lavender.opacity(0.2), lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onSubmit {
                        if canSend {
                            onSend()
                            Haptics.light()
                        }
                    }
                    .submitLabel(.send)

                if isGenerating {
                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.cream)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Theme.coral))
                            .shadow(color: Theme.inputShadowColor, radius: Theme.inputShadowRadius, x: 0, y: Theme.inputShadowY)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        onSend()
                        Haptics.light()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.cream)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(SendButtonStyle(isEnabled: canSend))
                    .disabled(!canSend)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Theme.lavender.opacity(0.2))
        }
    }
}

private struct SendButtonStyle: ButtonStyle {
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle().fill(
                    isEnabled
                    ? Theme.sendButtonGradient
                    : LinearGradient(
                        colors: [
                            Theme.charcoal.opacity(0.35),
                            Theme.charcoal.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
            .shadow(color: Theme.inputShadowColor, radius: Theme.inputShadowRadius, x: 0, y: Theme.inputShadowY)
            .opacity(isEnabled ? 1.0 : 0.6)
    }
}
