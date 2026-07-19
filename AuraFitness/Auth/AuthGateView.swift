import SwiftUI

/// Pre-auth root. Shown by `AuraFitnessApp` while `AuthService.sessionState`
/// is not `.signedIn`. Splash while `.loading` (never a login flash for an
/// already-authed user), login/sign-up form while `.signedOut`, and a
/// "confirm your email" screen while `.awaitingEmailConfirmation`.
struct AuthGateView: View {
    @EnvironmentObject var authService: AuthService

    var body: some View {
        Group {
            switch authService.sessionState {
            case .loading:
                splash
            case .signedOut:
                AuthFormView()
            case .awaitingEmailConfirmation(let email):
                AwaitingConfirmationView(email: email)
            case .signedIn:
                // AuraFitnessApp gates ContentView on .signedIn directly; this
                // branch is effectively unreachable but kept exhaustive.
                splash
            case .guest:
                // AuraFitnessApp gates ContentView on .guest directly too;
                // this branch is effectively unreachable but kept exhaustive.
                splash
            }
        }
        .background(Color.aura.bg.ignoresSafeArea())
    }

    private var splash: some View {
        VStack(spacing: AuraSpacing.s3) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(.aura.accent)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Login / Sign-up form

private struct AuthFormView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var toast = ToastCenter()

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false

    private enum Mode { case login, signUp }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                Spacer(minLength: AuraSpacing.s6)

                VStack(spacing: AuraSpacing.s2) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.aura.accent)
                    Text("Aura Fitness")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.aura.text)
                    Text(mode == .login ? "Log in to sync your workouts" : "Create an account to get started")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                .padding(.bottom, AuraSpacing.s3)

                VStack(spacing: AuraSpacing.s3) {
                    field("Email", text: $email, keyboard: .emailAddress)
                    secureField("Password", text: $password)
                }

                AuraPrimaryButton(label: mode == .login ? "Log In" : "Sign Up", isLoading: busy) {
                    submit()
                }
                .disabled(busy || email.isEmpty || password.isEmpty)
                .opacity(busy || email.isEmpty || password.isEmpty ? 0.6 : 1)

                Button {
                    mode = (mode == .login) ? .signUp : .login
                    authService.lastError = nil
                } label: {
                    Text(mode == .login ? "Don't have an account? Sign up" : "Already have an account? Log in")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.accent)
                }
                .padding(.top, AuraSpacing.s2)

                Button {
                    authService.continueAsGuest()
                } label: {
                    Text("Skip for now — use as guest")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                .padding(.top, AuraSpacing.s2)

                Spacer(minLength: AuraSpacing.s6)
            }
            .padding(.horizontal, AuraSpacing.s5)
        }
        .auraToast(toast)
        .onChange(of: authService.lastError) { _, err in
            if let err { toast.flash(err) }
        }
    }

    private func submit() {
        busy = true
        Task {
            let ok: Bool
            switch mode {
            case .login:  ok = await authService.signIn(email: email, password: password)
            case .signUp: ok = await authService.signUp(email: email, password: password)
            }
            busy = false
            if !ok, let err = authService.lastError { toast.flash(err) }
        }
    }

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        TextField(label, text: text)
            .font(AuraFont.body())
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, AuraSpacing.s3)
            .frame(height: 48)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        SecureField(label, text: text)
            .font(AuraFont.body())
            .padding(.horizontal, AuraSpacing.s3)
            .frame(height: 48)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
    }
}

// MARK: - Awaiting email confirmation

private struct AwaitingConfirmationView: View {
    let email: String
    @EnvironmentObject var authService: AuthService
    @StateObject private var toast = ToastCenter()
    @State private var busy = false

    var body: some View {
        VStack(spacing: AuraSpacing.s4) {
            Spacer()
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.aura.accent)
            Text("Check your email")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.aura.text)
            Text("We sent a confirmation link to \(email). Confirm your account, then log in below.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            AuraGrayButton(label: "Back to Login") {
                // Returning to .signedOut lets the user log in once confirmed.
                Task { await authService.signOut() }
            }
            .padding(.top, AuraSpacing.s3)
            .disabled(busy)

            Spacer()
        }
        .padding(.horizontal, AuraSpacing.s5)
        .auraToast(toast)
    }
}
