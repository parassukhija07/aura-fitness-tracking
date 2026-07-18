import SwiftUI

/// Round-based superset logging, matching the design's SupersetView:
/// progress header, A/B meta strips, per-round cards (A row + B row),
/// add round, per-exercise notes, complete.
struct SupersetView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: WorkoutSessionState
    let supersetIndex: Int

    @State private var showMenu = false
    @State private var modal: WorkoutModal? = nil

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
        if let a = exA, let b = exB {
            content(a: a, b: b)
        } else {
            Color.aura.bg.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func content(a: Exercise, b: Exercise) -> some View {
        let rounds = max(a.sets.count, b.sets.count)
        let totalDone = a.sets.filter { $0.done }.count + b.sets.filter { $0.done }.count
        let totalSets = a.sets.count + b.sets.count

        VStack(spacing: 0) {
            navBar
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
                        }
                        .foregroundColor(.aura.accent)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color.aura.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                    }
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
        .sheet(item: $modal) { m in
            WorkoutModalsView(modal: m, presented: $modal)
                .environmentObject(session)
        }
    }

    // MARK: Nav bar

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
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

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
                         value: ex.lastPR.map { "\(UnitFormatter.weight($0.weight, unit: appState.weightUnit)) × \($0.reps)" } ?? "—",
                         sub: ex.lastPR?.date ?? "—",
                         tint: false)
                    .overlay(Divider(), alignment: .trailing)
                metaCell(label: "🎯 Target",
                         value: ex.target.map { "\(UnitFormatter.weight($0.weight, unit: appState.weightUnit)) × \($0.reps)" } ?? "—",
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
            for i in session.workout.exercises[idx].sets.indices {
                let s = session.workout.exercises[idx].sets[i]
                if s.weight != nil && s.reps != nil {
                    session.workout.exercises[idx].sets[i].done = true
                }
            }
            session.workout.exercises[idx].completed = true
        }
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
    @EnvironmentObject var appState: AppState
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
                input($weightText, placeholder: history?.weight ?? "–", label: appState.weightUnit) {
                    set.weight = UnitFormatter.parseWeightToKg(weightText, unit: appState.weightUnit); finish()
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
                    Text(UnitFormatter.weight(Double(h.weight) ?? 0, unit: appState.weightUnit)).font(.system(size: 11, weight: .bold)).foregroundColor(.aura.text3).frame(maxWidth: .infinity)
                    Text("\(h.reps) reps").font(.system(size: 11, weight: .bold)).foregroundColor(.aura.text3).frame(maxWidth: .infinity)
                    Color.clear.frame(width: 48)
                    Color.clear.frame(width: 48)
                }
            }
        }
        .onAppear {
            weightText = set.weight.map { UnitFormatter.weightNumber($0, unit: appState.weightUnit) } ?? ""
            repsText = set.reps.map { String($0) } ?? ""
        }
    }

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
    }
}
