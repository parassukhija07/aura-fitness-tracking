import SwiftUI

struct WorkoutSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section("Display") {
                Toggle("Show Reps First", isOn: $appState.showRepsFirst)
                Toggle("Show PRs During Workout", isOn: $appState.showPRsDuringWorkout)
            }
            Section("Defaults") {
                Stepper("Default Sets: \(appState.defaultSets)", value: $appState.defaultSets, in: 1...10)
                HStack {
                    Text("Rep Range")
                    Spacer()
                    TextField("6–10", text: $appState.defaultRepRange)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.aura.accent)
                }
                Stepper("Rest Between Sets: \(appState.defaultRestBetweenSets)s",
                        value: $appState.defaultRestBetweenSets, in: 15...300, step: 15)
                Stepper("Rest Between Exercises: \(appState.defaultRestBetweenExercises)s",
                        value: $appState.defaultRestBetweenExercises, in: 30...600, step: 15)
            }
            Section("Automation") {
                Toggle("Auto Rest Timer", isOn: $appState.autoRestTimer)
                Toggle("Auto-Play Video", isOn: $appState.autoPlayVideo)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Workout Settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.aura.accent)
    }
}
