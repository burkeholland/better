import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthService.self) private var authService
    @State private var customInstructions: String = ""
    @State private var isSaving: Bool = false
    @State private var showSavedAlert: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Account
                Section {
                    if authService.isSignedIn, let user = authService.currentUser {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.accentGradient)
                                    .frame(width: 40, height: 40)
                                Text(String(user.displayName?.prefix(1) ?? "?"))
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName ?? "User")
                                    .font(.subheadline.weight(.semibold))
                                if let email = user.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)

                        Button(role: .destructive) {
                            try? authService.signOut()
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                Text("Sign Out")
                            }
                        }
                    }
                } header: {
                    sectionHeader(icon: "person.circle", title: "Account")
                }

                // MARK: - Custom Instructions
                Section {
                    TextEditor(text: $customInstructions)
                        .frame(minHeight: 120)
                        .font(.body)

                    Button {
                        Task { await saveCustomInstructions() }
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .background(Theme.sendButtonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous))
                    .foregroundStyle(.white)
                    .font(.headline)
                    .disabled(isSaving)
                } header: {
                    sectionHeader(icon: "text.quote", title: "Custom Instructions")
                } footer: {
                    Text("Tell the AI how to behave. These instructions apply to all conversations.")
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
            .alert("Saved", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) { }
            }
            .onAppear {
                Task { await loadCustomInstructions() }
            }
        }
        .tint(Theme.lavender)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Theme.accentGradient)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.accentGradient)
        }
    }

    private func loadCustomInstructions() async {
        guard let uid = authService.userId else { return }
        let docRef = Firestore.firestore()
            .collection(Constants.Firestore.usersCollection)
            .document(uid)
        do {
            let snapshot = try await docRef.getDocument()
            if let value = snapshot.data()?["customInstructions"] as? String {
                customInstructions = value
            }
        } catch {
            // First launch — document may not exist yet
        }
    }

    private func saveCustomInstructions() async {
        guard let uid = authService.userId else { return }
        isSaving = true
        let docRef = Firestore.firestore()
            .collection(Constants.Firestore.usersCollection)
            .document(uid)
        do {
            try await docRef.setData(["customInstructions": customInstructions], merge: true)
            showSavedAlert = true
            Haptics.success()
        } catch {
            Haptics.error()
        }
        isSaving = false
    }
}
