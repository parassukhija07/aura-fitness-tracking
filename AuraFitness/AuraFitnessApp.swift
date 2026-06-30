import SwiftUI

@main
struct AuraFitnessApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Sync AppState.userPlans from UserPlanDatabase on launch
                    // UserPlanDatabase.load() already seeded from first program if empty
                    if appState.userPlans.isEmpty {
                        appState.userPlans = UserPlanDatabase.shared.plans
                    }
                }
        }
    }
}
