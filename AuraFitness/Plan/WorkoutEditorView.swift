import SwiftUI

enum WorkoutEditorContext {
    case view                                         // read from program library (view only, no save)
    case createStandalone                             // new workout saved to a standalone pool
    case editInProgram(programID: UUID)               // editing existing workout in a program
    case editInPlan(planID: UUID)                     // editing custom workout in a plan
    case createInProgram(programID: UUID)             // new workout added to a program
    case createInPlan(planID: UUID)                   // new custom workout added to a plan
}

struct WorkoutEditorView: View {
    @State var workout: Workout
    let context: WorkoutEditorContext

    @StateObject private var programDB = ProgramDatabase.shared
    @StateObject private var planDB = UserPlanDatabase.shared
    @State private var showExLibrary = false
    @State private var showSaveScope = false
    @State private var showDeleteAlert = false
    @Environment(\.dismiss) var dismiss

    private var isReadOnly: Bool {
        if case .view = context { return true }
        return false
    }

    private var title: String {
        switch context {
        case .view: return workout.name
        case .createStandalone, .createInProgram, .createInPlan: return "New Workout"
        case .editInProgram, .editInPlan: return workout.name
        }
    }

    var body: some View {
        List {
            Section("Workout Info") {
                if isReadOnly {
                    LabeledContent("Name", value: workout.name)
                    LabeledContent("Muscles", value: workout.primaryMuscles)
                    LabeledContent("Duration", value: "~\(workout.estimatedMinutes) min")
                } else {
                    TextField("Workout Name", text: $workout.name)
                    TextField("Primary Muscles", text: $workout.primaryMuscles)
                    Stepper("Duration: ~\(workout.estimatedMinutes) min",
                            value: $workout.estimatedMinutes, in: 10...180, step: 5)
                    Stepper("Rest between sets: \(workout.restBetweenSets)s",
                            value: $workout.restBetweenSets, in: 15...300, step: 15)
                    Stepper("Rest between exercises: \(workout.restBetweenExercises)s",
                            value: $workout.restBetweenExercises, in: 30...600, step: 15)
                }
            }

            Section("Exercises (\(workout.exercises.count))") {
                ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { i, ex in
                    exerciseRow(ex, index: i)
                }
                .onMove(perform: isReadOnly ? nil : { from, to in workout.exercises.move(fromOffsets: from, toOffset: to) })
                .onDelete(perform: isReadOnly ? nil : { idx in workout.exercises.remove(atOffsets: idx) })
            }

            if !isReadOnly {
                Section {
                    Button {
                        showExLibrary = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .foregroundColor(.aura.accent)
                    }
                }
            }

            if case .view = context {
                Section {
                    Button {
                        // Show SaveEditScope to copy workout into plan
                        showSaveScope = true
                    } label: {
                        Label("Add to My Plans", systemImage: "plus")
                            .foregroundColor(.aura.accent)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showExLibrary) {
            ExercisePickerSheet { ex in
                workout.exercises.append(ex)
                showExLibrary = false
            }
        }
        .sheet(isPresented: $showSaveScope) {
            SaveEditScopeSheet(
                onJustToday: nil,
                onPermanently: { saveWorkout() }
            )
            .presentationDetents([.fraction(0.45)])
            .presentationDragIndicator(.visible)
        }
        .alert("Delete Workout", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteWorkout(); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove this workout.")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !isReadOnly {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveWorkout(); dismiss() }
                    .foregroundColor(.aura.accent)
                    .disabled(workout.name.isEmpty)
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        if case .editInProgram = context {
            ToolbarItem(placement: .bottomBar) {
                Button(role: .destructive) { showDeleteAlert = true } label: {
                    Label("Delete Workout", systemImage: "trash")
                        .foregroundColor(.aura.red)
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseRow(_ ex: Exercise, index: Int) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            if !isReadOnly {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.aura.text3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(ex.name)
                    .font(AuraFont.body())
                    .foregroundColor(.aura.text)
                HStack(spacing: 4) {
                    AuraBadge(label: "\(ex.plannedSets) sets", color: .aura.text2)
                    AuraBadge(label: ex.repRange, color: .aura.text2)
                    AuraBadge(label: ex.equipment, color: .aura.text2)
                }
            }
        }
    }

    private func saveWorkout() {
        switch context {
        case .view:
            break
        case .createStandalone:
            // Create a throwaway program to house standalone workouts
            if let existing = programDB.programs.first(where: { $0.name == "__standalone__" }) {
                programDB.addWorkout(workout, to: existing.id)
            } else {
                var prog = Program(name: "__standalone__", daysPerWeek: 0, level: "", style: "", description: "", workouts: [workout], isPredefined: false)
                programDB.addProgram(prog)
            }
        case .createInProgram(let pid):
            programDB.addWorkout(workout, to: pid)
        case .editInProgram(let pid):
            programDB.updateWorkout(workout, in: pid)
        case .createInPlan(let planID):
            planDB.addCustomWorkout(workout, to: planID)
        case .editInPlan(let planID):
            planDB.updateCustomWorkout(workout, in: planID)
        }
    }

    private func deleteWorkout() {
        switch context {
        case .editInProgram(let pid):
            programDB.deleteWorkout(id: workout.id, from: pid)
        case .editInPlan(let planID):
            planDB.deleteCustomWorkout(id: workout.id, from: planID)
        default:
            break
        }
    }
}
