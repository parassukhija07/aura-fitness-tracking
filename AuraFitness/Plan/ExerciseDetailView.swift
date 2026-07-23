import SwiftUI

// MARK: - Workout-editor context
//
// Supplied when the detail is opened FROM the workout editor. Enables the
// leading "Workout" tab (inline sets/reps/rest editing) and the A/B superset
// toggle; `onSave` writes the three edited values back into the editor's local
// workout state.
struct WorkoutEditCtx {
    var sets: Int
    var repRange: String
    var restSeconds: Int
    var isSuperset: Bool = false
    var partnerEntry: ExerciseEntry? = nil
    var onSave: (Int, String, Int) -> Void
}

// MARK: - ExerciseEntryDetailView (library-based, tabbed)
struct ExerciseEntryDetailView: View {
    let entry: ExerciseEntry
    /// Present iff opened from the workout editor.
    var workoutCtx: WorkoutEditCtx? = nil
    /// Show the library action bar iff opened from the Exercises library.
    var showActions: Bool = false

    @StateObject private var db = ExerciseDatabase.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = ""
    @State private var showEdit = false
    /// "A" == leader entry, "B" == superset partner entry.
    @State private var activeSlot = "A"

    // Workout-tab editable state (seeded from workoutCtx on appear).
    @State private var editSets = 3
    @State private var editReps = "8–12"
    @State private var editRest = 60

    // Action-bar flow state.
    @State private var showAddToPlan = false
    @State private var toast: String?

    /// Rest ladder for the Workout tab (design-specified, no 15s rung).
    private let workoutRestLadder = [30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

    /// Tab row: Workout (iff editing) · Overview · History · Warmup.
    private var tabs: [String] {
        (workoutCtx != nil ? ["Workout"] : []) + ["Overview", "History", "Warmup"]
    }

    /// Content is keyed off the active slot for the A/B superset toggle.
    private var activeEntry: ExerciseEntry {
        if activeSlot == "B", let partner = workoutCtx?.partnerEntry { return partner }
        return entry
    }

    /// Action bar shows only in library mode; workoutCtx wins if both passed.
    private var showActionBar: Bool { showActions && workoutCtx == nil }

    private var showABToggle: Bool {
        (workoutCtx?.isSuperset == true) && (workoutCtx?.partnerEntry != nil)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // A/B superset toggle (above the tab row).
                if showABToggle {
                    HStack(spacing: 4) {
                        abSegment("A", entry.name)
                        abSegment("B", workoutCtx?.partnerEntry?.name ?? "B")
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.vertical, AuraSpacing.s2)
                    .background(Color.aura.surface)
                }

                // Hero
                heroSection

                // Sub-tabs
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                        } label: {
                            VStack(spacing: 6) {
                                Text(tab)
                                    .font(AuraFont.jakarta(14, selectedTab == tab ? .bold : .medium))
                                    .foregroundColor(selectedTab == tab ? .aura.accent : .aura.text2)
                                Rectangle()
                                    .fill(selectedTab == tab ? Color.aura.accent : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .background(Color.aura.surface)

                Divider()

                // Tab content
                ScrollView {
                    switch selectedTab {
                    case "Workout":  workoutTab
                    case "Overview": overviewTab
                    case "History":  ExerciseHistoryTab(exerciseName: activeEntry.name)
                    case "Warmup":   warmupTab
                    default:         overviewTab
                    }
                }
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle(activeEntry.name)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { actionBar }
            .overlay(toastOverlay)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if entry.isCustom {
                        Button("Edit") { showEdit = true }
                            .foregroundColor(.aura.accent)
                    } else {
                        Button {
                            db.toggleFavorite(id: entry.id)
                        } label: {
                            Image(systemName: currentEntry?.isFavorite == true ? "heart.fill" : "heart")
                                .foregroundColor(currentEntry?.isFavorite == true ? .aura.red : .aura.text2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                CreateExerciseView()  // future: pass entry for editing
            }
            .sheet(isPresented: $showAddToPlan) {
                AddToPlanSheet(entry: activeEntry) { msg in flash(msg) }
            }
            .onAppear {
                if selectedTab.isEmpty { selectedTab = tabs.first ?? "Overview" }
                if let ctx = workoutCtx {
                    editSets = ctx.sets
                    editReps = ctx.repRange
                    editRest = ctx.restSeconds
                }
            }
        }
    }

    private var currentEntry: ExerciseEntry? {
        db.entry(id: activeEntry.id)
    }

    // MARK: A/B toggle segment

    @ViewBuilder
    private func abSegment(_ slot: String, _ name: String) -> some View {
        let active = activeSlot == slot
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { activeSlot = slot }
        } label: {
            Text("\(slot) · \(name)")
                .font(AuraFont.jakarta(13, active ? .bold : .medium))
                .foregroundColor(active ? .white : .aura.text2)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(active ? Color.aura.accent : Color.aura.fill)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        }
        .buttonStyle(.plain)
    }

    // MARK: Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast {
            Text(toast)
                .font(AuraFont.jakarta(13, .semibold))
                .foregroundColor(.aura.bg)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.aura.text)
                .clipShape(Capsule())
                .padding(.bottom, 90)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }

    private func flash(_ message: String) {
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { if toast == message { toast = nil } }
        }
    }

    // MARK: Hero
    private var heroSection: some View {
        let e = activeEntry
        return ZStack {
            Color.aura.surface
                .frame(height: 180)
            VStack(spacing: 10) {
                // Playable demo when the link resolves to a YouTube id;
                // "Auto-play video" decides whether it starts on its own or
                // waits behind the thumbnail's Play overlay.
                if YouTubePlayerView.videoID(from: e.youtubeURL) != nil {
                    ExerciseVideoView(youtubeURL: e.youtubeURL,
                                      autoplay: appState.autoPlayVideo,
                                      height: 180)
                } else {
                    // No demo video → cached remote still (falls back to the
                    // muscle-tinted gradient), with the category badge on top.
                    RemoteExerciseImage(urlString: e.imageURL, fallbackMuscle: e.category)
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.28))
                                    .frame(width: 64, height: 64)
                                Text(e.category.prefix(2).uppercased())
                                    .font(AuraFont.jakarta(26, .heavy))
                                    .foregroundColor(.white)
                            }
                        )
                }
            }
        }
    }

    // MARK: Overview tab
    private var overviewTab: some View {
        let e = activeEntry
        return VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            // Info strip
            HStack(spacing: 0) {
                infoCell(label: e.equipment, icon: "dumbbell")
                Divider()
                infoCell(label: e.category, icon: "figure.strengthtraining.traditional")
                Divider()
                infoCell(label: e.difficulty, icon: "star.fill")
                Divider()
                infoCell(label: e.type, icon: "bolt.fill")
            }
            .frame(height: 60)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))

            // Muscle activation
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    Text("Muscles Targeted")
                        .sectionLabelStyle()
                    ForEach(e.musclesTargeted, id: \.self) { muscle in
                        HStack {
                            Text(muscle)
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text)
                                .frame(width: 140, alignment: .leading)
                            AuraProgressBar(value: muscle == e.musclesTargeted.first ? 1.0 : 0.45)
                        }
                    }
                }
                .padding(AuraSpacing.s4)
            }

            // Rep & set defaults
            AuraCard {
                HStack(spacing: AuraSpacing.s4) {
                    statCell(label: "Rep Range", value: e.repRange)
                    Divider()
                    statCell(label: "Default Sets", value: "\(e.plannedSets)")
                    if e.isCable {
                        Divider()
                        statCell(label: "Pulley", value: e.pulley.capitalized)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(AuraSpacing.s4)
            }

            // Pro tip (folded from the old Tips tab).
            if let tip = activeEntry.proTips.first, !tip.isEmpty {
                AuraCard {
                    HStack(alignment: .top, spacing: AuraSpacing.s3) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.aura.accent)
                            .font(AuraFont.jakarta(16))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pro tip")
                                .font(AuraFont.sectionLabel())
                                .foregroundColor(.aura.accent)
                            Text(tip)
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(AuraSpacing.s4)
                    .background(Color.aura.accent.opacity(0.06))
                }
            }

            // Key takeaways = remaining pro tips, numbered.
            if activeEntry.proTips.count > 1 {
                AuraCard {
                    VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                        Text("Key takeaways")
                            .sectionLabelStyle()
                        ForEach(Array(activeEntry.proTips.dropFirst().enumerated()), id: \.offset) { i, tip in
                            HStack(alignment: .top, spacing: AuraSpacing.s3) {
                                Text("\(i + 1)")
                                    .font(AuraFont.jakarta(13, .bold))
                                    .foregroundColor(.aura.accent)
                                    .frame(width: 20, alignment: .leading)
                                Text(tip)
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(AuraSpacing.s4)
                }
            }
        }
        .padding(AuraSpacing.screenPad)
        .padding(.bottom, 40)
    }

    // MARK: Warmup tab
    private var warmupTab: some View {
        let entry = activeEntry
        return VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.aura.accent)
                        Text(entry.warmupProtocol.type)
                            .font(AuraFont.jakarta(15, .bold))
                            .foregroundColor(.aura.text)
                    }

                    if entry.warmupProtocol.steps.isEmpty {
                        Text("No specific warmup required for this exercise. Perform general mobility work before your session.")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    } else {
                        ForEach(entry.warmupProtocol.steps) { step in
                            warmupStepRow(step)
                        }
                    }
                }
                .padding(AuraSpacing.s4)
            }

            // General warmup tip
            AuraCard {
                HStack(alignment: .top, spacing: AuraSpacing.s3) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.aura.accent)
                        .font(AuraFont.jakarta(16))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Warmup Principle")
                            .font(AuraFont.sectionLabel())
                            .foregroundColor(.aura.text3)
                        Text("Always complete warmup sets before working sets. Warmup load should not cause fatigue — it prepares the CNS and joints.")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(AuraSpacing.s4)
            }
        }
        .padding(AuraSpacing.screenPad)
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private func warmupStepRow(_ step: WarmupStep) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            ZStack {
                Circle()
                    .fill(Color.aura.blue.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text("S\(step.set)")
                    .font(AuraFont.jakarta(11, .bold))
                    .foregroundColor(.aura.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(step.intensity)
                        .font(AuraFont.jakarta(13, .bold))
                        .foregroundColor(.aura.text)
                    Spacer()
                    Text("× \(step.reps) reps")
                        .font(AuraFont.jakarta(13, .medium))
                        .foregroundColor(.aura.accent)
                }
                if !step.description.isEmpty {
                    Text(step.description)
                        .font(AuraFont.jakarta(11))
                        .foregroundColor(.aura.text3)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func infoCell(label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(AuraFont.jakarta(14))
                .foregroundColor(.aura.text2)
            Text(label)
                .font(AuraFont.jakarta(11, .medium))
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(AuraFont.jakarta(17, .bold))
                .foregroundColor(.aura.text)
            Text(label)
                .font(AuraFont.jakarta(11))
                .foregroundColor(.aura.text3)
        }
        .frame(maxWidth: .infinity)
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "chest": return .aura.accent
        case "back": return .aura.blue
        case "shoulders": return .aura.purple
        case "arms": return .aura.green
        case "legs": return .aura.red
        case "core": return .aura.accent
        default: return .aura.text2
        }
    }

    // MARK: Workout tab (inline sets/reps/rest editing)

    @ViewBuilder
    private var workoutTab: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                    // Sets stepper.
                    HStack {
                        Text("Sets")
                            .font(AuraFont.body())
                            .foregroundColor(.aura.text)
                        Spacer()
                        AuraStepper(value: $editSets, range: 1...10, format: { "\($0) sets" })
                    }
                    Divider()
                    // Rep range.
                    HStack {
                        Text("Reps")
                            .font(AuraFont.body())
                            .foregroundColor(.aura.text)
                        Spacer()
                        TextField("8–12", text: $editReps)
                            .font(AuraFont.body())
                            .foregroundColor(.aura.text)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                    }
                }
                .padding(AuraSpacing.s4)
            }

            RestLadderPicker(title: "Rest between sets", seconds: restBinding)

            AuraPrimaryButton(label: "Save Changes", icon: "checkmark") {
                let reps = editReps.trimmingCharacters(in: .whitespaces).isEmpty ? "8–12" : editReps
                workoutCtx?.onSave(editSets, reps, editRest)
                dismiss()
            }
        }
        .padding(AuraSpacing.screenPad)
        .padding(.bottom, 40)
    }

    /// Bridges `editRest` (Int) to the `RestLadderPicker` binding.
    private var restBinding: Binding<Int> {
        Binding(get: { editRest }, set: { editRest = $0 })
    }

    // MARK: Library action bar

    @ViewBuilder
    private var actionBar: some View {
        if showActionBar {
            VStack(spacing: AuraSpacing.s2) {
                AuraPrimaryButton(label: "Add to Today's Workout", icon: "plus") {
                    addToTodaysWorkout()
                }
                AuraGrayButton(label: "Add to a Plan") {
                    showAddToPlan = true
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)
            .padding(.bottom, AuraSpacing.s2)
            .background(Color.aura.surface)
        }
    }

    /// Append the active entry to today's workout via a `.edited`/`.added`
    /// DayOverride, mirroring the Log tab's edit flow.
    private func addToTodaysWorkout() {
        let newExercise = ExerciseDatabase.shared.toExercise(activeEntry)
        let iso = AppState.iso(Date())
        var exercises = appState.todayWorkout()?.exercises ?? []
        // If an override already edited today, extend that list instead.
        if let existing = appState.dayInfo(for: Date()).override?.editedExercises {
            exercises = existing
        }
        exercises.append(newExercise)

        let existingKind = appState.dayInfo(for: Date()).override?.kind
        let kind: DayOverride.Kind = (existingKind == .logged) ? .logged : .edited
        let wid = appState.todayWorkout()?.id
        appState.setOverride(
            DayOverride(kind: kind, workoutId: wid, editedExercises: exercises),
            for: iso
        )
        flash("Added to today")
    }
}

// MARK: - Add-to-Plan sheet
//
// Two-step chooser: pick a workout in the default plan, then add the exercise
// as new, or replace one of that workout's exercises (filtered to the same
// primary muscle). Persists through `UserPlanDatabase.updateCustomWorkout`.
struct AddToPlanSheet: View {
    let entry: ExerciseEntry
    let onDone: (String) -> Void

    @StateObject private var planDB = UserPlanDatabase.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pickedWorkout: Workout?

    private var workouts: [Workout] {
        planDB.defaultPlan?.customWorkouts ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if let workout = pickedWorkout {
                    modeStep(for: workout)
                } else {
                    workoutStep
                }
            }
            .background(Color.aura.bgGrouped.ignoresSafeArea())
            .navigationTitle("Add to a Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var workoutStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if workouts.isEmpty {
                    Text("No custom workouts in your plan yet. Create one in My Plans first.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                        .padding(AuraSpacing.screenPad)
                } else {
                    AuraSectionLabel(title: "Choose a workout")
                        .padding(.horizontal, AuraSpacing.screenPad)
                    ForEach(workouts) { w in
                        AuraListRow(title: w.name, subtitle: "\(w.exercises.count) exercises") {
                            pickedWorkout = w
                        }
                        .padding(.horizontal, AuraSpacing.screenPad)
                        Divider().padding(.leading, AuraSpacing.screenPad)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func modeStep(for workout: Workout) -> some View {
        let replaceable = workout.exercises.filter {
            $0.primaryMuscle.lowercased() == entry.primaryMuscleLabel.lowercased()
        }
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                AuraSectionLabel(title: "Add as new exercise")
                    .padding(.horizontal, AuraSpacing.screenPad)
                AuraListRow(iconName: "plus.circle", title: "Append \(entry.name)") {
                    appendToWorkout(workout)
                }
                .padding(.horizontal, AuraSpacing.screenPad)

                if !replaceable.isEmpty {
                    AuraSectionLabel(title: "Replace one")
                        .padding(.horizontal, AuraSpacing.screenPad)
                    ForEach(replaceable) { ex in
                        AuraListRow(title: ex.name, subtitle: "\(ex.plannedSets) sets · \(ex.repRange)") {
                            replaceInWorkout(workout, target: ex)
                        }
                        .padding(.horizontal, AuraSpacing.screenPad)
                        Divider().padding(.leading, AuraSpacing.screenPad)
                    }
                }
            }
            .padding(.top, AuraSpacing.s2)
        }
    }

    private func appendToWorkout(_ workout: Workout) {
        guard let planID = planDB.defaultPlan?.id else { return }
        var updated = workout
        updated.exercises.append(ExerciseDatabase.shared.toExercise(entry))
        planDB.updateCustomWorkout(updated, in: planID)
        onDone("Added to \(workout.name)")
        dismiss()
    }

    private func replaceInWorkout(_ workout: Workout, target: Exercise) {
        guard let planID = planDB.defaultPlan?.id,
              let idx = workout.exercises.firstIndex(where: { $0.id == target.id }) else { return }
        var updated = workout
        var replacement = ExerciseDatabase.shared.toExercise(entry)
        // Carry over the target's planned volume.
        replacement.plannedSets = target.plannedSets
        replacement.repRange = target.repRange
        replacement.supersetGroupID = target.supersetGroupID
        updated.exercises[idx] = replacement
        planDB.updateCustomWorkout(updated, in: planID)
        onDone("Replaced in \(workout.name)")
        dismiss()
    }
}

private extension ExerciseEntry {
    /// Primary muscle label used for the "Replace one" muscle filter — matches
    /// how `ExerciseDatabase.toExercise` derives `Exercise.primaryMuscle`.
    var primaryMuscleLabel: String { musclesTargeted.first ?? category }
}

// MARK: - Legacy Exercise detail (used by active workout, kept for compatibility)
struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) var dismiss
    @StateObject private var db = ExerciseDatabase.shared

    var entry: ExerciseEntry? {
        db.entry(named: exercise.name)
    }

    var body: some View {
        if let e = entry {
            ExerciseEntryDetailView(entry: e)
        } else {
            // Fallback for exercises not in DB
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                        Group {
                            if YouTubePlayerView.videoID(from: exercise.youtubeURL) != nil {
                                ExerciseVideoView(youtubeURL: exercise.youtubeURL, autoplay: false, height: 200)
                            } else {
                                RemoteExerciseImage(urlString: exercise.imageURL, fallbackMuscle: exercise.primaryMuscle)
                                    .frame(height: 200)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))

                        Text(exercise.name).font(AuraFont.cardTitle()).foregroundColor(.aura.text)

                        HStack(spacing: 0) {
                            infoCell(label: exercise.equipment, icon: "dumbbell")
                            Divider()
                            infoCell(label: exercise.primaryMuscle, icon: "figure.strengthtraining.traditional")
                            Divider()
                            infoCell(label: exercise.difficulty, icon: "star.fill")
                        }
                        .frame(height: 60)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))

                        if !exercise.hint.isEmpty {
                            AuraCard {
                                HStack(alignment: .top, spacing: AuraSpacing.s3) {
                                    Image(systemName: "lightbulb.fill").foregroundColor(.aura.accent).font(AuraFont.jakarta(16))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Pro Tip").font(AuraFont.sectionLabel()).foregroundColor(.aura.text3)
                                        Text(exercise.hint).font(AuraFont.secondary()).foregroundColor(.aura.text2).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(AuraSpacing.s4)
                            }
                        }

                        AuraCard {
                            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                                Text("Muscle Activation").sectionLabelStyle()
                                ForEach(exercise.muscleGroups, id: \.self) { group in
                                    HStack {
                                        Text(group).font(AuraFont.secondary()).foregroundColor(.aura.text).frame(width: 100, alignment: .leading)
                                        AuraProgressBar(value: group == exercise.primaryMuscle ? 1.0 : 0.5)
                                    }
                                }
                            }
                            .padding(AuraSpacing.s4)
                        }
                    }
                    .padding(AuraSpacing.screenPad)
                    .padding(.bottom, 40)
                }
                .background(Color.aura.bgGrouped)
                .navigationTitle(exercise.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
    }

    @ViewBuilder
    private func infoCell(label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(AuraFont.jakarta(14)).foregroundColor(.aura.text2)
            Text(label).font(AuraFont.jakarta(11, .medium)).foregroundColor(.aura.text2).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}
