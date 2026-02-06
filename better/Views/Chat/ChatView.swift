import SwiftUI
import SwiftData

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(AppState.self) private var appState
    @State private var showChatSettings = false
    @State private var messageText = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.displayMessages) { message in
                        MessageBubble(
                            message: message,
                            branchInfo: viewModel.branchInfo(for: message),
                            onRegenerate: {
                                Task { await viewModel.regenerate(from: message) }
                            },
                            onEdit: { newText in
                                Task { await viewModel.editAndResend(message, newText: newText) }
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
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)

            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        viewModel.errorMessage = nil
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }

            Divider()

            MessageInput(
                text: $messageText,
                isGenerating: viewModel.isGenerating,
                onSend: {
                    let text = messageText
                    messageText = ""
                    Task { await viewModel.send(text: text) }
                },
                onStop: {
                    viewModel.stopGenerating()
                }
            )
        }
        .navigationTitle(viewModel.conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    Button {
                        showChatSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    
                    Button {
                        appState.showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showChatSettings) {
            NavigationStack {
                ParameterControlsView(conversation: viewModel.conversation)
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
}
