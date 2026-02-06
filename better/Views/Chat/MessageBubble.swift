import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: Message
    let branchInfo: (current: Int, total: Int)
    let onRegenerate: () -> Void
    let onEdit: (String) -> Void
    let onDeleteSingle: () -> Void
    let onDelete: () -> Void
    let onBranchSwitch: (Int) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @State private var showStreamingCursor = false
    @State private var didAppear = false
    @State private var showImageViewer = false

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
            if branchInfo.total > 1 {
                BranchNavigator(
                    current: branchInfo.current,
                    total: branchInfo.total,
                    onSwitch: onBranchSwitch
                )
            }

            if isEditing {
                editView
            } else {
                messageRow
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.content
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if message.isUser {
                Button {
                    editText = message.content
                    isEditing = true
                } label: {
                    Label("Edit & Resend", systemImage: "square.and.pencil")
                }
            }

            if !message.isUser {
                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            Button(role: .destructive) {
                onDeleteSingle()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete from here", systemImage: "trash.slash")
            }
        }
        .onAppear {
            if editText.isEmpty {
                editText = message.content
            }
            if !didAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    didAppear = true
                }
            }
            if message.isStreaming {
                startStreamingAnimation()
            }
        }
        .onChange(of: message.isStreaming) { _, isStreaming in
            if isStreaming {
                startStreamingAnimation()
            } else {
                showStreamingCursor = false
            }
        }
    }
}

private extension MessageBubble {
    var messageRow: some View {
        Group {
            if message.isUser {
                userMessage
            } else {
                assistantMessage
            }
        }
        .scaleEffect(didAppear ? 1.0 : 0.95)
        .opacity(didAppear ? 1.0 : 0.0)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    var userMessage: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 40)

            messageContent
                .padding(.horizontal, Theme.messagePaddingHorizontal)
                .padding(.vertical, Theme.messagePaddingVertical)
                .background(Theme.lavender.opacity(0.15))
                .foregroundStyle(Theme.charcoal)
                .clipShape(RoundedRectangle(cornerRadius: Theme.bubbleRadius, style: .continuous))
                .frame(maxWidth: userBubbleMaxWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, Theme.messagePaddingHorizontal)
    }

    var assistantMessage: some View {
        VStack(alignment: .leading, spacing: 8) {
            messageContent
                .foregroundStyle(Theme.charcoal)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.messagePaddingHorizontal)
        .padding(.vertical, 4)
    }

    var messageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if message.isStreaming && message.content.isEmpty {
                ThinkingView()
            }

            if let imageData = message.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onTapGesture {
                        showImageViewer = true
                    }
                    .fullScreenCover(isPresented: $showImageViewer) {
                        ImageViewer(image: uiImage)
                    }
            }

            if !message.content.isEmpty {
                if message.isUser {
                    Text(message.content)
                        .textSelection(.enabled)
                } else {
                    MarkdownRenderer(text: message.content)
                }
            }

            if message.isStreaming && !message.content.isEmpty {
                streamingCursor
            }

            if let input = message.inputTokens, let output = message.outputTokens {
                tokenCounts(input: input, output: output, cached: message.cachedTokens)
            }
        }
    }

    var streamingCursor: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Theme.accentGradient)
            .frame(width: 3, height: 18)
            .opacity(showStreamingCursor ? 1.0 : 0.25)
            .scaleEffect(x: 1.0, y: showStreamingCursor ? 1.0 : 0.7, anchor: .center)
            .padding(.top, 2)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: showStreamingCursor)
    }

    func tokenCounts(input: Int, output: Int, cached: Int?) -> some View {
        let cachedText = cached.map { " · \($0) cached" } ?? ""
        return HStack(spacing: 6) {
            HStack(spacing: 4) {
                Circle().fill(Theme.mint).frame(width: 6, height: 6)
                Circle().fill(Theme.lavender).frame(width: 6, height: 6)
                Circle().fill(Theme.peach).frame(width: 6, height: 6)
            }

            Text("\(input) in · \(output) out\(cachedText)")
                .font(.caption2)
                .foregroundStyle(Theme.charcoal.opacity(0.6))
        }
    }

    var editView: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $editText)
                .frame(minHeight: 80, maxHeight: 220)
                .padding(10)
                .background(Theme.cream)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Theme.lilac.opacity(0.5), lineWidth: 1)
                )

            HStack {
                Button("Cancel") {
                    isEditing = false
                }
                .foregroundStyle(Theme.charcoal)

                Spacer()

                Button {
                    onEdit(editText)
                    isEditing = false
                } label: {
                    Text("Send")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .foregroundStyle(.white)
                        .background(Theme.mint)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Theme.cream.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    var userBubbleMaxWidth: CGFloat {
        UIScreen.main.bounds.width * 0.8
    }

    func startStreamingAnimation() {
        showStreamingCursor = true
    }
}
