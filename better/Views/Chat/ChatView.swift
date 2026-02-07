import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @Binding var showChatSettings: Bool
    @State private var isNearBottom = true
    @State private var scrollViewHeight: CGFloat = 0
    @State private var bottomAnchorY: CGFloat = 0
    @State private var shouldForceScroll = false
    @State private var didInitialScroll = false

    private let bottomAnchorId = "bottom-anchor"
    private let scrollSpaceName = "chat-scroll"
    private let autoScrollThreshold: CGFloat = 120

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

                                Text("Ask anything and let springtime ideas bloom.")
                                    .font(.callout)
                                    .foregroundStyle(Theme.charcoal.opacity(0.6))
                            }
                            .frame(maxWidth: .infinity)
                            .containerRelativeFrame(.vertical)
                        } else {
                            LazyVStack(spacing: Theme.messageSpacing) {
                                ForEach(viewModel.displayMessages) { message in
                                    MessageBubble(
                                        message: message,
                                        isStreaming: viewModel.streamingMessage?.id == message.id,
                                        branchInfo: viewModel.branchInfo(for: message),
                                        onRegenerate: {
                                            Task { await viewModel.regenerate(from: message) }
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
                            .background(
                                GeometryReader { anchorProxy in
                                    Color.clear.preference(
                                        key: BottomAnchorPreferenceKey.self,
                                        value: anchorProxy.frame(in: .named(scrollSpaceName)).minY
                                    )
                                }
                            )
                    }
                }
                .background(Color.clear)
                .coordinateSpace(name: scrollSpaceName)
                .background(
                    GeometryReader { scrollProxy in
                        Color.clear
                            .onAppear {
                                scrollViewHeight = scrollProxy.size.height
                            }
                            .onChange(of: scrollProxy.size.height) { _, newValue in
                                scrollViewHeight = newValue
                            }
                    }
                )
                .onPreferenceChange(BottomAnchorPreferenceKey.self) { newValue in
                    bottomAnchorY = newValue
                    updateIsNearBottom()
                }
                .onChange(of: viewModel.displayMessages.count) { _, _ in
                    let shouldAutoScroll = shouldForceScroll || viewModel.isGenerating || isNearBottom
                    if shouldAutoScroll {
                        scrollToBottom(proxy)
                    }
                    shouldForceScroll = false
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
        .sheet(isPresented: $showChatSettings, onDismiss: {
            Task { await viewModel.persistConversation() }
        }) {
            NavigationStack {
                ParameterControlsView(conversation: $viewModel.conversation)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showChatSettings = false
                            }
                        }
                    }
            }
        }
    }

    private func updateIsNearBottom() {
        guard scrollViewHeight > 0 else { return }
        let distanceFromBottom = bottomAnchorY - scrollViewHeight
        isNearBottom = distanceFromBottom <= autoScrollThreshold
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

private struct BottomAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
