import SwiftUI

struct SideMenuView: View {
    var conversationListVM: ConversationListViewModel
    @Binding var isOpen: Bool
    @State private var dragOffset: CGFloat = 0

    let onSelect: (Conversation) -> Void
    let onSettings: () -> Void
    let onChatSettings: () -> Void

    private let maxMenuWidth: CGFloat = 300

    var body: some View {
        GeometryReader { proxy in
            let menuWidth = min(proxy.size.width * 0.8, maxMenuWidth)

            ZStack(alignment: .leading) {
                // Scrim
                if isOpen {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                isOpen = false
                            }
                        }
                        .transition(.opacity)
                }

                // Menu panel
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Better")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.accentGradient)
                            Text("Conversations")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 22)
                        .padding(.bottom, 14)

                        // Conversation list
                        List {
                            if conversationListVM.conversations.isEmpty {
                                emptyState
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                            } else {
                                if !conversationListVM.pinnedConversations.isEmpty {
                                    sectionLabel("PINNED")
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)

                                    ForEach(conversationListVM.pinnedConversations) { conversation in
                                        conversationRow(conversation)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets())
                                            .listRowBackground(Color.clear)
                                    }
                                }

                                if !conversationListVM.recentConversations.isEmpty {
                                    sectionLabel("RECENT")
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets())
                                        .listRowBackground(Color.clear)

                                    ForEach(conversationListVM.recentConversations) { conversation in
                                        conversationRow(conversation)
                                            .listRowSeparator(.hidden)
                                            .listRowInsets(EdgeInsets())
                                            .listRowBackground(Color.clear)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        Divider()
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        footerControls
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                            .padding(.bottom, 12)
                    }
                    .frame(width: menuWidth)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 60)
                    .padding(.bottom, 28)
                    .background(
                        ZStack {
                            Theme.cream
                            Theme.backgroundGradient.opacity(0.35)
                        }
                    )
                    .ignoresSafeArea()

                    Spacer()
                }
                .offset(x: (isOpen ? 0 : -menuWidth - 20) + dragOffset)
                .gesture(dragGesture(menuWidth: menuWidth))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.82), value: isOpen)
            .onChange(of: isOpen) { _, newValue in
                if !newValue { dragOffset = 0 }
            }
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.heavy))
            .foregroundStyle(Theme.darkGray.opacity(0.7))
            .tracking(1.2)
            .padding(.horizontal, 6)
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        Button {
            onSelect(conversation)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                isOpen = false
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    Text(conversation.updatedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if conversation.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.warmYellow)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                togglePinned(conversation)
            } label: {
                Label(conversation.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }

            Button(role: .destructive) {
                deleteConversation(conversation)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        conversationListVM.deleteConversation(conversation)
    }

    private func togglePinned(_ conversation: Conversation) {
        conversationListVM.togglePin(conversation)
        Haptics.light()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.title2)
                .foregroundStyle(Theme.lilac)
            Text("No chats yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.darkGray)
            Text("Start a conversation to see it here.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var footerControls: some View {
        VStack(spacing: 10) {
            Button {
                onChatSettings()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isOpen = false
                }
            } label: {
                footerRow(title: "Model & Parameters", systemImage: "slider.horizontal.3")
            }

            Button {
                onSettings()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isOpen = false
                }
            } label: {
                footerRow(title: "Settings", systemImage: "gearshape")
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.lilac.opacity(0.2), lineWidth: 1)
        )
    }

    private func footerRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .gradientIcon()
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func dragGesture(menuWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard isOpen else { return }
                dragOffset = min(0, value.translation.width)
            }
            .onEnded { value in
                guard isOpen else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    if value.translation.width < -60 {
                        isOpen = false
                    }
                }
                dragOffset = 0
            }
    }
}
