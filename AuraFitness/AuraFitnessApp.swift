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
            guard phase == .active, authService.userID != nil else { return }
            Task { await SupabaseSyncService.shared.pullAll() }
        }
    }
}
