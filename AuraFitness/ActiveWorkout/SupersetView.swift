import SwiftUI

// MARK: - SupersetView
struct SupersetView: View {
    @EnvironmentObject var session: WorkoutSessionState
    let supersetIndex: Int

    @State private var showMenu = false
    @State private var showDetailA = false
    @State private var showDetailB = false

    var exA: Exercise? {
        session.workout.exercises.indices.contains(supersetIndex)
            ? session.workout.exercises[supersetIndex] : nil
    }
    var exB: Exercise? {
        session.workout.exercises.indices.contains(supersetIndex + 1)
            ? session.workout.exercises[supersetIndex + 1] : nil
    }

    var roundCount: Int {
        max(exA?.sets.count ?? 0, exB?.sets.count ?? 0)
    }

    var body: some View {
        guard let a = exA, let b = exB else {
            return AnyView(
                VStack {
                    Spacer()
                    Text("Superset not found")
                        .foregroundColor(.aura.text2)
                    Spacer()
                }
                .background(Color.aura.bg)
            )
        }
        return AnyView(content(exA: a, exB: b))
    }

    @ViewBuilder
    private func content(exA: Exercise, exB: Exercise) -> some View {
        VStack(spacing: 0) {
            navBar
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    // Exercise meta cards side by side
                    HStack(spacing: AuraSpacing.s3) {
                        exMetaCard(ex: exA, label: "A", color: .aura.accent, idx: supersetIndex, showDetail: $showDetailA)
                        exMetaCard(ex: exB, label: "B", color: .aura.blue, idx: supersetIndex + 1, showDetail: $showDetailB)
                    }

                    // Round cards
                    ForEach(0..<roundCount, id: \.self) { round in
                        RoundCard(
                            round: round,
                            supersetIndex: supersetIndex,
                            labelA: exA.name,
                            labelB: exB.name
                        )
                        .environmentObject(session)
                    }

                    // Actions
                    HStack(spacing: AuraSpacing.s3) {
                        AuraTintedButton(label: "Add Round", icon: "plus") {
                            if supersetIndex < session.workout.exercises.count {
                                session.workout.exercises[supersetIndex].sets.append(WorkoutSet())
                            }
                            if supersetIndex + 1 < session.workout.exercises.count {
                                session.workout.exercises[supersetIndex + 1].sets.append(WorkoutSet())
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        AuraPrimaryButton(label: "Complete", icon: "checkmark") {
                            completeSuperset()
                        }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s3)
                .padding(.bottom, 120)
            }
        }
        .background(Color.aura.bg)
        .sheet(isPresented: $showMenu) {
            ExerciseMenuSheet(exerciseIndex: supersetIndex)
                .environmentObject(session)
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDetailA) {
            if let entry = ExerciseDatabase.shared.entry(named: exA.name) {
                ExerciseEntryDetailView(entry: entry)
            } else {
                ExerciseDetailView(exercise: exA)
            }
        }
        .sheet(isPresented: $showDetailB) {
            if let entry = ExerciseDatabase.shared.entry(named: exB.name) {
                ExerciseEntryDetailView(entry: entry)
            } else {
                ExerciseDetailView(exercise: exB)
            }
        }
    }

    // MARK: Nav bar
    private var navBar: some View {
        HStack {
            Button { session.activeView = .overview } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Overview")
                        .font(AuraFont.body())
                }
                .foregroundColor(.aura.accent)
                .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.aura.accent)
                Text("Superset")
                    .font(AuraFont.navTitle())
                    .foregroundColor(.aura.text)
            }

            Spacer()

            Button { showMenu = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(.aura.text)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: Exercise meta card (header)
    @ViewBuilder
    private func exMetaCard(ex: Exercise, label: String, color: Color, idx: Int, showDetail: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: 22, height: 22)
                    Text(label)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                }
                Button { showDetail.wrappedValue = true } label: {
                    HStack(spacing: 3) {
                        Text(ex.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.aura.text)
                            .lineLimit(1)
                        Image(systemName: "arrow.up.right.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.aura.text3)
                    }
                }
                .buttonStyle(.plain)
            }

            AuraProgressBar(
                value: ex.sets.isEmpty ? 0 : Double(ex.doneSetsCount) / Double(ex.sets.count),
                color: color,
                height: 4
            )

            HStack {
                // PR
                if let pr = ex.lastPR {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("PR")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.aura.text3)
                            .tracking(0.3)
                        Text("\(formatW(pr.weight))kg × \(pr.reps)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.aura.text)
                    }
                }
                Spacer()
                // Sets done
                Text("\(ex.doneSetsCount)/\(ex.sets.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }
        }
        .padding(AuraSpacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md)
            .stroke(color.opacity(0.35), lineWidth: 1))
    }

    // MARK: Complete superset
    private func completeSuperset() {
        for idx in [supersetIndex, supersetIndex + 1] {
            guard session.workout.exercises.indices.contains(idx) else { continue }
            session.workout.exercises[idx].sets.removeAll { !$0.done && $0.weight == nil && $0.reps == nil }
            for i in session.workout.exercises[idx].sets.indices {
                let s = session.workout.exercises[idx].sets[i]
                if s.weight != nil && s.reps != nil {
                    session.workout.exercises[idx].sets[i].done = true
                }
            }
            session.workout.exercises[idx].completed = true
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        session.triggerCelebration(emoji: "⚡", title: "Superset done",
            message: "Both exercises logged. On to the next.")
        session.startRest(duration: 90)
        session.activeView = .overview
    }

    private func formatW(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - RoundCard
private struct RoundCard: View {
    @EnvironmentObject var session: WorkoutSessionState
    let round: Int
    let supersetIndex: Int
    let labelA: String
    let labelB: String

    var isDone: Bool {
        let aIdx = supersetIndex
        let bIdx = supersetIndex + 1
        let aDone = session.workout.exercises.indices.contains(aIdx)
            && session.workout.exercises[aIdx].sets.indices.contains(round)
            && session.workout.exercises[aIdx].sets[round].done
        let bDone = session.workout.exercises.indices.contains(bIdx)
            && session.workout.exercises[bIdx].sets.indices.contains(round)
            && session.workout.exercises[bIdx].sets[round].done
        return aDone && bDone
    }

    var body: some View {
        VStack(spacing: 0) {
            // Round header
            HStack {
                HStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(isDone ? Color.aura.green : Color.aura.fill)
                            .frame(width: 26, height: 26)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        } else {
                            Text("\(round + 1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.aura.text2)
                        }
                    }
                    Text("Round \(round + 1)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isDone ? .aura.green : .aura.text)
                }
                Spacer()
                if isDone {
                    Text("Done")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.aura.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.aura.green.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, AuraSpacing.s3)
            .padding(.top, AuraSpacing.s3)
            .padding(.bottom, AuraSpacing.s2)

            Divider()

            // Exercise A set row
            if session.workout.exercises.indices.contains(supersetIndex),
               session.workout.exercises[supersetIndex].sets.indices.contains(round) {
                SSSetRow(
                    label: "A",
                    name: labelA,
                    color: .aura.accent,
                    exerciseIndex: supersetIndex,
                    setIndex: round
                )
                .environmentObject(session)
            }

            // Connector between A and B
            HStack(spacing: 0) {
                Color.aura.accentSoft.frame(width: 2).padding(.leading, 28)
                Spacer()
            }
            .frame(height: 14)

            // Exercise B set row
            if session.workout.exercises.indices.contains(supersetIndex + 1),
               session.workout.exercises[supersetIndex + 1].sets.indices.contains(round) {
                SSSetRow(
                    label: "B",
                    name: labelB,
                    color: .aura.blue,
                    exerciseIndex: supersetIndex + 1,
                    setIndex: round
                )
                .environmentObject(session)
            }

            Spacer().frame(height: AuraSpacing.s2)
        }
        .background(isDone ? Color.aura.green.opacity(0.05) : Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md)
            .stroke(isDone ? Color.aura.green.opacity(0.3) : Color.aura.separator2, lineWidth: 1))
        .animation(.easeInOut(duration: 0.2), value: isDone)
    }
}

// MARK: - SSSetRow (compact superset set row)
private struct SSSetRow: View {
    @EnvironmentObject var session: WorkoutSessionState
    let label: String
    let name: String
    let color: Color
    let exerciseIndex: Int
    let setIndex: Int

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    private var set: WorkoutSet {
        guard session.workout.exercises.indices.contains(exerciseIndex),
              session.workout.exercises[exerciseIndex].sets.indices.contains(setIndex)
        else { return WorkoutSet() }
        return session.workout.exercises[exerciseIndex].sets[setIndex]
    }

    var body: some View {
        HStack(spacing: AuraSpacing.s2) {
            // Label badge
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Text(label)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundColor(color)
            }
            .frame(width: 44)

            // Name (truncated)
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.aura.text2)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Weight
            TextField("–", text: $weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(AuraFont.statNum(size: 16))
                .foregroundColor(set.done ? .aura.green : .aura.text)
                .focused($weightFocused)
                .frame(width: 64, height: 36)
                .background(set.done ? Color.aura.green.opacity(0.1) : Color.aura.surface2)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                .onChange(of: weightText) { _, v in
                    writeWeight(Double(v.replacingOccurrences(of: ",", with: ".")))
                }

            Text("×")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(.aura.text3)
                .frame(width: 12)

            // Reps
            TextField("–", text: $repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(AuraFont.statNum(size: 16))
                .foregroundColor(set.done ? .aura.green : .aura.text)
                .focused($repsFocused)
                .frame(width: 52, height: 36)
                .background(set.done ? Color.aura.green.opacity(0.1) : Color.aura.surface2)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                .onChange(of: repsText) { _, v in
                    writeReps(Int(v))
                }

            // Done button
            Button { toggleDone() } label: {
                ZStack {
                    Circle()
                        .fill(set.done ? Color.aura.green : Color.aura.fill)
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(set.done ? .white : .aura.text3)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AuraSpacing.s3)
        .padding(.vertical, 4)
        .onAppear {
            weightText = set.weight.map { formatW($0) } ?? ""
            repsText = set.reps.map { String($0) } ?? ""
        }
    }

    private func writeWeight(_ v: Double?) {
        guard session.workout.exercises.indices.contains(exerciseIndex),
              session.workout.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        session.workout.exercises[exerciseIndex].sets[setIndex].weight = v
    }

    private func writeReps(_ v: Int?) {
        guard session.workout.exercises.indices.contains(exerciseIndex),
              session.workout.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        session.workout.exercises[exerciseIndex].sets[setIndex].reps = v
    }

    private func toggleDone() {
        guard session.workout.exercises.indices.contains(exerciseIndex),
              session.workout.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        let current = session.workout.exercises[exerciseIndex].sets[setIndex].done
        if current {
            session.workout.exercises[exerciseIndex].sets[setIndex].done = false
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
            session.workout.exercises[exerciseIndex].sets[setIndex].weight =
                Double(weightText.replacingOccurrences(of: ",", with: "."))
            session.workout.exercises[exerciseIndex].sets[setIndex].reps = Int(repsText)
            session.onSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            weightFocused = false
            repsFocused = false
        }
    }

    private func formatW(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}
