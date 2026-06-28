import SwiftUI

struct LogPastWorkoutSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedDate = Date()
    @State private var workoutName = ""
    @State private var durationMinutes = 60

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Details") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date])
                        .tint(.aura.accent)
                    TextField("Workout Name", text: $workoutName)
                    Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 5...300, step: 5)
                }
                Section {
                    Button("Log Workout") {
                        let log = WorkoutLog(
                            date: selectedDate,
                            workoutName: workoutName.isEmpty ? "Past Workout" : workoutName,
                            exercises: [],
                            durationSeconds: durationMinutes * 60
                        )
                        appState.workoutLogs.append(log)
                        dismiss()
                    }
                    .foregroundColor(.aura.accent)
                }
            }
            .navigationTitle("Log Past Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
