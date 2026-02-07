import SwiftUI

struct LoginView: View {
    @Environment(AuthService.self) private var authService
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            Theme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App branding
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Theme.accentGradient.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(Theme.accentGradient)
                    }

                    Text("Better")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accentGradient)

                    Text("Your AI chat companion")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Sign in button
                VStack(spacing: 16) {
                    Button {
                        signIn()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.title2)

                            Text("Sign in with Google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.white)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.inputRadius, style: .continuous))
                        .shadow(color: Theme.bubbleShadowColor, radius: Theme.bubbleShadowRadius, x: 0, y: Theme.bubbleShadowY)
                    }
                    .disabled(isSigningIn)
                    .opacity(isSigningIn ? 0.6 : 1.0)

                    if isSigningIn {
                        ProgressView()
                            .tint(Theme.mint)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    private func signIn() {
        isSigningIn = true
        Task {
            do {
                try await authService.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSigningIn = false
        }
    }
}
