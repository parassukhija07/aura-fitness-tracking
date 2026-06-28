import SwiftUI

struct ExerciseLoggingView: View {
    @EnvironmentObject var session: WorkoutSessionState
    let exerciseIndex: Int
    @State private var showWarmup = true
    @State private var showMenu = false

    var exercise: Exercise? {
        session.workout.exercises.indices.contains(exerciseIndex)
            ? session.workout.exercises[exerciseIndex] : nil
    }

    var body: some View {
        if let ex = exercise {
            content(ex: ex)
        } else {
            Color.aura.bg.ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func content(ex: Exercise) -> some View {
        VStack(spacing: 0) {
            navBar(ex: ex)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    videoThumb
                    nameAndChips(ex: ex)
                    if ex.isCable { pulleyCard }
                    prTargetCards(ex: ex)
                    if !ex.warmup.isEmpty && exerciseIndex < 2 { warmupCard(ex: ex) }
                    if !ex.hint.isEmpty { formTip(ex.hint) }
                    workingSetsHeader(ex: ex)
                    setRows(ex: ex)
                    addSetButton
                    if extraHistory(ex: ex).count > 0 { extraSetsCard(ex: ex) }
                    exerciseNotes
                    completeButton
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.bottom, 120)
            }
        }
        .background(Color.aura.bg)
        .sheet(isPresented: $showMenu) {
            ExerciseMenuSheet(exerciseIndex: exerciseIndex)
                .environmentObject(session)
                .presentationDetents([.fraction(0.6)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Nav bar (Back · "Exercise N" + name · ⋯)

    private func navBar(ex: Exercise) -> some View {
        HStack {
            Button { session.activeView = .overview } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.aura.accent)
            }
            Spacer()
            VStack(spacing: 1) {
                Text("EXERCISE \(exerciseIndex + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.aura.text3)
                Text(ex.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.aura.text)
                    .lineLimit(1)
                    .frame(maxWidth: 160)
            }
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

    // MARK: Video thumbnail + play

    private var videoThumb: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .fill(Color.aura.surface2)
                .aspectRatio(16.0/10.0, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: AuraRadius.lg)
                        .stroke(Color.aura.separator.opacity(0.5), lineWidth: 1)
                )
                .overlay(
                    Text("exercise demo")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.aura.text3)
                )
            Circle()
                .fill(Color.white)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.black)
                        .offset(x: 2)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        }
        .padding(.top, 14)
    }

    private func nameAndChips(ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ex.name)
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.aura.text)
            // Equipment chip (accent) + muscle group chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    chip(ex.equipment, accent: true)
                    ForEach(ex.muscleGroups, id: \.self) { g in chip(g, accent: false) }
                }
            }
        }
        .padding(.top, 14)
    }

    private func chip(_ text: String, accent: Bool) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(accent ? .aura.accent : .aura.text)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(accent ? Color.aura.accentSoft : Color.aura.fill)
            .clipShape(Capsule())
    }

    // MARK: Pulley card

    private var pulleyCard: some View {
        HStack {
            HStack(spacing: AuraSpacing.s2) {
                Image(systemName: "cable.connector")
                    .foregroundColor(.aura.text2)
                Text("Pulley setup")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.aura.text)
            }
            Spacer()
            AuraSegmentedPicker(
                options: ["Single", "Double"],
                selection: Binding(
                    get: { session.workout.exercises[exerciseIndex].pulley == "double" ? "Double" : "Single" },
                    set: { session.onPulleyChange(exerciseIndex: exerciseIndex, pulley: $0.lowercased()) }
                )
            )
            .frame(width: 150)
        }
        .padding(AuraSpacing.s4)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        .padding(.top, 14)
    }

    // MARK: PR + Target mini-cards

    private func prTargetCards(ex: Exercise) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            miniCard(
                icon: "trophy.fill", iconColor: .aura.accent, head: "Last PR",
                value: ex.lastPR.map { "\(fmt($0.weight)) kg × \($0.reps)" } ?? "—",
                sub: ex.lastPR?.date ?? "—", highlighted: false
            )
            miniCard(
                icon: "target", iconColor: .aura.accent, head: "Today's target",
                value: ex.target.map { "\(fmt($0.weight)) kg × \($0.reps)" } ?? "—",
                sub: ex.target?.note ?? "", highlighted: true
            )
        }
        .padding(.top, 14)
    }

    private func miniCard(icon: String, iconColor: Color, head: String, value: String, sub: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 13)).foregroundColor(iconColor)
                Text(head).font(.system(size: 11, weight: .bold)).foregroundColor(.aura.text2)
            }
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(highlighted ? .aura.accent : .aura.text)
                .monospacedDigit()
            Text(sub)
                .font(.system(size: 11))
                .foregroundColor(.aura.text3)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(highlighted ? Color.aura.accentSoft : Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.md)
                .stroke(highlighted ? Color.aura.accent : Color.aura.separator.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: Warm-up

    private func warmupCard(ex: Exercise) -> some View {
        VStack(spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { showWarmup.toggle() } } label: {
                HStack(spacing: AuraSpacing.s2) {
                    Image(systemName: "flame.fill").foregroundColor(.aura.accent).font(.system(size: 15))
                    Text("Warm-up protocol")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.aura.text)
                    Spacer()
                    Text("\(ex.warmup.count) sets").font(.system(size: 12)).foregroundColor(.aura.text2)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14)).foregroundColor(.aura.text3)
                        .rotationEffect(.degrees(showWarmup ? 180 : 0))
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            if showWarmup {
                VStack(spacing: 0) {
                    ForEach(Array(ex.warmup.enumerated()), id: \.offset) { i, w in
                        HStack(spacing: 12) {
                            Text("W\(i + 1)")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.aura.accent)
                                .frame(width: 30, height: 24)
                                .background(Color.aura.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            Text("\(w.reps) reps").font(.system(size: 14, weight: .medium)).foregroundColor(.aura.text)
                            Spacer()
                            Text(w.label).font(.system(size: 12)).foregroundColor(.aura.text2)
                        }
                        .padding(.vertical, 8)
                        .overlay(Divider(), alignment: .top)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        .padding(.top, 14)
    }

    // MARK: Form tip

    private func formTip(_ hint: String) -> some View {
        HStack(alignment: .top, spacing: AuraSpacing.s3) {
            Image(systemName: "lightbulb.fill").foregroundColor(.aura.accent).font(.system(size: 16))
            VStack(alignment: .leading, spacing: 3) {
                Text("Form tip").font(.system(size: 13, weight: .bold)).foregroundColor(.aura.text)
                Text(hint).font(.system(size: 13)).foregroundColor(.aura.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AuraSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        .padding(.top, 14)
    }

    // MARK: Working sets

    private func workingSetsHeader(ex: Exercise) -> some View {
        let done = ex.sets.filter { $0.done }.count
        return VStack(spacing: 14) {
            HStack {
                Text("Working sets").font(.system(size: 17, weight: .heavy)).foregroundColor(.aura.text)
                Spacer()
                Text("\(done)/\(ex.sets.count) done")
                    .font(.system(size: 12, weight: .bold)).foregroundColor(.aura.text2)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.aura.fill).clipShape(Capsule())
            }
            AuraProgressBar(value: ex.sets.isEmpty ? 0 : Double(done) / Double(ex.sets.count))
        }
        .padding(.top, 22)
        .padding(.bottom, 4)
    }

    private func setRows(ex: Exercise) -> some View {
        VStack(spacing: 8) {
            ForEach(session.workout.exercises[exerciseIndex].sets.indices, id: \.self) { si in
                SetRowView(
                    exerciseIndex: exerciseIndex,
                    setIndex: si,
                    set: Binding(
                        get: { session.workout.exercises[exerciseIndex].sets[si] },
                        set: { session.workout.exercises[exerciseIndex].sets[si] = $0 }
                    ),
                    history: si < ex.history.count ? ex.history[si] : nil
                )
            }
        }
    }

    private var addSetButton: some View {
        Button { session.onAddSet(to: exerciseIndex) } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 15, weight: .semibold))
                Text("Add set").font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.aura.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.aura.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    // MARK: Extra sets last session

    private func extraHistory(ex: Exercise) -> [SetHistory] {
        guard ex.history.count > ex.plannedSets else { return [] }
        return Array(ex.history[ex.plannedSets...])
    }

    private func extraSetsCard(ex: Exercise) -> some View {
        let extra = extraHistory(ex: ex)
        let detail = extra.enumerated().map { j, h in
            "Set \(ex.plannedSets + j + 1): \(h.weight) kg × \(h.reps) reps"
        }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: AuraSpacing.s3) {
            Image(systemName: "info.circle.fill").foregroundColor(.aura.blue).font(.system(size: 16))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(extra.count) extra set\(extra.count > 1 ? "s" : "") last session")
                    .font(.system(size: 13, weight: .bold)).foregroundColor(.aura.text)
                Text(detail).font(.system(size: 12)).foregroundColor(.aura.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AuraSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aura.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.blue.opacity(0.22), lineWidth: 1))
        .padding(.top, 14)
    }

    // MARK: Notes + complete

    private var exerciseNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Exercise notes").sectionLabelStyle()
            TextField("Cues, adjustments, how it felt…",
                      text: Binding(
                        get: { session.workout.exercises[exerciseIndex].note },
                        set: { session.workout.exercises[exerciseIndex].note = $0 }
                      ), axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(.aura.text)
                .lineLimit(3, reservesSpace: true)
                .padding(13)
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        }
        .padding(.top, 20)
    }

    private var completeButton: some View {
        AuraPrimaryButton(label: "Complete Exercise", icon: "checkmark") {
            session.onCompleteExercise(at: exerciseIndex)
        }
        .padding(.top, 16)
    }

    private func fmt(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }
}
