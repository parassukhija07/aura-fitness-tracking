import SwiftUI

@main
struct AuraFitnessApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    // Seed default data on first launch
                    if appState.userPlans.isEmpty {
                        appState.userPlans.append(SeedData.makeDefaultPlan())
                    }
                }
        }
    }
}
