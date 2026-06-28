import SwiftUI

struct CreateExerciseView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var category = "Chest"
    @State private var equipment = "Barbell"
    @State private var difficulty = "Beginner"
    @State private var primaryMuscle = "Chest"
    @State private var formTip = ""
    @State private var imageURL = ""
    @State private var youtubeURL = ""

    let categories = ["Chest","Back","Shoulders","Arms","Legs","Core","Cardio"]
    let equipments = ["Barbell","Dumbbell","Cable","Machine","Bodyweight","Smith Machine"]
    let difficulties = ["Beginner","Intermediate","Advanced"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Exercise Name*", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Equipment", selection: $equipment) {
                        ForEach(equipments, id: \.self) { Text($0) }
                    }
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(difficulties, id: \.self) { Text($0) }
                    }
                    TextField("Primary Muscle", text: $primaryMuscle)
                }
                Section("Optional") {
                    TextField("Form Tips", text: $formTip, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                    TextField("Image URL", text: $imageURL)
                        .keyboardType(.URL)
                    TextField("YouTube URL", text: $youtubeURL)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("Create Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        // Would add to user's custom exercise library
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .foregroundColor(.aura.accent)
                }
            }
        }
    }
}
