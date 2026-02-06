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
                                .foregroundStyle(.green)
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
                        .disabled(apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Get your API key from Google AI Studio (aistudio.google.com)")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Build", value: "1")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
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
