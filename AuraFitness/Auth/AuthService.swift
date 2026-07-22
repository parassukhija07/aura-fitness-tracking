import Foundation
import Supabase

/// Auth + session single source of truth. Wraps `supabase-swift`'s `auth`
/// client; the SDK persists the session in the Keychain itself (no custom
/// persistence rolled here). Mirrors the singleton shape used by
/// `ProgramDatabase`/`ExerciseDatabase` (`static let shared`, `@MainActor`).
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    enum SessionState: Equatable {
        case loading
        case signedOut
        case awaitingEmailConfirmation(email: String)
        case signedIn(userID: String, email: String)
        case guest
    }

    @Published private(set) var sessionState: SessionState = .loading
    @Published var lastError: String? = nil

    /// True while a password-recovery deep link has established a session that
    /// exists ONLY to authorise the `PUT /auth/v1/user` password update.
    /// `AuthGateView` gates the "Set new password" sheet on this.
    @Published private(set) var isRecoverySession = false

    let client: SupabaseClient

    /// Custom URL scheme Supabase Auth redirects back into. TWO owner-manual
    /// prerequisites — both written up in `MANUAL_STEPS.md`, neither of which
    /// code can do for you:
    ///  1. Supabase Dashboard → Authentication → URL Configuration must
    ///     allow-list the redirect URL. Register `aurafitness://auth-callback`
    ///     **and** `aurafitness://auth-callback**` — the trailing glob matters
    ///     because `passwordResetRedirectURL` below carries a query marker.
    ///  2. The app target must declare the `aurafitness` URL scheme (Xcode →
    ///     target → Info → URL Types). Without it iOS never hands the link to
    ///     `.onOpenURL` and the reset mail dead-ends in Safari. It cannot be
    ///     expressed as an `INFOPLIST_KEY_…` build setting the way
    ///     `AuthConfig`'s values are — `CFBundleURLTypes` is an array of
    ///     dictionaries, so Xcode has to materialise a real Info.plist.
    static let authCallbackScheme = "aurafitness"

    /// Plain callback — used for anything that is not a password reset.
    static let authCallbackURL = URL(string: "aurafitness://auth-callback")!

    /// Reset-specific callback. The `flow=recovery` marker is ours, and it is
    /// what makes recovery detection deterministic: under the PKCE flow (the
    /// supabase-swift default) the redirect carries only `?code=…` with no
    /// hint of what kind of link produced it, whereas the implicit flow puts
    /// `type=recovery` in the fragment. GoTrue preserves query parameters
    /// already present on `redirect_to`, so the marker survives the round trip
    /// under either flow.
    static let passwordResetRedirectURL = URL(string: "aurafitness://auth-callback?flow=recovery")!

    /// Minimum accepted password length. Mirrors the Supabase server minimum
    /// so an obviously-too-short password fails without a round trip.
    static let minimumPasswordLength = 6

    /// Persisted "Skip for now" flag — `true` while the user is browsing
    /// without an account. Cleared on successful sign-in and on `signOut()`.
    private let guestKey = "aura_guest_mode_v1"

    /// Convenience accessor for `SupabaseSyncService` — the current user's id,
    /// or nil while signed out OR in guest mode. Guest mode intentionally
    /// returns nil here so every `SupabaseSyncService.push` early-returns and
    /// stays local-only until the guest signs in.
    var userID: String? {
        if case let .signedIn(userID, _) = sessionState { return userID }
        return nil
    }

    /// The email the CURRENT SESSION authenticates with — i.e. the login
    /// email, which is not the same thing as the (freely editable, local)
    /// `AppState.userProfile.email` contact field.
    var sessionEmail: String? {
        if case let .signedIn(_, email) = sessionState { return email }
        return nil
    }

    private init() {
        client = SupabaseClient(supabaseURL: AuthConfig.supabaseURL, supabaseKey: AuthConfig.supabaseAnonKey)
        // Deliberately does NOT kick off `restoreSession()` here. Restoring a
        // session can synchronously drive `onSignedIn` -> `pullAll`/backfill,
        // which reads/writes AppState via `AppStateBridge.shared` — if that
        // fired from this singleton's lazy `init()` (first touched by
        // `AuraFitnessApp`'s `@StateObject` property, before the bridge is
        // guaranteed set), the one-shot backfill could silently no-op on a
        // nil bridge. `AuraFitnessApp.init()` sets `AppStateBridge.shared`
        // FIRST, then explicitly calls `restoreSession()` — see there.
    }

    /// Attempts to restore a persisted Keychain session on launch. Leaves
    /// `sessionState` at `.loading` until this resolves, so the app never
    /// flashes a login screen for an already-authed user.
    ///
    /// Precedence: a real Keychain session always beats guest mode — only
    /// fall back to `.guest` (on the `catch` branch, i.e. no restorable
    /// session) if the guest flag is set; otherwise `.signedOut`.
    func restoreSession() async {
        do {
            let session = try await client.auth.session
            await transitionToSignedIn(userID: session.user.id.uuidString, email: session.user.email ?? "")
        } catch {
            if UserDefaults.standard.bool(forKey: guestKey) {
                sessionState = .guest
            } else {
                sessionState = .signedOut
            }
        }
    }

    /// "Skip for now" — enters the app without an account. No network call;
    /// simply persists the guest flag and flips the gate. `userID` stays nil
    /// in this state, so every local store already works unauthenticated.
    func continueAsGuest() {
        UserDefaults.standard.set(true, forKey: guestKey)
        sessionState = .guest
    }

    /// Sign-up requires email confirmation (R3) — success lands on
    /// `.awaitingEmailConfirmation`, never `.signedIn`.
    @discardableResult
    func signUp(email: String, password: String) async -> Bool {
        lastError = nil
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            sessionState = .awaitingEmailConfirmation(email: email)
            return true
        } catch {
            lastError = Self.humanize(error)
            return false
        }
    }

    /// Sign-in. An unconfirmed account surfaces a clear message and keeps the
    /// user on `.signedOut` (never silently signs them in half-way).
    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        lastError = nil
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            await transitionToSignedIn(userID: session.user.id.uuidString, email: session.user.email ?? email)
            return true
        } catch {
            let message = Self.humanize(error)
            if message.lowercased().contains("confirm") {
                lastError = "Please confirm your email — check your inbox."
            } else {
                lastError = message
            }
            sessionState = .signedOut
            return false
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            // Even if the network call fails, the SDK clears the local
            // Keychain session — proceed to the signed-out state either way.
        }
        // A signed-out user is neither guest nor signed-in; clear the guest
        // flag so they land back on the login form, not a silent guest session.
        UserDefaults.standard.set(false, forKey: guestKey)
        // Drop the delta-pull watermark so a *different* account signing in on
        // this device starts its incremental sync from epoch, never inheriting
        // the prior user's cursor.
        SupabaseSyncService.shared.resetSyncState()
        // The progress-photo file cache is deliberately NOT dropped here.
        // Sign-out does not clear `appState.progressPhotos`, so the rows stay
        // on screen — and since phase3-01 a migrated row has no inline bytes,
        // deleting its cache file would leave a blank tile that nothing can
        // refill (no session, no download). Byte lifetime tracks row lifetime:
        // the full reset clears both (see DataResetService).
        isRecoverySession = false
        sessionState = .signedOut
    }

    /// Invokes the privileged `delete-account` Edge Function. On success the
    /// caller (ProfileSettingsScreens) performs the local wipe, then this
    /// signs out to flip the gate to login.
    @discardableResult
    func deleteAccount() async -> Bool {
        lastError = nil
        do {
            _ = try await client.functions.invoke("delete-account", options: FunctionInvokeOptions())
            await signOut()
            return true
        } catch {
            lastError = Self.humanize(error)
            return false
        }
    }

    // MARK: - Password reset

    /// Asks Supabase to mail a recovery link (`POST /auth/v1/recover`).
    ///
    /// Deliberately CANNOT distinguish a registered from an unregistered
    /// address: Supabase answers 200 for both to avoid user enumeration, and
    /// the caller must show the same neutral copy for `true` either way. The
    /// only branch worth surfacing is the 429 rate limit.
    @discardableResult
    func requestPasswordReset(email: String) async -> Bool {
        lastError = nil
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            lastError = "Enter your email address."
            return false
        }
        do {
            try await client.auth.resetPasswordForEmail(address, redirectTo: Self.passwordResetRedirectURL)
            return true
        } catch {
            lastError = Self.humanize(error)
            return false
        }
    }

    /// Sets the new password (`PUT /auth/v1/user`). Only legal inside the
    /// recovery session `handleAuthCallback` established — outside one the SDK
    /// has no access token and the call fails.
    ///
    /// On success this runs the NORMAL post-sign-in hook, so a recovery link
    /// opened while a different account was signed in leaves sync pulling for
    /// the uid that actually owns the new session.
    @discardableResult
    func completePasswordReset(newPassword: String) async -> Bool {
        lastError = nil
        guard newPassword.count >= Self.minimumPasswordLength else {
            lastError = "Password is too short (minimum \(Self.minimumPasswordLength) characters)."
            return false
        }
        do {
            let user = try await client.auth.update(user: UserAttributes(password: newPassword))
            isRecoverySession = false
            await transitionToSignedIn(userID: user.id.uuidString, email: user.email ?? "")
            return true
        } catch {
            lastError = Self.humanize(error)
            return false
        }
    }

    /// Backs out of a recovery session without setting a password. Signs out
    /// rather than merely clearing the flag: the recovery session is a live
    /// credential, and leaving it behind would silently hand the app to
    /// whoever opened the link.
    func cancelPasswordReset() async {
        isRecoverySession = false
        await signOut()
    }

    /// Entry point for `.onOpenURL`. Feeds the callback URL to the SDK, which
    /// exchanges it (PKCE code or implicit fragment) for a session.
    ///
    /// Returns whether the result is a RECOVERY session — the flag the
    /// "Set new password" sheet is gated on — not merely whether it succeeded.
    @discardableResult
    func handleAuthCallback(url: URL) async -> Bool {
        guard url.scheme?.lowercased() == Self.authCallbackScheme else { return false }
        lastError = nil
        let recovery = Self.declaresRecovery(url)
        do {
            let session = try await client.auth.session(from: url)
            guard recovery else {
                // Any other callback (email confirmation, confirmed email
                // change) is an ordinary sign-in.
                await transitionToSignedIn(userID: session.user.id.uuidString,
                                           email: session.user.email ?? "")
                return false
            }
            isRecoverySession = true
            // Deliberately NOT `.signedIn`. `AuraFitnessApp` routes `.signedIn`
            // straight to `ContentView`, which would replace the gate hosting
            // the "Set new password" sheet. The session IS live — that is what
            // authorises the password update — the gate simply stays up until
            // `completePasswordReset` performs the real transition.
            sessionState = .signedOut
            return true
        } catch {
            // Expired/reused links land here (`otp_expired`), as does an
            // already-consumed PKCE code.
            lastError = Self.humanize(error)
            isRecoverySession = false
            return false
        }
    }

    // MARK: - Email change

    /// Starts a login-email change (`PUT /auth/v1/user`). Supabase keeps the
    /// address as `new_email` and only swaps it once the user confirms from
    /// their mailbox — by default from BOTH the old and the new address — so
    /// `true` here means "confirmation sent", never "email changed".
    @discardableResult
    func requestEmailChange(to newEmail: String) async -> Bool {
        lastError = nil
        let address = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            lastError = "Enter your email address."
            return false
        }
        do {
            _ = try await client.auth.update(user: UserAttributes(email: address))
            return true
        } catch {
            lastError = Self.humanize(error)
            return false
        }
    }

    /// Re-reads the persisted session and re-publishes its email. This is what
    /// makes a confirmed email change appear in-app: the swap happens
    /// server-side after the user clicks the link, so the value is only
    /// visible once the session is refreshed. Called on foreground.
    func refreshSession() async {
        guard case let .signedIn(currentID, currentEmail) = sessionState else { return }
        guard let session = try? await client.auth.session else { return }
        let id = session.user.id.uuidString
        let email = session.user.email ?? currentEmail
        guard id != currentID || email != currentEmail else { return }
        sessionState = .signedIn(userID: id, email: email)
    }

    /// Is this callback URL a password-recovery return?
    ///
    /// Checks the query AND the fragment, because the marker's location
    /// depends on the flow: PKCE puts everything in the query (which is why
    /// `passwordResetRedirectURL` plants `flow=recovery` there in advance),
    /// while the implicit flow returns `#access_token=…&type=recovery`.
    /// A customised email template can also supply `type=recovery` directly.
    private static func declaresRecovery(_ url: URL) -> Bool {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return false }
        var items = comps.queryItems ?? []
        if let fragment = comps.fragment,
           let fragmentItems = URLComponents(string: "?\(fragment)")?.queryItems {
            items += fragmentItems
        }
        return items.contains { ($0.name == "flow" || $0.name == "type") && $0.value == "recovery" }
    }

    /// Common path for restore + sign-in: flips to `.signedIn` and kicks off
    /// the first-login backfill/pull disambiguation (R4).
    ///
    /// Only reached on a SUCCESSFUL sign-in (restore or `signIn`), so the
    /// guest flag is cleared here — never on a failed attempt, which would
    /// otherwise strand the user with no way back to their guest data.
    private func transitionToSignedIn(userID: String, email: String) async {
        UserDefaults.standard.set(false, forKey: guestKey)
        sessionState = .signedIn(userID: userID, email: email)
        await SupabaseSyncService.shared.onSignedIn(userID: userID)
    }

    /// Maps SDK errors to short, human-readable strings — never surfaces raw
    /// dumps to the UI. Nothing here echoes a password, and no call site logs
    /// one.
    private static func humanize(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("email not confirmed") { return "Please confirm your email — check your inbox." }
        if raw.localizedCaseInsensitiveContains("invalid login credentials") { return "Incorrect email or password." }
        // 429 `over_email_send_rate_limit`. No auto-retry — the user has to
        // wait out the server's 60-second window.
        if raw.localizedCaseInsensitiveContains("once every")
            || raw.localizedCaseInsensitiveContains("rate limit")
            || raw.localizedCaseInsensitiveContains("for security purposes") {
            return "Please wait a minute before requesting another link."
        }
        // 401 `otp_expired` — a reset/confirmation link that is stale or has
        // already been used once.
        if raw.localizedCaseInsensitiveContains("expired")
            || raw.localizedCaseInsensitiveContains("invalid or has expired") {
            return "That link has expired. Request a new one."
        }
        // 422 `email_exists` on an email change; the server phrasing ("has
        // already been registered") differs from the sign-up phrasing below.
        if raw.localizedCaseInsensitiveContains("already been registered") { return "That email is already in use." }
        if raw.localizedCaseInsensitiveContains("already registered") { return "An account with this email already exists." }
        // 422 `weak_password`.
        if raw.localizedCaseInsensitiveContains("password should be at least") {
            return "Password is too short (minimum \(minimumPasswordLength) characters)."
        }
        if raw.localizedCaseInsensitiveContains("password") && raw.localizedCaseInsensitiveContains("short") { return "Password is too short (minimum 6 characters)." }
        if raw.localizedCaseInsensitiveContains("network") { return "No network connection. Please try again." }
        return "Something went wrong. Please try again."
    }
}
