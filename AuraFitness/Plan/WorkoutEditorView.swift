import SwiftUI
import UniformTypeIdentifiers

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
    @State private var draggingID: UUID?
    @State private var menuExerciseID: UUID?
    @State private var pickerMode: PickerMode?
    @State private var supersetPickIndex: Int?
    @State private var detailTargetID: UUID?
    @State private var showNoLibraryAlert = false
    @Environment(\.dismiss) var dismiss

    /// Which exercise-picker flow is active, carrying the target index.
    enum PickerMode: Identifiable {
        case substitute(index: Int)
        case addAfter(index: Int)
        case supersetNew(leaderIndex: Int)

        var id: String {
            switch self {
            case .substitute(let i):   return "sub-\(i)"
            case .addAfter(let i):     return "add-\(i)"
            case .supersetNew(let i):  return "ss-\(i)"
            }
        }
    }

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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                infoCard

                if !isReadOnly {
                    RestLadderPicker(title: "Between sets", seconds: $workout.restBetweenSets)
                    RestLadderPicker(title: "After exercise", seconds: $workout.restBetweenExercises)
                }

                AuraSectionLabel(title: "Exercises (\(workout.exercises.count))")

                exerciseList

                if !isReadOnly {
                    AuraTintedButton(label: "Add Exercise", icon: "plus") {
                        showExLibrary = true
                    }
                }

                if case .view = context {
                    AuraPrimaryButton(label: "Add to My Plans", icon: "plus") {
                        // Show SaveEditScope to copy workout into plan
                        showSaveScope = true
                    }
                    .padding(.top, AuraSpacing.s2)
                }
            }
            .padding(AuraSpacing.screenPad)
        }
        .background(Color.aura.bg.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { deleteBar }
        .sheet(isPresented: $showExLibrary) {
            ExercisePickerSheet { ex in
                workout.exercises.append(ex)
                showExLibrary = false
            }
        }
        .sheet(item: menuExerciseBinding) { target in
            if let idx = workout.exercises.firstIndex(where: { $0.id == target.id }) {
                let paired = workout.exercises[idx].supersetGroupID != nil
                ExerciseEditMenuSheet(
                    exercise: $workout.exercises[idx],
                    onSubstitute: { pickerMode = .substitute(index: idx) },
                    onSuperset: {
                        if paired {
                            dissolveSuperset(at: idx)
                        } else {
                            supersetPickIndex = idx
                        }
                    },
                    onAddAfter: { pickerMode = .addAfter(index: idx) },
                    onRemove: { removeExercise(id: target.id) },
                    isSuperset: paired
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $pickerMode) { mode in
            EditorExercisePicker(mode: displayMode(for: mode)) { entry in
                applyPick(entry, mode: mode)
            }
        }
        .sheet(item: supersetPickBinding) { box in
            let leaderIdx = box.value
            if workout.exercises.indices.contains(leaderIdx) {
                SupersetPickSheet(
                    leader: workout.exercises[leaderIdx],
                    candidates: supersetCandidates(excludingLeader: leaderIdx),
                    onPickExisting: { partner in
                        pairExisting(leaderIndex: leaderIdx, partnerID: partner.id)
                    },
                    onPickFromLibrary: {
                        pickerMode = .supersetNew(leaderIndex: leaderIdx)
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: detailBinding) { box in
            if let idx = workout.exercises.firstIndex(where: { $0.id == box.id }),
               let entry = libraryEntry(for: workout.exercises[idx]) {
                ExerciseEntryDetailView(entry: entry, workoutCtx: workoutEditCtx(forIndex: idx))
            }
        }
        .alert("No library page", isPresented: $showNoLibraryAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This custom exercise has no library page.")
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

    // MARK: - Name / muscles / duration card

    @ViewBuilder
    private var infoCard: some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                if isReadOnly {
                    Text(workout.name)
                        .font(AuraFont.cardTitle())
                        .foregroundColor(.aura.text)
                    Text(workout.primaryMuscles)
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text2)
                    Text("~\(workout.estimatedMinutes) min")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text2)
                } else {
                    TextField("Workout Name", text: $workout.name)
                        .font(AuraFont.cardTitle())
                        .foregroundColor(.aura.text)
                        .textFieldStyle(.plain)
                    Divider()
                    TextField("Primary Muscles", text: $workout.primaryMuscles)
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text2)
                        .textFieldStyle(.plain)
                    HStack {
                        Text("Duration")
                            .font(AuraFont.body())
                            .foregroundColor(.aura.text2)
                        Spacer()
                        AuraStepper(value: $workout.estimatedMinutes, range: 10...180, step: 5,
                                    format: { "~\($0) min" })
                    }
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    // MARK: - Exercise list (custom cards + drag reorder)

    @ViewBuilder
    private var exerciseList: some View {
        if workout.exercises.isEmpty {
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundColor(.aura.text3)
                .frame(height: 72)
                .overlay(
                    Text("No exercises yet — add one below")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                )
        } else {
            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { i, ex in
                let leader = isSupersetLeader(ex)
                let follower = isSupersetFollower(i)

                ExerciseEditCard(
                    exercise: ex,
                    index: i,
                    isReadOnly: isReadOnly,
                    isSupersetLeader: leader,
                    onTapName: { openDetail(for: ex) },
                    onMenu: { menuExerciseID = ex.id }
                )
                .overlay(supersetBorder(show: leader || follower))
                .opacity(draggingID != nil && draggingID != ex.id ? 0.5 : 1)
                .overlay(dragOverlay(for: ex))
                .modifier(ReorderModifier(
                    enabled: !isReadOnly,
                    id: ex.id,
                    draggingID: $draggingID,
                    onDrop: { from in moveExercise(from: from, to: ex.id) }
                ))

                // Connector bar sits between a leader and its follower.
                if leader {
                    SupersetConnector()
                }
            }
        }
    }

    /// Accent border overlay for the two cards of a superset pair.
    @ViewBuilder
    private func supersetBorder(show: Bool) -> some View {
        if show {
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .stroke(Color.aura.accent.opacity(0.5), lineWidth: 1.5)
        }
    }

    @ViewBuilder
    private func dragOverlay(for ex: Exercise) -> some View {
        if draggingID != nil && draggingID != ex.id {
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundColor(.aura.text3)
        }
    }

    // MARK: - Toolbar / delete bar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !isReadOnly {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveWorkout(); dismiss() }
                    .foregroundColor(.aura.accent)
                    .disabled(workout.name.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var deleteBar: some View {
        if case .editInProgram = context {
            AuraDangerButton(label: "Delete Workout", icon: "trash") {
                showDeleteAlert = true
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, AuraSpacing.s2)
        }
    }

    // MARK: - Helpers

    /// A `.sheet(item:)` adapter around the `menuExerciseID` optional.
    private var menuExerciseBinding: Binding<IDBox?> {
        Binding(
            get: { menuExerciseID.map(IDBox.init) },
            set: { menuExerciseID = $0?.id }
        )
    }

    /// A `.sheet(item:)` adapter wrapping the superset leader index.
    private var supersetPickBinding: Binding<IntBox?> {
        Binding(
            get: { supersetPickIndex.map(IntBox.init) },
            set: { supersetPickIndex = $0?.value }
        )
    }

    /// A `.sheet(item:)` adapter around the exercise-detail target.
    private var detailBinding: Binding<IDBox?> {
        Binding(
            get: { detailTargetID.map(IDBox.init) },
            set: { detailTargetID = $0?.id }
        )
    }

    // MARK: Exercise detail

    /// Resolve the library `ExerciseEntry` for a workout exercise by
    /// case-insensitive name; nil for custom exercises with no library page.
    private func libraryEntry(for exercise: Exercise) -> ExerciseEntry? {
        let target = exercise.name.trimmingCharacters(in: .whitespaces).lowercased()
        return ExerciseDatabase.shared.entries.first {
            $0.name.trimmingCharacters(in: .whitespaces).lowercased() == target
        }
    }

    /// Open the library detail for an exercise, or alert if it has no page.
    private func openDetail(for exercise: Exercise) {
        if libraryEntry(for: exercise) != nil {
            detailTargetID = exercise.id
        } else {
            showNoLibraryAlert = true
        }
    }

    /// Build the workout-editing context passed into the detail view. Not shown
    /// when read-only (⋯ / tap paths are inert there anyway).
    private func workoutEditCtx(forIndex idx: Int) -> WorkoutEditCtx? {
        guard !isReadOnly, workout.exercises.indices.contains(idx) else { return nil }
        let ex = workout.exercises[idx]
        let exID = ex.id

        // Partner entry when this exercise is part of a pair (leader or follower).
        var partner: ExerciseEntry?
        var isPair = false
        if let gid = ex.supersetGroupID {
            if let partnerEx = workout.exercises.first(where: {
                $0.supersetGroupID == gid && $0.id != exID
            }) {
                isPair = true
                partner = libraryEntry(for: partnerEx)
            }
        }

        return WorkoutEditCtx(
            sets: ex.plannedSets,
            repRange: ex.repRange,
            restSeconds: workout.restBetweenSets,
            isSuperset: isPair,
            partnerEntry: partner,
            onSave: { sets, reps, rest in
                if let i = workout.exercises.firstIndex(where: { $0.id == exID }) {
                    workout.exercises[i].plannedSets = sets
                    workout.exercises[i].repRange = reps
                }
                workout.restBetweenSets = rest
            }
        )
    }

    // MARK: Superset queries

    /// A leader has a non-nil group and the NEXT exercise shares that group.
    private func isSupersetLeader(_ ex: Exercise) -> Bool {
        guard let gid = ex.supersetGroupID,
              let i = workout.exercises.firstIndex(where: { $0.id == ex.id }),
              i + 1 < workout.exercises.count
        else { return false }
        return workout.exercises[i + 1].supersetGroupID == gid
    }

    /// A follower has a non-nil group shared with the PREVIOUS exercise.
    private func isSupersetFollower(_ i: Int) -> Bool {
        guard i > 0, let gid = workout.exercises[i].supersetGroupID else { return false }
        return workout.exercises[i - 1].supersetGroupID == gid
    }

    /// Exercises eligible to become Exercise B: everything except the leader and
    /// anything already in a superset (no chains).
    private func supersetCandidates(excludingLeader leaderIdx: Int) -> [Exercise] {
        workout.exercises.enumerated().compactMap { i, ex in
            (i != leaderIdx && ex.supersetGroupID == nil) ? ex : nil
        }
    }

    // MARK: Mutations

    /// Remove by id (never by a stale index) so an open menu sheet is safe.
    private func removeExercise(id: UUID) {
        workout.exercises.removeAll { $0.id == id }
        normalizeSupersets()
    }

    /// Move the dragged exercise (`from`) to the position of the drop target.
    private func moveExercise(from: UUID, to: UUID) {
        guard from != to,
              let src = workout.exercises.firstIndex(where: { $0.id == from }),
              let dst = workout.exercises.firstIndex(where: { $0.id == to })
        else { return }
        let moved = workout.exercises.remove(at: src)
        workout.exercises.insert(moved, at: min(dst, workout.exercises.count))
        normalizeSupersets()
    }

    /// Clear the group on the exercise at `idx` and any adjacent partner sharing it.
    private func dissolveSuperset(at idx: Int) {
        guard workout.exercises.indices.contains(idx),
              let gid = workout.exercises[idx].supersetGroupID else { return }
        for i in workout.exercises.indices where workout.exercises[i].supersetGroupID == gid {
            workout.exercises[i].supersetGroupID = nil
        }
    }

    /// Pair the leader with an existing candidate: dissolve any pre-existing
    /// groups on either party, stamp a fresh group id on both, then move the
    /// partner to sit immediately after the leader.
    private func pairExisting(leaderIndex: Int, partnerID: UUID) {
        guard workout.exercises.indices.contains(leaderIndex),
              let partnerIdx = workout.exercises.firstIndex(where: { $0.id == partnerID })
        else { return }

        dissolveSuperset(at: leaderIndex)
        dissolveSuperset(at: partnerIdx)

        let gid = UUID()
        let leaderID = workout.exercises[leaderIndex].id
        workout.exercises[leaderIndex].supersetGroupID = gid

        // Pull the partner out, then re-insert right after the leader.
        var partner = workout.exercises.remove(at: partnerIdx)
        partner.supersetGroupID = gid
        // Removal shifts the leader's index down by 1 if the partner sat before it.
        let leaderNow = workout.exercises.firstIndex(where: { $0.id == leaderID }) ?? leaderIndex
        workout.exercises.insert(partner, at: min(leaderNow + 1, workout.exercises.count))
        normalizeSupersets()
    }

    /// Auto-dissolve any group whose two members are no longer physically
    /// adjacent (run after every mutation of `workout.exercises`).
    private func normalizeSupersets() {
        // Count members per group.
        var counts: [UUID: Int] = [:]
        for ex in workout.exercises {
            if let gid = ex.supersetGroupID { counts[gid, default: 0] += 1 }
        }
        for i in workout.exercises.indices {
            guard let gid = workout.exercises[i].supersetGroupID else { continue }
            let prevShares = i > 0 && workout.exercises[i - 1].supersetGroupID == gid
            let nextShares = i + 1 < workout.exercises.count
                && workout.exercises[i + 1].supersetGroupID == gid
            // Adjacency broken, or the group lost a member → dissolve this cell.
            if (!prevShares && !nextShares) || (counts[gid] ?? 0) != 2 {
                workout.exercises[i].supersetGroupID = nil
            }
        }
    }

    // MARK: Picker apply

    private func displayMode(for mode: PickerMode) -> EditorPickerMode {
        switch mode {
        case .substitute(let i):
            let name = workout.exercises.indices.contains(i) ? workout.exercises[i].name : ""
            return .substitute(replacingName: name)
        case .addAfter:
            return .addAfter
        case .supersetNew:
            return .supersetNew
        }
    }

    /// Apply a picked library entry according to the active picker mode.
    private func applyPick(_ entry: ExerciseEntry, mode: PickerMode) {
        let picked = ExerciseDatabase.shared.toExercise(entry)
        switch mode {
        case .substitute(let i):
            guard workout.exercises.indices.contains(i) else { return }
            // Carry over the old exercise's planned volume + pairing.
            var replacement = picked
            replacement.plannedSets = workout.exercises[i].plannedSets
            replacement.repRange = workout.exercises[i].repRange
            replacement.supersetGroupID = workout.exercises[i].supersetGroupID
            workout.exercises[i] = replacement

        case .addAfter(let i):
            var ex = picked
            ex.supersetGroupID = nil
            workout.exercises.insert(ex, at: min(i + 1, workout.exercises.count))

        case .supersetNew(let leader):
            guard workout.exercises.indices.contains(leader) else { return }
            dissolveSuperset(at: leader)
            let gid = UUID()
            workout.exercises[leader].supersetGroupID = gid
            var ex = picked
            ex.supersetGroupID = gid
            workout.exercises.insert(ex, at: min(leader + 1, workout.exercises.count))
        }
        normalizeSupersets()
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

// MARK: - Reorder support

/// `Identifiable` wrapper so a bare `UUID?` can drive a `.sheet(item:)`.
private struct IDBox: Identifiable { let id: UUID }

/// `Identifiable` wrapper so a bare `Int` index can drive a `.sheet(item:)`.
private struct IntBox: Identifiable {
    let value: Int
    var id: Int { value }
}

/// Attaches `onDrag`/`onDrop` to an exercise card for manual reordering. The
/// dragged card's id is carried as plain text; the drop target reorders via the
/// supplied closure. Reordering is inert when `enabled` is false (read-only).
private struct ReorderModifier: ViewModifier {
    let enabled: Bool
    let id: UUID
    @Binding var draggingID: UUID?
    let onDrop: (UUID) -> Void

    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    draggingID = id
                    return NSItemProvider(object: id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: ReorderDropDelegate(
                    targetID: id, draggingID: $draggingID, onDrop: onDrop))
        } else {
            content
        }
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggingID: UUID?
    let onDrop: (UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let from = draggingID, from != targetID else { return }
        onDrop(from)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
