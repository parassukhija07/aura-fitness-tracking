import SwiftUI

@main
struct AuraFitnessApp: App {
    @StateObject private var appState: AppState
    @StateObject private var authService: AuthService
    @StateObject private var syncService: SupabaseSyncService
    @Environment(\.scenePhase) private var scenePhase

    /// Explicit init (instead of relying on `@StateObject`'s implicit
    /// first-access ordering) so `AppStateBridge.shared` is GUARANTEED set
    /// before `AuthService.shared` is touched for the first time anywhere —
    /// otherwise `AuthService.init` -> (previously) `restoreSession()` ->
    /// `onSignedIn` -> `pullAll`/backfill could run against a nil bridge on
    /// cold launch and silently no-op (one-shot backfill would then
    /// permanently miss the local data it should have pushed up).
    init() {
        let state = AppState()
        AppStateBridge.shared = state
        // Must run before AuthService is touched below: `restoreSession` can
        // kick off a pull, and pulling remote plans onto still-random local
        // seed ids is exactly the mismatch this migration exists to remove.
        // Nothing pushes here — there is no session yet — but every rewritten
        // row is stamped as a local change, so the first sign-in reconcile
        // carries the stable ids up.
        SeedIDMigration.runIfNeeded()
        _appState = StateObject(wrappedValue: state)
        _authService = StateObject(wrappedValue: AuthService.shared)
        _syncService = StateObject(wrappedValue: SupabaseSyncService.shared)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch authService.sessionState {
                case .signedIn:
                    ContentView()
                        .environmentObject(appState)
                case .guest:
                    // Guest mode runs the exact same UI as .signedIn — every
                    // store already works with no userID (SupabaseSyncService
                    // push()/pull() no-op locally without one).
                    ContentView()
                        .environmentObject(appState)
                default:
                    AuthGateView()
                        .environmentObject(authService)
                }
            }
            .environmentObject(authService)
            .environmentObject(syncService)
            .task {
                // AppStateBridge.shared is already set (see init() above) by
                // the time this fires, so restoreSession's onSignedIn ->
                // pullAll/backfill can safely read/apply AppState.
                await authService.restoreSession()
            }
            .task(priority: .background) {
                // Over-the-air exercise-library refresh. Independent of
                // `restoreSession` above and deliberately not sequenced after
                // it: the catalog is world-readable, so it works signed out
                // and in guest mode, and it must never delay sign-in. Costs
                // one small GET when the catalog is unchanged, which is the
                // usual case; failure leaves the bundled library in place.
                await ExerciseDatabase.shared.refreshCatalogFromRemote()
            }
            .onOpenURL { url in
                Task { await authService.handleAuthCallback(url: url) }
            }
            .onChange(of: scenePhase) { _, phase in
                // A confirmed email change only lands server-side, so the new
                // address is invisible until the session is re-read. Foreground
                // is the first moment the user can be back from their mailbox.
                guard phase == .active else { return }
                Task { await authService.refreshSession() }
            }
        }
    }
}
