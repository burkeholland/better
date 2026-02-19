import SwiftUI
import UniformTypeIdentifiers

struct MessageInput: View {
    @Bindable var viewModel: ChatViewModel

    @FocusState private var isFocused: Bool
    @State private var isPhotoPickerPresented = false
    @State private var isFileImporterPresented = false

    private var canSend: Bool {
        (!viewModel.messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.pendingAttachment != nil) && !viewModel.isGenerating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                viewModel.isProMode.toggle()
                Haptics.light()
            }) {
                HStack(spacing: 4) {
                    Group {
                        if viewModel.isProMode {
                            Image(systemName: "brain.head.profile")
                            Text("Thoughtful")
                        } else {
                            Image(systemName: "bolt.fill")
                            Text("Fast")
                        }
                    }
                    .font(.caption.weight(.medium))
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .opacity(0.5)
                }
                .foregroundStyle(viewModel.isProMode ? Theme.cream : Theme.charcoal.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(viewModel.isProMode ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.lavender.opacity(0.15)))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Preview Area
            if let attachment = viewModel.pendingAttachment {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if let preview = attachment.preview {
                            Image(uiImage: preview)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius))
                                .overlay(alignment: .topTrailing) {
                                    removeButton
                                        .offset(x: 10, y: -10)
                                }
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 20))
                                    .gradientIcon()
                                Text(attachment.filename ?? "Document")
                                    .font(.callout)
                                    .foregroundStyle(Theme.charcoal)
                                    .lineLimit(1)
                                    .frame(maxWidth: 150)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Theme.lavender.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.smallRadius)
                                    .stroke(Theme.lavender.opacity(0.3), lineWidth: 1)
                            )
                            .overlay(alignment: .topTrailing) {
                                removeButton
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    isPhotoPickerPresented = true
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                }
                .buttonStyle(PickerButtonStyle())
                .disabled(viewModel.isGenerating)
                .padding(.bottom, 8)
                .accessibilityLabel("Attach Photo")
                .sheet(isPresented: $isPhotoPickerPresented) {
                    PhotoAttachmentPicker { result in
                        switch result {
                        case .success(let picked):
                            viewModel.attachImageData(
                                data: picked.data,
                                mimeTypeHint: picked.mimeTypeHint,
                                filename: nil
                            )
                        case .failure(let error):
                            viewModel.errorMessage = "Could not attach image: \(error.localizedDescription)"
                        }
                    }
                }

                Button {
                    isFileImporterPresented = true
                } label: {
                    Image(systemName: "doc")
                        .font(.system(size: 20))
                }
                .buttonStyle(PickerButtonStyle())
                .disabled(viewModel.isGenerating)
                .padding(.bottom, 8)
                .accessibilityLabel("Attach Document")
                .fileImporter(
                    isPresented: $isFileImporterPresented,
                    allowedContentTypes: [.pdf],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            Task { await viewModel.attachPDF(url: url) }
                        }
                    case .failure(let error):
                        viewModel.errorMessage = error.localizedDescription
                    }
                }

                TextField("Message...", text: $viewModel.messageText)
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
                            send()
                        }
                    }
                    .submitLabel(.send)

                if viewModel.isGenerating {
                    Button(action: { viewModel.stopGenerating() }) {
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
                        send()
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

    private var removeButton: some View {
        Button {
            withAnimation {
                viewModel.removePendingAttachment()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.cream)
                    .frame(width: 24, height: 24)
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.charcoal.opacity(0.6))
            }
        }
        .frame(width: 44, height: 44)
    }

    private func send() {
        let text = viewModel.messageText
        viewModel.messageText = ""
        Task { await viewModel.send(text: text) }
        Haptics.light()
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

private struct PickerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? Theme.mint : Theme.charcoal.opacity(0.6))
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
