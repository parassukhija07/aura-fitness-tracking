import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                LogTabView()
                    .tabItem {
                        Label("Log", systemImage: "calendar")
                    }
                    .tag(0)

                PlanTabView()
                    .tabItem {
                        Label("Plan", systemImage: "dumbbell")
                    }
                    .tag(1)

                ProgressTabView()
                    .tabItem {
                        Label("Progress", systemImage: "chart.bar")
                    }
                    .tag(2)

                ProfileTabView()
                    .tabItem {
                        Label("Profile", systemImage: "person")
                    }
                    .tag(3)
            }
            .accentColor(.aura.accent)
            .preferredColorScheme(appState.darkModePreference.colorScheme)

            // Active workout overlay
            if let session = appState.activeWorkoutSession {
                ActiveWorkoutView()
                    .environmentObject(session)
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.activeWorkoutSession != nil)
    }
}
