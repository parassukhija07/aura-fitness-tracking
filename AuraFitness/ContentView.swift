import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection: AuraTab = .log

    var body: some View {
        ZStack {
            Color.aura.bg.ignoresSafeArea()

            // Active tab content + flat bottom tab bar, matching the design's
            // screens/Log.html shell (plain 4-icon bar, no floating pill / FAB).
            VStack(spacing: 0) {
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                AuraTabBar(selection: $selection)
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
}
