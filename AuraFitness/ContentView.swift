import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: AuraTab = .log
    @State private var collapsed = false

    var body: some View {
        ZStack {
            Color.aura.bg.ignoresSafeArea()

            // Active tab content fills the screen; the glass bar floats over it.
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
            if appState.workoutOverlayOpen, let session = appState.activeWorkoutSession {
                ActiveWorkoutView()
                    .environmentObject(session)
                    .ignoresSafeArea()
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        .preferredColorScheme(appState.darkModePreference.colorScheme)
        .animation(.easeInOut(duration: 0.3), value: appState.workoutOverlayOpen)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: appState.workoutInProgress)
        .onReceive(NotificationCenter.default.publisher(for: .auraScroll)) { note in
            if let dir = note.userInfo?["dir"] as? String {
                withAnimation(.easeInOut(duration: 0.22)) { collapsed = (dir == "down") }
            }
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
    /// active tab (per 02-shell-nav "Build to the intent column").
    private func handleQuickAction(_ action: AuraQuickAction) {
        switch action {
        case .startWorkout:
            // Open the Log add-workout source sheet (03-log §misc). Route to Log
            // first if we're elsewhere; LogTabView raises the sheet on appear.
            selection = .log
            appState.requestLogAddSheet = true
        case .logMeasurement:
            // Progress → Body → log-measurement entry.
            appState.progressDeepLink = .measurements
            selection = .progress
        case .progressPhoto:
            // Progress → progress-photo comparison.
            appState.progressDeepLink = .photos
            selection = .progress
        }
    }
}
