import SwiftUI

struct WorkoutOverviewView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: WorkoutSessionState
    @Binding var showEndSheet: Bool

    @State private var exerciseMenu: Int? = nil
    @State private var modal: WorkoutModal? = nil

    var body: some View {
        Group {
            if session.workout.exercises.isEmpty {
                EmptyOverviewView(showEndSheet: $showEndSheet,
                                  onAdd: { modal = .addExercise(forSupersetExIdx: nil) })
            } else {
                populatedOverview
            }
        }
        // Per-exercise ⋯ menu
        .sheet(item: Binding<IndexWrapper?>(
            get: { exerciseMenu.map { IndexWrapper(index: $0) } },
            set: { exerciseMenu = $0?.index }
        )) { wrapper in
            ExerciseMenuSheet(exerciseIndex: wrapper.index, onModal: { m in
                exerciseMenu = nil
                // Defer so the menu sheet fully dismisses before presenting the next.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { modal = m }
            })
            .environmentObject(session)
            .presentationDetents([.fraction(0.6)])
            .presentationDragIndicator(.visible)
        }
        // Substitute / create-superset / remove-superset / add modals
        .sheet(item: $modal) { m in
            WorkoutModalsView(modal: m, presented: $modal)
                .environmentObject(session)
        }
    }

    // MARK: Populated overview

    private var populatedOverview: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    progressHeader
                    ForEach(Array(session.workout.exercises.enumerated()), id: \.element.id) { idx, exercise in
                        exerciseCard(exercise: exercise, index: idx)
                    }
                    VStack(spacing: 10) {
                        AuraTintedButton(label: "Add Exercise", icon: "plus") {
                            modal = .addExercise(forSupersetExIdx: nil)
                        }
                        AuraPrimaryButton(label: "Finish Workout", icon: "checkmark") {
                            session.activeView = .summary
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, 14)
            }
        }
        .background(Color.aura.bg)
    }

    private var navBar: some View {
        HStack {
            Button { showEndSheet = true } label: {
                Text("End").font(AuraFont.body()).foregroundColor(.aura.red)
            }
            Spacer()
            VStack(spacing: 1) {
                Text(session.workout.name).font(.system(size: 12, weight: .bold)).foregroundColor(.aura.text2).lineLimit(1)
                Text(session.elapsedFormatted)
                    .font(AuraFont.statNum(size: 19)).foregroundColor(.aura.accent).monospacedDigit()
            }
            Spacer()
            Button { appState.minimizeWorkout() } label: {
                Image(systemName: "minus").font(.system(size: 22, weight: .medium)).foregroundColor(.aura.text)
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(session.doneSets)/\(session.totalSets) sets")
                    .font(.system(size: 15, weight: .heavy)).foregroundColor(.aura.text)
                Spacer()
                Text(session.workout.program ?? "").font(AuraFont.secondary()).foregroundColor(.aura.text2)
            }
            AuraProgressBar(value: session.progressFraction)
        }
    }

    // MARK: Exercise card

    @ViewBuilder
    private func exerciseCard(exercise: Exercise, index: Int) -> some View {
        let doneSets = exercise.sets.filter { $0.done }.count
        let allDone = exercise.isFullyDone
        let isSSSecond = index > 0
            && exercise.supersetGroupID != nil
            && session.workout.exercises[index - 1].supersetGroupID == exercise.supersetGroupID
        let isSSFirst = exercise.supersetGroupID != nil && !isSSSecond

        VStack(spacing: 0) {
            if isSSSecond { supersetConnector }

            HStack(spacing: AuraSpacing.s3) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18)).foregroundColor(.aura.text3)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // Tapping the name opens the exercise (design opens detail)
                        Button {
                            openExercise(index: index, isSSFirst: isSSFirst, isSSSecond: isSSSecond)
                        } label: {
                            Text(exercise.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.aura.text)
                                .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        if allDone {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.aura.green).font(.system(size: 20))
                        }
                    }

                    HStack(spacing: 6) {
                        Text("\(exercise.sets.count) sets · \(exercise.repRange) reps · \(exercise.equipment)")
                            .font(AuraFont.secondary()).foregroundColor(.aura.text2)
                        if isSSFirst {
                            HStack(spacing: 3) {
                                Image(systemName: "bolt.fill").font(.system(size: 9))
                                Text("SS").font(.system(size: 10, weight: .heavy))
                            }
                            .foregroundColor(.aura.accent)
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.aura.accentSoft).clipShape(Capsule())
                        }
                    }

                    if !exercise.sets.isEmpty {
                        AuraProgressBar(value: Double(doneSets) / Double(exercise.sets.count), height: 5)
                    }
                }

                Button { exerciseMenu = index } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20)).foregroundColor(.aura.text2)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
            }
            .padding(AuraSpacing.s4)
            .contentShape(Rectangle())
            .onTapGesture { openExercise(index: index, isSSFirst: isSSFirst, isSSSecond: isSSSecond) }
            .background(Color.aura.surface)
            .opacity(allDone ? 0.62 : 1.0)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.lg)
                    .stroke(isSSFirst || isSSSecond ? Color.aura.accent.opacity(0.3) : Color.aura.separator.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
            .contextMenu {
                Button {
                    if index > 0 { session.moveExercise(from: IndexSet(integer: index), to: index - 1) }
                } label: { Label("Move Up", systemImage: "arrow.up") }
                Button {
                    if index < session.workout.exercises.count - 1 {
                        session.moveExercise(from: IndexSet(integer: index), to: index + 2)
                    }
                } label: { Label("Move Down", systemImage: "arrow.down") }
            }
        }
    }

    private var supersetConnector: some View {
        HStack(spacing: 8) {
            Rectangle().fill(Color.aura.accentSoft).frame(height: 2)
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill").font(.system(size: 11))
                Text("SUPERSET").font(.system(size: 10, weight: .heavy)).tracking(0.5)
            }
            .foregroundColor(.aura.accent)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Color.aura.accentSoft).clipShape(Capsule())
            Rectangle().fill(Color.aura.accentSoft).frame(height: 2)
        }
        .padding(.vertical, 2)
    }

    private func openExercise(index: Int, isSSFirst: Bool, isSSSecond: Bool) {
        if isSSFirst || isSSSecond {
            session.activeView = .superset(index: isSSFirst ? index : index - 1)
        } else {
            session.activeView = .exercise(index: index)
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

// MARK: - Exercise Menu Sheet (ex-menu-ov)

struct ExerciseMenuSheet: View {
    @EnvironmentObject var session: WorkoutSessionState
    let exerciseIndex: Int
    /// Optional hook so the parent can present a follow-on modal after dismiss.
    var onModal: ((WorkoutModal) -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    var exercise: Exercise? {
        session.workout.exercises.indices.contains(exerciseIndex)
            ? session.workout.exercises[exerciseIndex] : nil
    }
    var isInSuperset: Bool {
        exercise?.supersetGroupID != nil
    }

    @State private var showNote = false

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            if let ex = exercise {
                VStack(spacing: 2) {
                    Text(ex.name).font(.system(size: 15, weight: .bold)).foregroundColor(.aura.text)
                    Text("Exercise \(exerciseIndex + 1) of \(session.workout.exercises.count)")
                        .font(AuraFont.secondary()).foregroundColor(.aura.text2)
                }
                .padding(.vertical, AuraSpacing.s3)
            }

            // Primary actions
            VStack(spacing: 0) {
                menuRow(icon: "arrow.left.arrow.right", color: .aura.blue, title: "Substitute Exercise") {
                    triggerModal(.substitute(exIdx: exerciseIndex))
                }
                Divider().padding(.leading, 56)
                menuRow(icon: "bolt.fill", color: .aura.accent,
                        title: isInSuperset ? "Remove Superset Pairing" : "Create Superset…") {
                    triggerModal(isInSuperset
                        ? .removeSuperset(exIdx: supersetAnchor)
                        : .createSuperset(exIdx: exerciseIndex))
                }
                Divider().padding(.leading, 56)
                menuRow(icon: "plus.circle.fill", color: .aura.green, title: "Add Exercise After") {
                    triggerModal(.addExercise(forSupersetExIdx: nil))
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
            .background(Color.aura.surface).clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            .animation(.easeInOut(duration: 0.18), value: showNote)

            // Danger zone
            VStack(spacing: 0) {
                menuRow(icon: "trash", color: .aura.red, title: "Remove Exercise", textColor: .aura.red) {
                    session.removeExercise(at: exerciseIndex)
                    dismiss()
                }
            }
            .background(Color.aura.surface).clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad).padding(.top, 12)

            AuraGrayButton(label: "Cancel") { dismiss() }
                .padding(.horizontal, AuraSpacing.screenPad).padding(.top, 12).padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
    }

    /// The first exercise of the superset pair (for remove confirmation).
    private var supersetAnchor: Int {
        guard let e = exercise, let gid = e.supersetGroupID else { return exerciseIndex }
        if exerciseIndex > 0, session.workout.exercises[exerciseIndex - 1].supersetGroupID == gid {
            return exerciseIndex - 1
        }
        return exerciseIndex
    }

    private func triggerModal(_ m: WorkoutModal) {
        if let onModal {
            onModal(m)
        } else {
            dismiss()
        }
    }

    private func menuRow(icon: String, color: Color, title: String, textColor: Color = .aura.text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundColor(color)
                }
                Text(title).font(AuraFont.body()).foregroundColor(textColor)
                Spacer()
            }
            .padding(.horizontal, AuraSpacing.s4).padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Picker (kept for compatibility; library search)

struct ExercisePickerSheet: View {
    let onSelect: (Exercise) -> Void
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss

    var filtered: [Exercise] {
        let all = ExerciseLibrary.all
        return searchText.isEmpty ? all : all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { ex in
                Button { onSelect(ex) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name).font(AuraFont.body()).foregroundColor(.aura.text)
                        Text("\(ex.primaryMuscle) · \(ex.equipment)").font(AuraFont.secondary()).foregroundColor(.aura.text2)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
