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
    }

    @Published private(set) var sessionState: SessionState = .loading
    @Published var lastError: String? = nil

    let client: SupabaseClient

    /// Convenience accessor for `SupabaseSyncService` — the current user's id,
    /// or nil while signed out.
    var userID: String? {
        if case let .signedIn(userID, _) = sessionState { return userID }
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
    func restoreSession() async {
        do {
            let session = try await client.auth.session
            await transitionToSignedIn(userID: session.user.id.uuidString, email: session.user.email ?? "")
        } catch {
            sessionState = .signedOut
        }
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

    /// Common path for restore + sign-in: flips to `.signedIn` and kicks off
    /// the first-login backfill/pull disambiguation (R4).
    private func transitionToSignedIn(userID: String, email: String) async {
        sessionState = .signedIn(userID: userID, email: email)
        await SupabaseSyncService.shared.onSignedIn(userID: userID)
    }

    /// Maps SDK errors to short, human-readable strings — never surfaces raw
    /// dumps to the UI.
    private static func humanize(_ error: Error) -> String {
        let raw = error.localizedDescription
        if raw.localizedCaseInsensitiveContains("email not confirmed") { return "Please confirm your email — check your inbox." }
        if raw.localizedCaseInsensitiveContains("invalid login credentials") { return "Incorrect email or password." }
        if raw.localizedCaseInsensitiveContains("already registered") { return "An account with this email already exists." }
        if raw.localizedCaseInsensitiveContains("password") && raw.localizedCaseInsensitiveContains("short") { return "Password is too short (minimum 6 characters)." }
        if raw.localizedCaseInsensitiveContains("network") { return "No network connection. Please try again." }
        return "Something went wrong. Please try again."
    }
}
