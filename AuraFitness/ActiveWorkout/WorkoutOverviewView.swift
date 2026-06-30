import SwiftUI

struct WorkoutOverviewView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: WorkoutSessionState
    @Binding var showEndSheet: Bool
    @State private var showAddExercise = false
    @State private var showExerciseMenu: Int? = nil
    @State private var isReordering = false

    var body: some View {
        VStack(spacing: 0) {
            navBar
            if isReordering {
                reorderList
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        progressHeader
                            .padding(.horizontal, AuraSpacing.screenPad)
                            .padding(.top, AuraSpacing.s4)
                            .padding(.bottom, AuraSpacing.s3)

                        exerciseList

                        actionButtons
                            .padding(.horizontal, AuraSpacing.screenPad)
                            .padding(.top, AuraSpacing.s3)
                            .padding(.bottom, 120)
                    }
                }
            }
        }
        .background(Color.aura.bg)
        .sheet(isPresented: $showAddExercise) {
            ExercisePickerSheet { exercise in
                session.addExercise(exercise)
                showAddExercise = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: Binding<IndexWrapper?>(
            get: { showExerciseMenu.map { IndexWrapper(index: $0) } },
            set: { showExerciseMenu = $0?.index }
        )) { wrapper in
            ExerciseMenuSheet(exerciseIndex: wrapper.index)
                .environmentObject(session)
                .presentationDetents([.fraction(0.58)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Nav bar
    private var navBar: some View {
        HStack {
            Button { showEndSheet = true } label: {
                Text("End")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.aura.red)
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(session.workout.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.aura.text2)
                    .lineLimit(1)
                Text(session.elapsedFormatted)
                    .font(AuraFont.statNum(size: 20))
                    .foregroundColor(.aura.accent)
                    .monospacedDigit()
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isReordering.toggle() }
            } label: {
                Image(systemName: isReordering ? "checkmark" : "arrow.up.arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isReordering ? .aura.accent : .aura.text)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: Progress header
    private var progressHeader: some View {
        VStack(spacing: AuraSpacing.s2) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(session.doneSets) of \(session.totalSets) sets")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.aura.text)
                    if let prog = session.workout.program {
                        Text(prog)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                }
                Spacer()
                // Volume stat
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatVolume(session.totalVolume))
                        .font(AuraFont.statNum(size: 16))
                        .foregroundColor(.aura.text)
                    Text("kg volume")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
            }
            AuraProgressBar(value: session.progressFraction, height: 6)
        }
    }

    // MARK: Exercise list (normal mode)
    private var exerciseList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(session.workout.exercises.enumerated()), id: \.element.id) { idx, exercise in
                let isSSFirst = exercise.superset
                let isSSSecond = idx > 0 && session.workout.exercises[idx - 1].superset

                VStack(spacing: 0) {
                    // Superset connector bar between paired exercises
                    if isSSSecond {
                        supersetConnector
                    } else if idx > 0 {
                        Spacer().frame(height: AuraSpacing.s2)
                    }

                    exerciseCard(exercise: exercise, index: idx, isSSFirst: isSSFirst, isSSSecond: isSSSecond)
                        .padding(.horizontal, AuraSpacing.screenPad)
                }
            }
        }
    }

    // MARK: Superset connector visual
    private var supersetConnector: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: AuraSpacing.screenPad + 16)
            Rectangle()
                .fill(Color.aura.accent.opacity(0.35))
                .frame(width: 2)
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.aura.accent)
                Text("SUPERSET")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.aura.accent)
                    .tracking(0.5)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.aura.accentSoft)
            .clipShape(Capsule())
            Rectangle()
                .fill(Color.aura.accent.opacity(0.35))
                .frame(height: 2)
            Color.clear.frame(width: AuraSpacing.screenPad + 8)
        }
        .frame(height: 24)
    }

    // MARK: Reorder list
    private var reorderList: some View {
        List {
            ForEach(Array(session.workout.exercises.enumerated()), id: \.element.id) { idx, ex in
                HStack(spacing: AuraSpacing.s3) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16))
                        .foregroundColor(.aura.text3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name)
                            .font(AuraFont.body())
                            .foregroundColor(.aura.text)
                        Text("\(ex.sets.count) sets · \(ex.equipment)")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                    Spacer()
                    if ex.isFullyDone {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.aura.green)
                    }
                }
                .listRowBackground(Color.aura.surface)
            }
            .onMove { from, to in session.moveExercise(from: from, to: to) }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: Exercise card
    @ViewBuilder
    private func exerciseCard(exercise: Exercise, index: Int, isSSFirst: Bool, isSSSecond: Bool) -> some View {
        let doneSets = exercise.doneSetsCount
        let allDone = exercise.isFullyDone
        let isSuperset = isSSFirst || isSSSecond
        let accentColor: Color = isSSSecond ? .aura.blue : .aura.accent

        Button {
            if isSuperset {
                let ssIdx = isSSFirst ? index : index - 1
                session.activeView = .superset(index: ssIdx)
            } else {
                session.activeView = .exercise(index: index)
            }
        } label: {
            HStack(spacing: AuraSpacing.s3) {
                // Left accent bar for superset
                if isSuperset {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accentColor)
                        .frame(width: 3)
                        .padding(.vertical, 10)
                }

                VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                if isSuperset {
                                    Text(isSSFirst ? "A" : "B")
                                        .font(.system(size: 10, weight: .heavy))
                                        .foregroundColor(accentColor)
                                        .frame(width: 16, height: 16)
                                        .background(accentColor.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                Text(exercise.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(allDone ? .aura.text2 : .aura.text)
                            }

                            HStack(spacing: 6) {
                                AuraBadge(label: exercise.equipment, color: .aura.text2)
                                Text(exercise.repRange + " reps")
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            if allDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.aura.green)
                            } else {
                                Text("\(doneSets)/\(exercise.sets.count)")
                                    .font(AuraFont.statNum(size: 16))
                                    .foregroundColor(.aura.text)
                            }
                        }
                    }

                    // Progress bar
                    if !exercise.sets.isEmpty {
                        AuraProgressBar(
                            value: Double(doneSets) / Double(exercise.sets.count),
                            color: allDone ? .aura.green : (isSuperset ? accentColor : .aura.accent),
                            height: 4
                        )
                    }

                    // Set summary chips
                    if !exercise.sets.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { i, s in
                                    setChip(set: s, index: i)
                                }
                            }
                        }
                    }
                }

                // Menu button
                Button {
                    showExerciseMenu = index
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.aura.text3)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(AuraSpacing.s3)
        }
        .buttonStyle(.plain)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .stroke(
                    allDone ? Color.aura.green.opacity(0.3)
                        : (isSuperset ? accentColor.opacity(0.3) : Color.aura.separator2),
                    lineWidth: 1
                )
        )
        .opacity(allDone ? 0.75 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: allDone)
    }

    // MARK: Set chips
    private func setChip(set: WorkoutSet, index: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(set.done ? Color.aura.green.opacity(0.15) : Color.aura.fill)
                .frame(width: 38, height: 22)
            if set.done, let w = set.weight, let r = set.reps {
                Text("\(Int(w))×\(r)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.aura.green)
            } else {
                Text("S\(index + 1)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.aura.text3)
            }
        }
    }

    // MARK: Action buttons
    private var actionButtons: some View {
        VStack(spacing: AuraSpacing.s2) {
            AuraTintedButton(label: "Add Exercise", icon: "plus") {
                showAddExercise = true
            }
            AuraPrimaryButton(label: "Finish Workout", icon: "flag.checkered") {
                session.activeView = .summary
            }
        }
    }

    private func formatVolume(_ v: Double) -> String {
        v >= 1000
            ? String(format: "%.1fk", v / 1000)
            : String(format: "%.0f", v)
    }
}

struct IndexWrapper: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Exercise Picker Sheet
struct ExercisePickerSheet: View {
    let onSelect: (Exercise) -> Void
    @StateObject private var db = ExerciseDatabase.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @Environment(\.dismiss) var dismiss

    private let categories = ["All","Chest","Back","Shoulders","Arms","Legs","Core","Cardio","Warm-up"]

    var filtered: [ExerciseEntry] {
        db.filtered(
            category: selectedCategory == "All" ? nil : selectedCategory,
            query: searchText
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AuraSpacing.s2) {
                        ForEach(categories, id: \.self) { cat in
                            AuraChip(label: cat, active: selectedCategory == cat) {
                                selectedCategory = cat
                            }
                        }
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.vertical, AuraSpacing.s2)
                }
                Divider()
                List(filtered) { entry in
                    Button {
                        onSelect(db.toExercise(entry))
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text)
                            Text("\(entry.category) · \(entry.equipment) · \(entry.difficulty)")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                    }
                    .listRowBackground(Color.aura.surface)
                }
                .listStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Exercise Menu Sheet
struct ExerciseMenuSheet: View {
    @EnvironmentObject var session: WorkoutSessionState
    let exerciseIndex: Int
    @State private var showSubstitute = false
    @State private var showSupersetPicker = false
    @State private var showNote = false
    @Environment(\.dismiss) var dismiss

    var exercise: Exercise? {
        session.workout.exercises.indices.contains(exerciseIndex)
            ? session.workout.exercises[exerciseIndex] : nil
    }

    var isInSuperset: Bool {
        guard let e = exercise else { return false }
        return e.superset || (exerciseIndex > 0 && session.workout.exercises[exerciseIndex - 1].superset)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()

            if let ex = exercise {
                VStack(spacing: 4) {
                    Text(ex.name)
                        .font(AuraFont.navTitle())
                        .foregroundColor(.aura.text)
                    Text("Exercise \(exerciseIndex + 1) of \(session.workout.exercises.count)")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                .padding(.vertical, AuraSpacing.s3)
            }

            // Primary actions
            VStack(spacing: 0) {
                menuRow(icon: "arrow.left.arrow.right", color: .aura.blue, title: "Substitute Exercise") {
                    showSubstitute = true
                }
                Divider().padding(.leading, 56)
                menuRow(
                    icon: "bolt.fill", color: .aura.accent,
                    title: isInSuperset ? "Remove Superset" : "Pair as Superset…"
                ) {
                    if isInSuperset {
                        session.removeSuperset(at: exerciseIndex)
                        dismiss()
                    } else {
                        showSupersetPicker = true
                    }
                }
                Divider().padding(.leading, 56)
                menuRow(icon: "note.text", color: .aura.text2, title: "Add Note") {
                    withAnimation { showNote.toggle() }
                }

                if showNote, let _ = exercise {
                    HStack(spacing: AuraSpacing.s2) {
                        Image(systemName: "note.text")
                            .font(.system(size: 13))
                            .foregroundColor(.aura.text3)
                            .frame(width: 36)
                        TextField("Note for this exercise…",
                                  text: Binding(
                                    get: { session.workout.exercises[exerciseIndex].note },
                                    set: { session.workout.exercises[exerciseIndex].note = $0 }
                                  ))
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text)
                        .submitLabel(.done)
                    }
                    .padding(.horizontal, AuraSpacing.s4)
                    .padding(.vertical, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            .animation(.easeInOut(duration: 0.18), value: showNote)

            // Danger zone
            VStack(spacing: 0) {
                menuRow(icon: "trash", color: .aura.red, title: "Remove Exercise", textColor: .aura.red) {
                    session.removeExercise(at: exerciseIndex)
                    dismiss()
                }
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, 12)

            AuraGrayButton(label: "Cancel") { dismiss() }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, 12)
                .padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
        .sheet(isPresented: $showSubstitute) {
            ExercisePickerSheet { replacement in
                session.substituteExercise(at: exerciseIndex, with: replacement)
                showSubstitute = false
                dismiss()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSupersetPicker) {
            SupersetPartnerPicker(sourceIndex: exerciseIndex) { targetIndex in
                session.createSuperset(sourceIndex: exerciseIndex, targetIndex: targetIndex)
                showSupersetPicker = false
                dismiss()
            }
            .environmentObject(session)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func menuRow(icon: String, color: Color, title: String, textColor: Color = .aura.text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(AuraFont.body())
                    .foregroundColor(textColor)
                Spacer()
            }
            .padding(.horizontal, AuraSpacing.s4)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Superset Partner Picker
struct SupersetPartnerPicker: View {
    @EnvironmentObject var session: WorkoutSessionState
    let sourceIndex: Int
    let onSelect: (Int) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let src = session.workout.exercises.indices.contains(sourceIndex)
                    ? session.workout.exercises[sourceIndex] : nil {
                    HStack(spacing: AuraSpacing.s2) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.aura.accent)
                        Text("Pair \"\(src.name)\" with:")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.vertical, AuraSpacing.s2)
                }

                List {
                    ForEach(Array(session.workout.exercises.enumerated()), id: \.element.id) { idx, ex in
                        if idx != sourceIndex {
                            Button {
                                onSelect(idx)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name)
                                            .font(AuraFont.body())
                                            .foregroundColor(.aura.text)
                                        Text("\(ex.sets.count) sets · \(ex.equipment)")
                                            .font(AuraFont.secondary())
                                            .foregroundColor(.aura.text2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.aura.text3)
                                }
                            }
                            .listRowBackground(Color.aura.surface)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .background(Color.aura.bg)
            .navigationTitle("Pick Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
