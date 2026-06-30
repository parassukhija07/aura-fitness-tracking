import SwiftUI

<<<<<<< HEAD
// MARK: - SupersetView
=======
/// Round-based superset logging, matching the design's SupersetView:
/// progress header, A/B meta strips, per-round cards (A row + B row),
/// add round, per-exercise notes, complete.
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
struct SupersetView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: WorkoutSessionState
    let supersetIndex: Int

    @State private var showMenu = false
<<<<<<< HEAD
    @State private var showDetailA = false
    @State private var showDetailB = false
=======
    @State private var modal: WorkoutModal? = nil
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753

    private var idxA: Int { supersetIndex }
    private var idxB: Int { supersetIndex + 1 }

    private var exA: Exercise? {
        session.workout.exercises.indices.contains(idxA) ? session.workout.exercises[idxA] : nil
    }
    private var exB: Exercise? {
        session.workout.exercises.indices.contains(idxB) ? session.workout.exercises[idxB] : nil
    }

    var roundCount: Int {
        max(exA?.sets.count ?? 0, exB?.sets.count ?? 0)
    }

    var body: some View {
<<<<<<< HEAD
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
=======
        if let a = exA, let b = exB {
            content(a: a, b: b)
        } else {
            Color.aura.bg.ignoresSafeArea()
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
        }
    }

    @ViewBuilder
    private func content(a: Exercise, b: Exercise) -> some View {
        let rounds = max(a.sets.count, b.sets.count)
        let totalDone = a.sets.filter { $0.done }.count + b.sets.filter { $0.done }.count
        let totalSets = a.sets.count + b.sets.count

        VStack(spacing: 0) {
            navBar
<<<<<<< HEAD
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
=======
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Progress header
                    HStack {
                        Text("\(totalDone)/\(totalSets) sets")
                            .font(.system(size: 15, weight: .heavy)).foregroundColor(.aura.text)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill").font(.system(size: 12))
                            Text("\(rounds) rounds").font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.aura.accent)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(Color.aura.accentSoft).clipShape(Capsule())
                    }
                    .padding(.top, 14).padding(.bottom, 6)

                    AuraProgressBar(value: totalSets == 0 ? 0 : Double(totalDone) / Double(totalSets))
                        .padding(.bottom, 14)

                    // A / B meta strips
                    exMeta(a, color: .aura.accent, letter: "A")
                    exMeta(b, color: .aura.blue, letter: "B")
                        .padding(.bottom, 4)

                    // Rounds
                    ForEach(0..<rounds, id: \.self) { r in
                        roundCard(roundIndex: r, a: a, b: b)
                            .padding(.bottom, 10)
                    }

                    // Add round
                    Button { addRound() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 15, weight: .semibold))
                            Text("Add Round").font(.system(size: 15, weight: .bold))
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
                        }
                        .foregroundColor(.aura.accent)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color.aura.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                    }
<<<<<<< HEAD
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s3)
=======
                    .buttonStyle(.plain)

                    // Notes (per exercise)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes").sectionLabelStyle()
                        noteField(placeholder: "\(a.name)…", index: idxA)
                        noteField(placeholder: "\(b.name)…", index: idxB)
                    }
                    .padding(.top, 20)

                    AuraPrimaryButton(label: "Complete Superset", icon: "checkmark") {
                        completeSuperset()
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, AuraSpacing.screenPad)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
                .padding(.bottom, 120)
            }
        }
        .background(Color.aura.bg)
        .sheet(isPresented: $showMenu) {
            ExerciseMenuSheet(exerciseIndex: idxA, onModal: { m in
                showMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { modal = m }
            })
                .environmentObject(session)
                .presentationDetents([.fraction(0.6)])
                .presentationDragIndicator(.visible)
        }
<<<<<<< HEAD
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
=======
        .sheet(item: $modal) { m in
            WorkoutModalsView(modal: m, presented: $modal)
                .environmentObject(session)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
        }
    }

    // MARK: Nav bar
<<<<<<< HEAD
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
=======

    private var navBar: some View {
        HStack {
            Button { session.activeView = .overview } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.aura.accent)
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill").font(.system(size: 15))
                Text("Superset").font(.system(size: 16, weight: .heavy))
            }
            .foregroundColor(.aura.accent)
            Spacer()
            Button { showMenu = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 20))
                    .foregroundColor(.aura.text)
                    .frame(width: 34, height: 34)
                    .background(Color.aura.fill.opacity(0.5))
                    .clipShape(Circle())
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

<<<<<<< HEAD
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
=======
    // MARK: Exercise meta strip (PR + Target)

    private func exMeta(_ ex: Exercise, color: Color, letter: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Text(letter)
                    .font(.system(size: 8, weight: .heavy)).foregroundColor(.white)
                    .frame(width: 15, height: 15).background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(ex.name)
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.aura.text)
                    .lineLimit(1)
            }
            HStack(spacing: 0) {
                metaCell(label: "🏆 PR",
                         value: ex.lastPR.map { "\(fmt($0.weight)) kg × \($0.reps)" } ?? "—",
                         sub: ex.lastPR?.date ?? "—",
                         tint: false)
                    .overlay(Divider(), alignment: .trailing)
                metaCell(label: "🎯 Target",
                         value: ex.target.map { "\(fmt($0.weight)) kg × \($0.reps)" } ?? "—",
                         sub: ex.target?.note ?? "",
                         tint: true)
            }
            .background(Color.aura.fill.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.sm).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        }
        .padding(9)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        .padding(.bottom, 8)
    }

    private func metaCell(label: String, value: String, sub: String, tint: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(tint ? .aura.accent : .aura.text3)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(tint ? .aura.accent : .aura.text)
                .lineLimit(1)
            Text(sub)
                .font(.system(size: 9))
                .foregroundColor(tint ? .aura.accent.opacity(0.7) : .aura.text3)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(tint ? Color.aura.accentSoft : Color.clear)
    }

    // MARK: Round card

    private func roundCard(roundIndex r: Int, a: Exercise, b: Exercise) -> some View {
        let sa = r < a.sets.count ? a.sets[r] : nil
        let sb = r < b.sets.count ? b.sets[r] : nil
        let roundDone = (sa?.done ?? false) && (sb?.done ?? false)
        let progress = (sa?.done == true ? 1 : 0) + (sb?.done == true ? 1 : 0)

        return VStack(spacing: 0) {
            // Header
            HStack {
                Text("Round \(r + 1)").font(.system(size: 13, weight: .bold)).foregroundColor(.aura.text)
                Spacer()
                if roundDone {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.aura.green).font(.system(size: 18))
                } else {
                    Text("\(progress)/2 done").font(.system(size: 11, weight: .semibold)).foregroundColor(.aura.text3)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(roundDone ? Color.aura.green.opacity(0.07) : Color.clear)
            .overlay(Divider(), alignment: .bottom)

            // A row
            if r < a.sets.count {
                roundExRow(exerciseIndex: idxA, setIndex: r, letter: "A", color: .aura.accent, name: a.name)
            }
            // B row
            if r < b.sets.count {
                roundExRow(exerciseIndex: idxB, setIndex: r, letter: "B", color: .aura.blue, name: b.name)
                    .overlay(Divider(), alignment: .top)
            }
        }
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .stroke(roundDone ? Color.aura.green.opacity(0.35) : Color.aura.separator.opacity(0.5), lineWidth: 1)
        )
    }

    private func roundExRow(exerciseIndex: Int, setIndex: Int, letter: String, color: Color, name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Text(letter)
                    .font(.system(size: 9, weight: .heavy)).foregroundColor(.white)
                    .frame(width: 16, height: 16).background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(name).font(.system(size: 12, weight: .bold)).foregroundColor(.aura.text).lineLimit(1)
            }
            SupersetSetRow(
                exerciseIndex: exerciseIndex,
                setIndex: setIndex,
                set: Binding(
                    get: { session.workout.exercises[exerciseIndex].sets[setIndex] },
                    set: { session.workout.exercises[exerciseIndex].sets[setIndex] = $0 }
                ),
                history: setIndex < session.workout.exercises[exerciseIndex].history.count
                    ? session.workout.exercises[exerciseIndex].history[setIndex] : nil
            )
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: Notes

    private func noteField(placeholder: String, index: Int) -> some View {
        TextField(placeholder, text: Binding(
            get: { session.workout.exercises[index].note },
            set: { session.workout.exercises[index].note = $0 }
        ), axis: .vertical)
            .font(.system(size: 14))
            .foregroundColor(.aura.text)
            .lineLimit(2, reservesSpace: true)
            .padding(13)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
    }

    // MARK: Actions

    private func addRound() {
        session.workout.exercises[idxA].sets.append(WorkoutSet())
        session.workout.exercises[idxB].sets.append(WorkoutSet())
    }

    private func completeSuperset() {
        for idx in [idxA, idxB] {
            guard session.workout.exercises.indices.contains(idx) else { continue }
            session.workout.exercises[idx].sets.removeAll { $0.weight == nil && $0.reps == nil && !$0.done }
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
            for i in session.workout.exercises[idx].sets.indices {
                let s = session.workout.exercises[idx].sets[i]
                if s.weight != nil && s.reps != nil {
                    session.workout.exercises[idx].sets[i].done = true
                }
            }
            session.workout.exercises[idx].completed = true
        }
<<<<<<< HEAD
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
=======
        session.triggerCelebration(emoji: "💪", title: "Superset done", message: "Both exercises logged. Keep going.")
        // Complete Superset rest = the default-rest tweak (Profile "Rest Between Sets"),
        // not the hard 60s used for per-side set completion.
        session.startRest(duration: appState.defaultRestBetweenSets)
        session.activeView = .overview
    }

    private func fmt(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}

// MARK: - Superset set row (number is static; no type button)

struct SupersetSetRow: View {
    @EnvironmentObject var session: WorkoutSessionState
    let exerciseIndex: Int
    let setIndex: Int
    @Binding var set: WorkoutSet
    var history: SetHistory? = nil

    @State private var weightText = ""
    @State private var repsText = ""

    private var filled: Bool { !weightText.isEmpty && !repsText.isEmpty }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 9) {
                Text("\(setIndex + 1)")
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.aura.text2)
                    .frame(width: 40, height: 48)
                    .background(Color.aura.fill).clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                input($weightText, placeholder: history?.weight ?? "–", label: "kg") {
                    set.weight = Double(weightText); finish()
                }
                input($repsText, placeholder: history?.reps ?? "–", label: "reps") {
                    set.reps = Int(repsText); finish()
                }
                Button { toggle() } label: {
                    Image(systemName: "checkmark").font(.system(size: 16, weight: .bold))
                        .foregroundColor(set.done ? .white : .aura.text3)
                        .frame(width: 48, height: 48)
                        .background(set.done ? Color.aura.green : Color.aura.fill)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                }.buttonStyle(.plain)
                Button {
                    session.onDeleteSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                } label: {
                    Image(systemName: "trash").font(.system(size: 16)).foregroundColor(.aura.red)
                        .frame(width: 48, height: 48)
                        .background(Color.aura.red.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                }.buttonStyle(.plain)
            }
            if let h = history {
                HStack(spacing: 9) {
                    Color.clear.frame(width: 40)
                    Text("\(h.weight) kg").font(.system(size: 11, weight: .bold)).foregroundColor(.aura.text3).frame(maxWidth: .infinity)
                    Text("\(h.reps) reps").font(.system(size: 11, weight: .bold)).foregroundColor(.aura.text3).frame(maxWidth: .infinity)
                    Color.clear.frame(width: 48)
                    Color.clear.frame(width: 48)
                }
            }
        }
        .onAppear {
            weightText = set.weight.map { $0.truncatingRemainder(dividingBy: 1) == 0 ? String(Int($0)) : String($0) } ?? ""
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
            repsText = set.reps.map { String($0) } ?? ""
        }
    }

<<<<<<< HEAD
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
=======
    private func input(_ text: Binding<String>, placeholder: String, label: String, onChange: @escaping () -> Void) -> some View {
        VStack(spacing: -2) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad).multilineTextAlignment(.center)
                .font(.system(size: 18, weight: .heavy)).foregroundColor(.aura.text)
                .onChange(of: text.wrappedValue) { _, _ in onChange() }
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.aura.text3).textCase(.uppercase)
        }
        .frame(maxWidth: .infinity).frame(height: 48)
        .background(set.done ? Color.aura.green.opacity(0.09) : Color.aura.surface2)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.sm).stroke(set.done ? Color.aura.green.opacity(0.22) : Color.aura.separator.opacity(0.5), lineWidth: 1))
    }

    private func finish() {
        guard !set.done, filled else { return }
        session.onSupersetSetDone(exerciseIndex: exerciseIndex, setIndex: setIndex)
    }
    private func toggle() {
        if set.done { set.done = false }
        else { set.weight = Double(weightText); set.reps = Int(repsText)
            session.onSupersetSetDone(exerciseIndex: exerciseIndex, setIndex: setIndex) }
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
    }
}
