import SwiftUI

struct ProgramEditorView: View {
    enum Mode {
        case create
        case edit(Program)
    }

    let mode: Mode
    @StateObject private var programDB = ProgramDatabase.shared
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var level: String
    @State private var style: String
    @State private var daysPerWeek: Int
    @State private var description: String
    @State private var workouts: [Workout]
    @State private var showAddWorkout = false
    @State private var editingWorkout: Workout? = nil
    @State private var showDeleteAlert = false

    private var programID: UUID? {
        if case .edit(let p) = mode { return p.id }
        return nil
    }

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _level = State(initialValue: "Intermediate")
            _style = State(initialValue: "Hypertrophy")
            _daysPerWeek = State(initialValue: 3)
            _description = State(initialValue: "")
            _workouts = State(initialValue: [])
        case .edit(let p):
            _name = State(initialValue: p.name)
            _level = State(initialValue: p.level)
            _style = State(initialValue: p.style)
            _daysPerWeek = State(initialValue: p.daysPerWeek)
            _description = State(initialValue: p.description)
            _workouts = State(initialValue: p.workouts)
        }
    }

    let levels = ["Beginner","Intermediate","Advanced","All Levels"]
    let styles = ["Hypertrophy","Strength","Power","PPL","Upper/Lower","Full Body","Conditioning"]

    var body: some View {
        NavigationStack {
            List {
                Section("Program Info") {
                    TextField("Program Name", text: $name)
                    Picker("Level", selection: $level) {
                        ForEach(levels, id: \.self) { Text($0) }
                    }
                    Picker("Style", selection: $style) {
                        ForEach(styles, id: \.self) { Text($0) }
                    }
                    Stepper("Days per week: \(daysPerWeek)", value: $daysPerWeek, in: 1...7)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Workouts (\(workouts.count))") {
                    ForEach(workouts) { workout in
                        Button {
                            editingWorkout = workout
                        } label: {
                            HStack(spacing: AuraSpacing.s3) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workout.name)
                                        .font(AuraFont.body())
                                        .foregroundColor(.aura.text)
                                    Text("\(workout.exercises.count) exercises · ~\(workout.estimatedMinutes) min")
                                        .font(AuraFont.secondary())
                                        .foregroundColor(.aura.text2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.aura.text3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onMove { from, to in workouts.move(fromOffsets: from, toOffset: to) }
                    .onDelete { idx in workouts.remove(atOffsets: idx) }

                    Button {
                        showAddWorkout = true
                    } label: {
                        Label("Add Workout", systemImage: "plus.circle.fill")
                            .foregroundColor(.aura.accent)
                    }
                }

                if case .edit = mode {
                    Section {
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Program", systemImage: "trash")
                                .foregroundColor(.aura.red)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(programID == nil ? "New Program" : "Edit Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .foregroundColor(.aura.accent)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAddWorkout) {
                WorkoutEditorView(
                    workout: Workout(name: "", primaryMuscles: "", estimatedMinutes: 45, exercises: []),
                    context: .createStandalone
                )
                // After dismiss, user-created workout ends up in programDB.__standalone__
                // For program context we use onDismiss to grab it
            }
            .sheet(item: $editingWorkout) { w in
                WorkoutEditorView(
                    workout: w,
                    context: programID.map { .editInProgram(programID: $0) } ?? .createStandalone
                )
            }
            .alert("Delete Program", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let pid = programID { programDB.deleteProgram(id: pid) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete the program and all its workouts.")
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        switch mode {
        case .create:
            let prog = Program(
                name: trimmedName,
                daysPerWeek: daysPerWeek,
                level: level,
                style: style,
                description: description,
                workouts: workouts,
                isPredefined: false
            )
            programDB.addProgram(prog)
        case .edit(let existing):
            var updated = existing
            updated.name = trimmedName
            updated.daysPerWeek = daysPerWeek
            updated.level = level
            updated.style = style
            updated.description = description
            updated.workouts = workouts
            programDB.updateProgram(updated)
        }
    }
}
