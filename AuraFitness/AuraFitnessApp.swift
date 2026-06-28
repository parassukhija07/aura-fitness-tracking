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
                    // Seed a few recent "missed" days so the Log tab shows that state
                    // (mirrors combined/log.jsx SEED_MISSED, relative to today).
                    if appState.seededMissed.isEmpty {
                        let cal = Calendar.current
                        let today = cal.startOfDay(for: Date())
                        for back in [5, 11, 17] {
                            if let d = cal.date(byAdding: .day, value: -back, to: today) {
                                appState.seededMissed.insert(AppState.iso(d))
                            }
                        }
                    }
                }
        }
    }
}
