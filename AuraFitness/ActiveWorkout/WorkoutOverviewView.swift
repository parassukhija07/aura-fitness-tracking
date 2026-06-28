import SwiftUI

struct WorkoutOverviewView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: WorkoutSessionState
    @Binding var showEndSheet: Bool
    @State private var showAddExercise = false
    @State private var showExerciseMenu: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button {
                    showEndSheet = true
                } label: {
                    Text("End")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.red)
                }

                Spacer()

                VStack(spacing: 1) {
                    Text(session.workout.name)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                        .lineLimit(1)
                    Text(session.elapsedFormatted)
                        .font(AuraFont.statNum(size: 19))
                        .foregroundColor(.aura.accent)
                        .monospacedDigit()
                }

                Spacer()

                Button {
                    // Minimize – not implemented in this prototype; just dismiss to Log tab
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.aura.text)
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Divider()
            }

            ScrollView {
                VStack(spacing: 12) {
                    // Progress header
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(session.doneSets)/\(session.totalSets) sets")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.aura.text)
                            Spacer()
                            Text(session.workout.program ?? "")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                        AuraProgressBar(value: session.progressFraction)
                    }
                    .padding(.top, 14)

                    // Exercise cards
                    ForEach(Array(session.workout.exercises.enumerated()), id: \.element.id) { idx, exercise in
                        exerciseCard(exercise: exercise, index: idx)
                    }

                    // Action buttons
                    VStack(spacing: 10) {
                        AuraTintedButton(label: "Add Exercise", icon: "plus") {
                            showAddExercise = true
                        }
                        AuraPrimaryButton(label: "Finish Workout", icon: "checkmark") {
                            session.activeView = .summary
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
                .padding(.horizontal, AuraSpacing.screenPad)
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
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func exerciseCard(exercise: Exercise, index: Int) -> some View {
        let doneSets = exercise.sets.filter { $0.done }.count
        let allDone = exercise.isFullyDone

        // Superset connector
        let isSSSecond = index > 0 && session.workout.exercises[index - 1].superset

        VStack(spacing: 0) {
            if isSSSecond {
                HStack {
                    Rectangle()
                        .fill(Color.aura.accentSoft)
                        .frame(height: 2)
                    Text("⚡ SUPERSET")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(.aura.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.aura.accentSoft)
                        .clipShape(Capsule())
                    Rectangle()
                        .fill(Color.aura.accentSoft)
                        .frame(height: 2)
                }
                .padding(.vertical, -2)
            }

            Button {
                if exercise.superset || isSSSecond {
                    let ssIdx = exercise.superset ? index : index - 1
                    session.activeView = .superset(index: ssIdx)
                } else {
                    session.activeView = .exercise(index: index)
                }
            } label: {
                HStack(spacing: AuraSpacing.s3) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16))
                        .foregroundColor(.aura.text3)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(exercise.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.aura.text)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if allDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.aura.green)
                                    .font(.system(size: 20))
                            }
                        }

                        Text("\(exercise.sets.count) sets · \(exercise.repRange) reps · \(exercise.equipment)")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)

                        // Mini progress bar
                        if !exercise.sets.isEmpty {
                            AuraProgressBar(value: Double(doneSets) / Double(exercise.sets.count), height: 4)
                        }
                    }

                    Button {
                        showExerciseMenu = index
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18))
                            .foregroundColor(.aura.text2)
                            .padding(8)
                    }
                }
                .padding(AuraSpacing.s4)
            }
            .buttonStyle(.plain)
            .background(Color.aura.surface)
            .opacity(allDone ? 0.62 : 1.0)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.lg)
                    .stroke(exercise.superset || isSSSecond
                        ? Color.aura.accent.opacity(0.3)
                        : Color.aura.separator.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        }
    }
}

struct IndexWrapper: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - Exercise Picker Sheet (stub for add exercise)
struct ExercisePickerSheet: View {
    let onSelect: (Exercise) -> Void
    @State private var searchText = ""
    @Environment(\.dismiss) var dismiss

    var filtered: [Exercise] {
        let all = ExerciseLibrary.all
        if searchText.isEmpty { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { ex in
                Button {
                    onSelect(ex)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ex.name)
                            .font(AuraFont.body())
                            .foregroundColor(.aura.text)
                        Text("\(ex.primaryMuscle) · \(ex.equipment)")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                }
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
    @State private var showSuperset = false
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

            VStack(spacing: 0) {
                menuRow(icon: "arrow.left.arrow.right", color: .aura.blue, title: "Substitute Exercise") {
                    showSubstitute = true
                }
                Divider().padding(.leading, 56)
                menuRow(icon: "bolt.fill", color: .aura.accent,
                        title: isInSuperset ? "Remove Superset Pairing" : "Create Superset…") {
                    if isInSuperset {
                        session.removeSuperset(at: exerciseIndex)
                        dismiss()
                    } else {
                        showSuperset = true
                    }
                }
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)

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
