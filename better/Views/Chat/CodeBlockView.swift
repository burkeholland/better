import SwiftUI
import UIKit

struct CodeBlockView: View {
    let code: String
    let language: String?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            codeArea
        }
        .background(Theme.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.lavender.opacity(0.2), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Text(language ?? "code")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.lavender)
            Spacer()
            Button {
                handleCopy()
            } label: {
                Group {
                    if copied {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Theme.mint)
                    } else {
                        Image(systemName: "doc.on.doc")
                            .gradientIcon()
                    }
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.charcoal)
        .animation(.easeInOut(duration: 0.2), value: copied)
    }

    private var codeArea: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Theme.lilac.opacity(0.9))
                .padding(12)
        }
        .background(Theme.darkGray)
        .overlay(alignment: .top) {
            Theme.accentGradient
                .frame(height: 2)
                .opacity(0.9)
        }
    }

    private func handleCopy() {
        UIPasteboard.general.string = code
        Haptics.light()
        withAnimation(.easeInOut(duration: 0.2)) {
            copied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                copied = false
            }
        }
    }
}
