import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: AuraTab = .log
    /// Owned here rather than inside the bar so collapse survives a tab switch.
    /// In the prototype each tab rendered its own bar and the state reset with
    /// it; 02-shell-nav calls that out as a prototype artefact to fix.
    @State private var collapsed = false

    var body: some View {
        ZStack {
            Color.aura.bg.ignoresSafeArea()

            // Active tab content fills the screen; the glass bar floats over it
            // (screens leave room via AuraSpacing.tabBarClearance).
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating glass tab bar + FAB. The resume banner is rendered inside
            // LogTabView (mirrors combined/log.jsx), so it only shows on Log.
            VStack {
                Spacer()
                AuraTabBar(selection: $selection, collapsed: collapsed) { action in
                    handleQuickAction(action)
                }
            }
            .ignoresSafeArea(.keyboard)

            // Active workout overlay takes over the whole screen (only while open).
            //
            // Deliberately NOT `.ignoresSafeArea()`: with no edges given that
            // applies to all four, and the overlay's own top bar — "End", the
            // workout title and timer, the minimise button — then drew under
            // the status bar and off the top of the screen, where it could not
            // be tapped. `ActiveWorkoutView` already runs its background to the
            // edges internally, which is the part that actually needs to bleed.
            if appState.workoutOverlayOpen, let session = appState.activeWorkoutSession {
                ActiveWorkoutView()
                    .environmentObject(session)
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        .preferredColorScheme(appState.darkModePreference.colorScheme)
        .animation(.easeInOut(duration: 0.3), value: appState.workoutOverlayOpen)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.workoutInProgress)
        .onReceive(NotificationCenter.default.publisher(for: .auraScroll)) { note in
            guard let dir = note.userInfo?["dir"] as? String else { return }
            // Reacts to DIRECTION, not absolute offset: one notch upward
            // re-expands immediately, however far down the page you are.
            withAnimation(.easeInOut(duration: 0.22)) { collapsed = (dir == "down") }
        }
    }

    // MARK: Tab content switcher
    @ViewBuilder
    private var tabContent: some View {
        switch selection {
        case .log:      LogTabView()
        case .plan:     PlanTabView()
        case .progress: ProgressTabView()
        case .profile:  ProfileTabView()
        }
    }

    /// FAB quick actions route to their *intended* destination regardless of the
    /// active tab. The prototype had each tab supply its own handler and several
    /// of those just fell back to Log; 02-shell-nav is explicit that they are
    /// shortcuts rather than the spec ("build to the intent column").
    private func handleQuickAction(_ action: AuraQuickAction) {
        switch action {
        case .startWorkout:
            // Log's add-workout source sheet. Switch to Log first if we are
            // elsewhere; LogTabView raises the sheet off `requestLogAddSheet`.
            selection = .log
            appState.requestLogAddSheet = true
        case .logMeasurement:
            // Progress → Body → measurement entry.
            appState.progressDeepLink = .measurements
            selection = .progress
        case .progressPhoto:
            // Progress → progress-photo comparison.
            appState.progressDeepLink = .photos
            selection = .progress
        }
    }
}
