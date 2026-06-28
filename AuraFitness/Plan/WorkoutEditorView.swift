import SwiftUI

struct WorkoutEditorView: View {
    @State var workout: Workout
    @State private var showExLibrary = false
    @State private var showSaveScope = false

    var body: some View {
        List {
            Section("Workout Info") {
                TextField("Workout Name", text: $workout.name)
                Stepper("Rest between sets: \(workout.restBetweenSets)s",
                        value: $workout.restBetweenSets, in: 15...300, step: 15)
                Stepper("Rest between exercises: \(workout.restBetweenExercises)s",
                        value: $workout.restBetweenExercises, in: 30...600, step: 15)
            }
            Section("Exercises") {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { i, ex in
                    exerciseRow(ex, index: i)
                }
                .onMove { from, to in workout.exercises.move(fromOffsets: from, toOffset: to) }
                .onDelete { idx in workout.exercises.remove(atOffsets: idx) }
            }
            Section {
                Button {
                    showExLibrary = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .foregroundColor(.aura.accent)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { showSaveScope = true }
                    .foregroundColor(.aura.accent)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showExLibrary) {
            ExercisePickerSheet { ex in
                workout.exercises.append(ex)
                showExLibrary = false
            }
        }
        .sheet(isPresented: $showSaveScope) {
            SaveEditScopeSheet()
                .presentationDetents([.fraction(0.45)])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func exerciseRow(_ ex: Exercise, index: Int) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            Image(systemName: "line.3.horizontal")
                .foregroundColor(.aura.text3)
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(AuraFont.body())
                    .foregroundColor(.aura.text)
                HStack(spacing: 4) {
                    AuraBadge(label: "\(ex.plannedSets) sets", color: .aura.text2)
                    AuraBadge(label: ex.repRange, color: .aura.text2)
                }
            }
        }
    }
}
