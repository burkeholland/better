import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var didInitialScroll = false

    private let bottomAnchorId = "bottom-anchor"

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        if viewModel.displayMessages.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 36, weight: .semibold))
                                    .gradientIcon()
                                    .padding(18)
                                    .background(
                                        Circle().fill(Theme.accentGradient.opacity(0.2))
                                    )

                                Text("Start a conversation")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(Theme.charcoal)
                            }
                            .frame(maxWidth: .infinity)
                            .containerRelativeFrame(.vertical)
                        } else {
                            LazyVStack(spacing: Theme.messageSpacing) {
                                ForEach(viewModel.displayMessages) { message in
                                    MessageBubble(
                                        message: message,
                                        isStreaming: viewModel.streamingMessage?.id == message.id,
                                        generationStatus: viewModel.generationStatus,
                                        branchInfo: viewModel.branchInfo(for: message),
                                        isLastInBranch: viewModel.isLastInBranch(message),
                                        onRegenerate: {
                                            Task { await viewModel.regenerate(from: message) }
                                        },
                                        onFork: {
                                            Task { await viewModel.fork(from: message) }
                                        },
                                        onEdit: { newText in
                                            Task { await viewModel.editAndResend(message, newText: newText) }
                                        },
                                        onDeleteSingle: {
                                            viewModel.deleteSingleMessage(message)
                                        },
                                        onDelete: {
                                            viewModel.deleteFromMessage(message)
                                        },
                                        onBranchSwitch: { direction in
                                            viewModel.switchBranch(for: message, direction: direction)
                                        }
                                    )
                                }
                            }
                            .padding()
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(bottomAnchorId)
                    }
                }
                .background(Color.clear)
                .onChange(of: viewModel.scrollToBottomTrigger) { _, _ in
                    scrollToBottom(proxy)
                }
                .onAppear {
                    if !didInitialScroll {
                        didInitialScroll = true
                        scrollToBottom(proxy, animated: false)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if let error = viewModel.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.coral)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.charcoal)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.charcoal)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Theme.lavender.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Theme.inputShadowColor, radius: Theme.inputShadowRadius, x: 0, y: Theme.inputShadowY)
                .padding(.horizontal)
                .padding(.top, 6)
            }

            MessageInput(viewModel: viewModel)
        }
        .adaptiveBackground()
        .navigationTitle(viewModel.conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.conversation.title)
                    .font(.headline)
                    .lineLimit(1)
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        Task { @MainActor in
            if animated {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(bottomAnchorId, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(bottomAnchorId, anchor: .bottom)
            }
        }
    }
}
