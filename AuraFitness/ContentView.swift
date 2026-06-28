import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    @State private var selection: AuraTab = .log
    @State private var collapsed = false
    @State private var showMeasurementSheet = false

    var body: some View {
        ZStack {
            Color.aura.bg.ignoresSafeArea()

            // Active tab content fills the screen; the glass bar floats over it.
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Floating glass tab bar + FAB
            VStack {
                Spacer()
                AuraTabBar(selection: $selection, collapsed: collapsed) { action in
                    handleQuickAction(action)
                }
            }
            .ignoresSafeArea(.keyboard)

            // Active workout overlay takes over the whole screen.
            if let session = appState.activeWorkoutSession {
                ActiveWorkoutView()
                    .environmentObject(session)
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        .preferredColorScheme(appState.darkModePreference.colorScheme)
        .animation(.easeInOut(duration: 0.3), value: appState.activeWorkoutSession != nil)
        .onReceive(NotificationCenter.default.publisher(for: .auraScroll)) { note in
            if let dir = note.userInfo?["dir"] as? String {
                withAnimation(.easeInOut(duration: 0.22)) { collapsed = (dir == "down") }
            }
        }
        .sheet(isPresented: $showMeasurementSheet) {
            LogMeasurementSheet()
                .environmentObject(appState)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selection {
        case .log:      LogTabView()
        case .plan:     PlanTabView()
        case .progress: ProgressTabView()
        case .profile:  ProfileTabView()
        }
    }

    private func handleQuickAction(_ action: AuraQuickAction) {
        switch action {
        case .startWorkout:
            if let today = appState.todayWorkout() {
                appState.startWorkout(today)
            } else {
                appState.startWorkout(SeedData.emptyWorkout())
            }
        case .logMeasurement:
            selection = .progress
            showMeasurementSheet = true
        case .progressPhoto:
            selection = .progress
        }
    }
}
