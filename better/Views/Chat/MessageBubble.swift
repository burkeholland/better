import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: Message
    let branchInfo: (current: Int, total: Int)
    let onRegenerate: () -> Void
    let onEdit: (String) -> Void
    let onDelete: () -> Void
    let onBranchSwitch: (Int) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @State private var showThinking = false
    @State private var showStreamingCursor = false

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            if branchInfo.total > 1 {
                BranchNavigator(
                    current: branchInfo.current,
                    total: branchInfo.total,
                    onSwitch: onBranchSwitch
                )
            }

            if isEditing {
                VStack(spacing: 8) {
                    TextEditor(text: $editText)
                        .frame(minHeight: 60, maxHeight: 200)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Button("Cancel") {
                            isEditing = false
                        }
                        Spacer()
                        Button("Send") {
                            onEdit(editText)
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(12)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                HStack {
                    if message.isUser { Spacer(minLength: 60) }

                    VStack(alignment: .leading, spacing: 8) {
                        if let thinking = message.thinkingContent, !thinking.isEmpty {
                            DisclosureGroup("Thinking", isExpanded: $showThinking) {
                                Text(thinking)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        if let imageData = message.imageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        if !message.content.isEmpty {
                            if message.isUser {
                                Text(message.content)
                                    .textSelection(.enabled)
                            } else {
                                MarkdownRenderer(text: message.content)
                            }
                        }

                        if message.isStreaming {
                            Rectangle()
                                .fill(.primary)
                                .frame(width: 2, height: 16)
                                .opacity(showStreamingCursor ? 1.0 : 0.2)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                        showStreamingCursor = true
                                    }
                                }
                                .onChange(of: message.isStreaming) { _, isStreaming in
                                    if isStreaming {
                                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                            showStreamingCursor = true
                                        }
                                    } else {
                                        showStreamingCursor = false
                                    }
                                }
                        }

                        if let input = message.inputTokens, let output = message.outputTokens {
                            Text("\(input) in · \(output) out" + (message.cachedTokens.map { " · \($0) cached" } ?? ""))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(12)
                    .background(message.isUser ? Color.blue : Color(.systemGray6))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if !message.isUser { Spacer(minLength: 60) }
                }
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
                    Label("Edit & Resend", systemImage: "pencil")
                }
            }

            if !message.isUser {
                Button {
                    onRegenerate()
                } label: {
                    Label("Regenerate", systemImage: "arrow.counterclockwise")
                }
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete from here", systemImage: "trash")
            }
        }
        .onAppear {
            if editText.isEmpty {
                editText = message.content
            }
        }
    }
}
