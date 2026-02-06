import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var apiKeyText: String = ""
    @State private var hasAPIKey: Bool = false
    @State private var showSavedAlert: Bool = false
    @FocusState private var isAPIKeyFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if hasAPIKey {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.mint)
                            Text("API Key configured")
                            Spacer()
                            Button("Remove", role: .destructive) {
                                _ = KeychainService.deleteAPIKey()
                                hasAPIKey = false
                            }
                            .font(.caption)
                        }
                    } else {
                        TextField("Paste your Gemini API Key", text: $apiKeyText)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))
                            .focused($isAPIKeyFocused)
                            .onSubmit {
                                saveKey()
                            }

                        Button("Save API Key") {
                            saveKey()
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Theme.sendButtonGradient)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                        .foregroundStyle(.white)
                        .font(.headline)
                        .opacity(apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                        .disabled(apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.accentGradient)
                        Text("API Key")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.accentGradient)
                    }
                } footer: {
                    Text("Get your API key from Google AI Studio (aistudio.google.com)")
                }

                Section {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous)
                                .fill(Theme.accentGradient)
                                .frame(width: 44, height: 44)
                            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Better")
                                .font(.headline)
                                .foregroundStyle(Theme.accentGradient)
                            Text("Springtime chat")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)

                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Build", value: "1")
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(Theme.accentGradient)
                        Text("About")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Theme.accentGradient)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.lavender)
                }
            }
            .alert("API Key Saved", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                hasAPIKey = KeychainService.loadAPIKey() != nil
                if !hasAPIKey {
                    isAPIKeyFocused = true
                }
            }
        }
        .tint(Theme.lavender)
    }
    
    private func saveKey() {
        let trimmed = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if KeychainService.saveAPIKey(trimmed) {
            hasAPIKey = true
            showSavedAlert = true
            apiKeyText = ""
            appState.hasAPIKey = true
            Haptics.success()
            Task { await appState.loadModels() }
        } else {
            Haptics.error()
        }
    }
}
