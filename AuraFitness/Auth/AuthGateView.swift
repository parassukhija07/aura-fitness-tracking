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
        // Hosted at the gate root rather than inside `AuthFormView` because a
        // recovery link can arrive in any pre-auth state (splash, sign-up
        // form, "check your email"), and `handleAuthCallback` parks the
        // session on `.signedOut` precisely so this stays reachable.
        .sheet(isPresented: recoverySheetPresented) {
            SetNewPasswordSheet()
                .environmentObject(authService)
        }
    }

    /// `isRecoverySession` is `private(set)`, so the sheet drives it through
    /// an explicit binding. The setter only cancels when the session is STILL
    /// in recovery — on success `completePasswordReset` has already cleared
    /// the flag and signed the user in, and cancelling there would sign them
    /// straight back out.
    private var recoverySheetPresented: Binding<Bool> {
        Binding(
            get: { authService.isRecoverySession },
            set: { presented in
                guard !presented, authService.isRecoverySession else { return }
                Task { await authService.cancelPasswordReset() }
            }
        )
    }

    private var splash: some View {
        VStack(spacing: AuraSpacing.s3) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(AuraFont.jakarta(44, .bold))
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
    @State private var showForgotPassword = false

    private enum Mode { case login, signUp }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                Spacer(minLength: AuraSpacing.s6)

                VStack(spacing: AuraSpacing.s2) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(AuraFont.jakarta(40, .bold))
                        .foregroundColor(.aura.accent)
                    Text("Aura Fitness")
                        .font(AuraFont.jakarta(24, .heavy))
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

                if mode == .login {
                    Button {
                        authService.lastError = nil
                        showForgotPassword = true
                    } label: {
                        Text("Forgot password?")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.accent)
                    }
                }

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
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(initialEmail: email)
                .environmentObject(authService)
        }
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

// MARK: - Forgot password (request a reset link)

private struct ForgotPasswordSheet: View {
    /// Prefill from whatever the user already typed on the login form.
    let initialEmail: String

    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var toast = ToastCenter()

    @State private var email = ""
    @State private var busy = false
    @State private var sent = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: AuraSpacing.s3) {
                if sent { confirmation } else { form }
            }
            .padding(.horizontal, AuraSpacing.s4)
            .padding(.bottom, AuraSpacing.s5)
        }
        .presentationDetents([.height(sent ? 300 : 330)])
        .presentationDragIndicator(.visible)
        .background(Color.aura.surface)
        .auraToast(toast)
        .onAppear { if email.isEmpty { email = initialEmail } }
    }

    private var form: some View {
        VStack(spacing: AuraSpacing.s3) {
            Text("Reset your password")
                .font(AuraFont.jakarta(20, .bold))
                .foregroundColor(.aura.text)
            Text("Enter the email you signed up with and we'll send you a link to set a new password.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)

            TextField("Email", text: $email)
                .font(AuraFont.body())
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, AuraSpacing.s3)
                .frame(height: 48)
                .background(Color.aura.fill)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))

            AuraPrimaryButton(label: "Send reset link", isLoading: busy) { send() }
                .disabled(busy || email.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(busy || email.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1)

            AuraGrayButton(label: "Cancel") { dismiss() }
                .disabled(busy)
        }
    }

    private var confirmation: some View {
        VStack(spacing: AuraSpacing.s3) {
            Image(systemName: "envelope.badge.fill")
                .font(AuraFont.jakarta(40, .semibold))
                .foregroundColor(.aura.accent)
            Text("Check your email")
                .font(AuraFont.jakarta(20, .bold))
                .foregroundColor(.aura.text)
            // Deliberately says nothing about whether the address is
            // registered — Supabase answers 200 either way to prevent user
            // enumeration, and this copy must not leak what the API won't.
            Text("If an account exists for that email, a reset link is on its way.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
            AuraPrimaryButton(label: "Done") { dismiss() }
        }
    }

    private func send() {
        busy = true
        Task {
            let ok = await authService.requestPasswordReset(email: email)
            busy = false
            // Only a hard failure (rate limit, no network) stays on the form.
            // A success is shown identically for known and unknown addresses.
            if ok { sent = true } else if let err = authService.lastError { toast.flash(err) }
        }
    }
}

// MARK: - Set new password (inside a recovery session)

private struct SetNewPasswordSheet: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var toast = ToastCenter()

    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var busy = false

    private var tooShort: Bool { password.count < AuthService.minimumPasswordLength }
    private var mismatched: Bool { password != confirmPassword }
    private var canSubmit: Bool { !busy && !tooShort && !mismatched }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: AuraSpacing.s3) {
                Text("Set a new password")
                    .font(AuraFont.jakarta(20, .bold))
                    .foregroundColor(.aura.text)
                Text("Choose a new password for your account. It needs at least \(AuthService.minimumPasswordLength) characters.")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
                    .multilineTextAlignment(.center)

                secureField("New password", text: $password)
                secureField("Confirm new password", text: $confirmPassword)

                if !confirmPassword.isEmpty && mismatched {
                    Text("Passwords don't match.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.red)
                }

                AuraPrimaryButton(label: "Save password", isLoading: busy) { submit() }
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.6)

                // Cancelling signs the recovery session out — it is a live
                // credential, not just a UI state.
                AuraGrayButton(label: "Cancel") {
                    Task { await authService.cancelPasswordReset() }
                }
                .disabled(busy)
            }
            .padding(.horizontal, AuraSpacing.s4)
            .padding(.bottom, AuraSpacing.s5)
        }
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
        .background(Color.aura.surface)
        // No swipe-away mid-request: the update is in flight against a
        // one-shot recovery session.
        .interactiveDismissDisabled(busy)
        .auraToast(toast)
    }

    private func submit() {
        busy = true
        Task {
            let ok = await authService.completePasswordReset(newPassword: password)
            busy = false
            // On success `completePasswordReset` clears `isRecoverySession`
            // and signs in, which tears this sheet down — nothing to do here.
            if !ok, let err = authService.lastError { toast.flash(err) }
        }
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
                .font(AuraFont.jakarta(44, .semibold))
                .foregroundColor(.aura.accent)
            Text("Check your email")
                .font(AuraFont.jakarta(20, .bold))
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
