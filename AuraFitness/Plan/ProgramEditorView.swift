import SwiftUI

// MARK: - Program Editor
//
// Build-a-program-from-scratch (create) or edit an adopted copy. Because the
// shared WorkoutEditorView writes workout edits straight to ProgramDatabase via
// its context (it has no local-array binding), a real program id must exist
// before its workouts can be edited. Create mode therefore lazily commits a
// draft program to the DB on the first workout add, then edits it in place; a
// Cancel that leaves an untouched draft deletes it so no orphan lingers.

struct ProgramEditorView: View {
    enum Mode {
        case create
        case edit(Program)
    }

    let mode: Mode
    @StateObject private var programDB = ProgramDatabase.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var level: String
    @State private var style: String
    @State private var daysPerWeek: Int
    @State private var description: String

    /// The id of the program being edited. Non-nil in edit mode from the start;
    /// in create mode it's filled once a draft is committed (see `ensureProgramID`).
    @State private var programID: UUID?
    /// True in create mode only until the draft has been committed to the DB.
    @State private var draftCommitted: Bool

    /// Local preview schedule (weekday → workout id / nil rest). Program has no
    /// schedule field of its own — scheduling is materialised when the program
    /// is adopted as a plan — so this is editor-preview state for parity.
    @State private var schedule: [Int: UUID?] = [:]

    @FocusState private var nameFocused: Bool
    @State private var showAddChooser = false
    @State private var showLibrary = false
    @State private var editorTarget: WorkoutEditorTarget? = nil
    @State private var assignDay: Int? = nil
    @State private var workoutToDelete: Workout? = nil
    @State private var showDeleteAlert = false
    @State private var showDeleteProgramAlert = false
    @State private var warnEmpty = false

    /// Sheet payload: which workout to open in which editor context.
    struct WorkoutEditorTarget: Identifiable {
        let id = UUID()
        let workout: Workout
        let context: WorkoutEditorContext
    }

    /// Live workouts: read from the DB once a program id exists, else empty
    /// (create mode before the first add). The DB is the source of truth so the
    /// child WorkoutEditorView's writes reflect back here.
    private var workouts: [Workout] {
        programID.flatMap { programDB.program(id: $0)?.workouts } ?? []
    }

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _level = State(initialValue: "")
            _style = State(initialValue: "Hypertrophy")
            _daysPerWeek = State(initialValue: 3)
            _description = State(initialValue: "")
            _programID = State(initialValue: nil)
            _draftCommitted = State(initialValue: false)
        case .edit(let p):
            _name = State(initialValue: p.name)
            _level = State(initialValue: p.level)
            _style = State(initialValue: p.style)
            _daysPerWeek = State(initialValue: p.daysPerWeek)
            _description = State(initialValue: p.description)
            _programID = State(initialValue: p.id)
            _draftCommitted = State(initialValue: true)
        }
    }

    private let difficulties = ["Beginner", "Intermediate", "Advanced"]
    private func difficultyColor(_ d: String) -> Color {
        switch d {
        case "Beginner":  return .aura.green
        case "Advanced":  return .aura.red
        default:          return .aura.accent
        }
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AuraSpacing.s5) {
                        nameField
                        difficultyControl
                        weekStripSection
                        workoutsSection
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.top, AuraSpacing.s4)
                    .padding(.bottom, 120)
                }

                stickyFooter
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle(isEdit ? "Edit Program" : "New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                if isEdit {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) { showDeleteProgramAlert = true } label: {
                            Image(systemName: "trash").foregroundColor(.aura.red)
                        }
                    }
                }
            }
            .onAppear { nameFocused = true }
            .confirmationDialog("Add Workout", isPresented: $showAddChooser, titleVisibility: .visible) {
                Button("Add from Workout Library") { showLibrary = true }
                Button("Create your own workout") { createOwnWorkout() }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showLibrary) {
                NavigationStack { WorkoutLibraryPickerView(onPick: addFromLibrary) }
            }
            .sheet(item: $editorTarget) { target in
                NavigationStack {
                    WorkoutEditorView(workout: target.workout, context: target.context)
                }
            }
            .sheet(item: assignDayBinding) { box in
                assignSheet(day: box.value)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .alert("Remove Workout", isPresented: $showDeleteAlert, presenting: workoutToDelete) { w in
                Button("Remove", role: .destructive) { deleteWorkout(w) }
                Button("Cancel", role: .cancel) {}
            } message: { w in
                Text("'\(w.name)' will be removed from this program.")
            }
            .alert("Delete Program", isPresented: $showDeleteProgramAlert) {
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

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    // MARK: Name field (auto-focused, large)

    private var nameField: some View {
        TextField("Program name", text: $name)
            .font(AuraFont.cardTitle(size: 26))
            .tracking(AuraFont.cardTitleTracking(size: 26))
            .foregroundColor(.aura.text)
            .textFieldStyle(.plain)
            .focused($nameFocused)
            .submitLabel(.done)
    }

    // MARK: Difficulty segmented control (optional value)

    private var difficultyControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            AuraSectionLabel(title: "Difficulty").padding(.top, 0)
            HStack(spacing: 4) {
                ForEach(difficulties, id: \.self) { d in
                    let active = level == d
                    Button {
                        // Tapping the active segment again clears the selection.
                        level = active ? "" : d
                    } label: {
                        Text(d)
                            .font(AuraFont.jakarta(13, .bold))
                            .foregroundColor(active ? .white : .aura.text2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                            .background(active ? difficultyColor(d) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm - 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        }
    }

    // MARK: Week strip

    private var weekStripSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AuraSectionLabel(title: "This week").padding(.top, 0)
            WeekStripView(
                calendarStartDay: appState.calendarStartDay,
                workoutForDay: { day in workoutForDay(day) },
                onTapDay: { day in tapDay(day) }
            )
            if warnEmpty {
                Text("Add workouts below before assigning days")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.accent)
                    .padding(.horizontal, AuraSpacing.s3)
                    .padding(.vertical, AuraSpacing.s2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.aura.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                    .transition(.opacity)
            }
        }
    }

    private func workoutForDay(_ day: Int) -> Workout? {
        guard let entry = schedule[day], let wid = entry else { return nil }
        return workouts.first { $0.id == wid }
    }

    private func tapDay(_ day: Int) {
        guard !workouts.isEmpty else {
            // Flash the inline warning; auto-dismiss after 2.5s.
            withAnimation { warnEmpty = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { warnEmpty = false }
            }
            return
        }
        assignDay = day
    }

    private var assignDayBinding: Binding<IntBox?> {
        Binding(get: { assignDay.map { IntBox(value: $0) } }, set: { assignDay = $0?.value })
    }

    @ViewBuilder
    private func assignSheet(day: Int) -> some View {
        PlanSheet(title: "Assign workout", onClose: { assignDay = nil }) {
            PlanList {
                Button {
                    schedule[day] = .some(nil); assignDay = nil
                } label: {
                    assignRow(label: "Rest Day", icon: "moon.fill", tint: .aura.text3)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 14)
                ForEach(Array(workouts.enumerated()), id: \.element.id) { i, w in
                    Button {
                        schedule[day] = w.id; assignDay = nil
                    } label: {
                        assignRow(label: w.name, icon: planWkIcon(w.name), tint: planWkStyle(w.name).tint)
                    }
                    .buttonStyle(.plain)
                    if i < workouts.count - 1 { Divider().padding(.leading, 14) }
                }
            }
        }
    }

    private func assignRow(label: String, icon: String, tint: Color) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            Image(systemName: icon).font(AuraFont.jakarta(16)).foregroundColor(tint).frame(width: 24)
            Text(label).font(AuraFont.body()).foregroundColor(.aura.text)
            Spacer()
        }
        .padding(.vertical, 11).padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Color.aura.surface)
    }

    // MARK: Workouts section

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                AuraSectionLabel(title: "Workouts (\(workouts.count))").padding(.top, 0)
                Spacer()
                PlanIconButton(icon: "plus", size: 16, diameter: 28, accent: true) {
                    showAddChooser = true
                }
            }
            .padding(.bottom, 10)

            if workouts.isEmpty {
                VStack(spacing: 10) {
                    AuraTintedButton(label: "Add from Workout Library", icon: "books.vertical") {
                        showLibrary = true
                    }
                    AuraTintedButton(label: "Create your own workout", icon: "plus") {
                        createOwnWorkout()
                    }
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(workouts) { w in
                        workoutRow(w)
                    }
                }
            }
        }
    }

    private func workoutRow(_ w: Workout) -> some View {
        let style = planWkStyle(w.name)
        return HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(style.bg)
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(style.border.opacity(0.35), lineWidth: 1.5))
                Image(systemName: planWkIcon(w.name))
                    .font(AuraFont.jakarta(20)).foregroundColor(style.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(w.name.isEmpty ? "Untitled workout" : w.name)
                    .font(AuraFont.jakarta(15, .heavy)).foregroundColor(.aura.text)
                Text("\(w.exercises.count) exercises · ~\(w.estimatedMinutes) min")
                    .font(AuraFont.jakarta(12, .medium)).foregroundColor(.aura.text2)
                    .lineLimit(1)
            }
            Spacer()
            Button { editWorkout(w) } label: {
                Image(systemName: "chevron.right").font(AuraFont.jakarta(14, .semibold)).foregroundColor(.aura.text3)
                    .frame(width: 30, height: 30)
            }
            Button {
                workoutToDelete = w
                showDeleteAlert = true
            } label: {
                Image(systemName: "trash").font(AuraFont.jakarta(14, .medium)).foregroundColor(.aura.red)
                    .frame(width: 30, height: 30)
                    .background(Color.aura.fill.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { editWorkout(w) }
    }

    // MARK: Sticky footer

    private var stickyFooter: some View {
        VStack(spacing: 0) {
            Divider()
            AuraPrimaryButton(label: "Save Program") { save(); dismiss() }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s3)
                .padding(.bottom, AuraSpacing.s4)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: Workout CRUD routing (all through the DB via a real program id)

    /// Ensure a committed program id exists (create mode: commit a draft the
    /// first time a workout is added). Returns the id, or nil if it can't be made.
    private func ensureProgramID() -> UUID? {
        if let pid = programID { return pid }
        let draft = Program(
            name: trimmedName.isEmpty ? "Untitled Program" : trimmedName,
            daysPerWeek: daysPerWeek, level: level, style: style,
            description: description, workouts: [], isPredefined: false
        )
        programDB.addProgram(draft)
        programID = draft.id
        draftCommitted = true
        return draft.id
    }

    private func addFromLibrary(_ w: Workout) {
        guard let pid = ensureProgramID() else { return }
        // Copy into the program under a fresh id so the source stays untouched.
        var copy = w
        copy.id = UUID()
        programDB.addWorkout(copy, to: pid)
        showLibrary = false
    }

    private func createOwnWorkout() {
        guard let pid = ensureProgramID() else { return }
        editorTarget = WorkoutEditorTarget(
            workout: Workout(name: "", primaryMuscles: "", estimatedMinutes: 45, exercises: []),
            context: .createInProgram(programID: pid)
        )
    }

    private func editWorkout(_ w: Workout) {
        guard let pid = programID else { return }
        editorTarget = WorkoutEditorTarget(workout: w, context: .editInProgram(programID: pid))
    }

    private func deleteWorkout(_ w: Workout) {
        guard let pid = programID else { return }
        programDB.deleteWorkout(id: w.id, from: pid)
        // Null any schedule slot that pointed at the removed workout.
        for (day, entry) in schedule where entry == w.id {
            schedule[day] = .some(nil)
        }
    }

    // MARK: Save / cancel

    private func save() {
        guard canSave else { return }
        if let pid = programID, var p = programDB.program(id: pid) {
            // Program already exists (edit, or create after a draft commit):
            // update its scalar fields; workouts were persisted as they were added.
            p.name = trimmedName
            p.daysPerWeek = daysPerWeek
            p.level = level
            p.style = style
            p.description = description
            programDB.updateProgram(p)
        } else {
            // Pure create with no workouts added yet — persist a fresh program.
            let prog = Program(
                name: trimmedName, daysPerWeek: daysPerWeek, level: level,
                style: style, description: description, workouts: [], isPredefined: false
            )
            programDB.addProgram(prog)
        }
    }

    private func cancel() {
        // Create mode that committed a draft but the user backed out: drop the
        // orphan so it doesn't linger in the library.
        if !isEdit, draftCommitted, let pid = programID {
            programDB.deleteProgram(id: pid)
        }
        dismiss()
    }
}

/// `Identifiable` wrapper so a bare `Int` weekday index can drive `.sheet(item:)`.
private struct IntBox: Identifiable {
    let value: Int
    var id: Int { value }
}

// MARK: - Workout Library Picker
//
// Lightweight searchable list over the program library's workouts that returns
// the chosen workout via `onPick` (the shared WorkoutLibraryView routes taps to
// a read-only editor instead, so it can't be reused for a pick flow).

struct WorkoutLibraryPickerView: View {
    @StateObject private var programDB = ProgramDatabase.shared
    @Environment(\.dismiss) var dismiss
    let onPick: (Workout) -> Void

    @State private var query = ""

    private var filtered: [Workout] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        // Dedupe by name so the same workout across programs shows once.
        var seen = Set<String>()
        return programDB.allWorkouts.filter { w in
            guard q.isEmpty || w.name.lowercased().contains(q)
                || w.primaryMuscles.lowercased().contains(q) else { return false }
            let key = w.name.lowercased()
            return seen.insert(key).inserted
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            PlanSearchField(placeholder: "Search workouts", text: $query)
                .padding(.horizontal, 14)
                .padding(.top, 6)
                .padding(.bottom, 8)

            AuraScreenScroll {
                if filtered.isEmpty {
                    PlanEmptyState(title: "No workouts found", subtitle: "Try a different search")
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { w in
                            PlanLibraryCard(
                                title: w.name,
                                meta: AnyView(
                                    Text("\(w.exercises.count) exercises · \(w.primaryMuscles)")
                                        .font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)
                                        .lineLimit(1)
                                ),
                                trailing: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(AuraFont.jakarta(18, .semibold)).foregroundColor(.aura.accent)
                                },
                                action: { onPick(w); dismiss() }
                            )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                }
            }
        }
        .background(Color.aura.bgGrouped)
        .navigationTitle("Workout Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
    }
}
