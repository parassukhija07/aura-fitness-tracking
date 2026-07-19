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
        }
        .onChange(of: scenePhase) { _, phase in
            // `authService.userID` is nil for guests, so this already
            // correctly skips the foreground pull in guest mode — guest mode
            // intentionally does not pull (there's nothing remote to fetch;
            // guest data lives purely locally until the user signs in).
            guard phase == .active, authService.userID != nil else { return }
            Task { await SupabaseSyncService.shared.pullAll() }
        }
    }
}
