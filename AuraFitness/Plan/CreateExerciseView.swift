import SwiftUI

struct CreateExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @StateObject private var db = ExerciseDatabase.shared

    @State private var name = ""
    @State private var category = "Chest"
    @State private var equipment = "Barbell"
    @State private var difficulty = "Beginner"
    @State private var musclesText = ""   // comma-separated
    @State private var formTip = ""
    @State private var imageURL = ""
    @State private var youtubeURL = ""
    // Seeded from the user's Workout Settings in `.onAppear` (a @State
    // initialiser cannot read the environment); the literals below are the
    // neutral fallback if those defaults are somehow unavailable.
    @State private var repRange = Exercise.fallbackRepRange
    @State private var plannedSets = Exercise.fallbackSets

    let categories = ["Chest","Back","Shoulders","Arms","Legs","Core","Cardio","Warm-up"]
    let equipments = ["Barbell","Dumbbell","Cable","Machine","Bodyweight","Smith Machine"]
    let difficulties = ["Beginner","Intermediate","Advanced"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Exercise Name *", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(equipments, id: \.self) { Text($0) }
                    }
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(difficulties, id: \.self) { Text($0) }
                    }
                }
                Section("Muscles & Programming") {
                    TextField("Muscles targeted (comma separated)", text: $musclesText)
                    TextField("Rep Range (e.g. 8–12)", text: $repRange)
                    Stepper("Default sets: \(plannedSets)", value: $plannedSets, in: 1...10)
                }
                Section("Media & Tips") {
                    TextField("Form tips / coaching cues", text: $formTip, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    TextField("Image URL", text: $imageURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("YouTube URL", text: $youtubeURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Create Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // A brand-new exercise starts from the user's configured
                // defaults; they stay editable here, and existing saved
                // exercises are never retro-fitted.
                repRange = appState.defaultRepRange
                plannedSets = appState.defaultSets
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(.aura.accent)
                }
            }
        }
    }

    private func save() {
        let muscles = musclesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let entry = ExerciseEntry(
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            equipment: equipment,
            musclesTargeted: muscles.isEmpty ? [category] : muscles,
            type: equipment == "Cable" || equipment == "Machine" ? "Machine" : "Compound",
            difficulty: difficulty,
            repRange: repRange.isEmpty ? Exercise.fallbackRepRange : repRange,
            youtubeURL: youtubeURL.trimmingCharacters(in: .whitespaces),
            imageURL: imageURL.trimmingCharacters(in: .whitespaces),
            proTips: formTip.isEmpty ? [] : [formTip],
            warmupProtocol: ExerciseWarmupProtocol(type: "No Warmup Required", steps: []),
            isCable: equipment == "Cable",
            isCustom: true,
            plannedSets: plannedSets,
            hint: formTip
        )
        db.add(entry)
        dismiss()
    }
}
