import SwiftUI

struct ExerciseLoggingView: View {
    @EnvironmentObject var session: WorkoutSessionState
    @EnvironmentObject var appState: AppState
    let exerciseIndex: Int
<<<<<<< HEAD

    @State private var showWarmup = false
    @State private var showMenu = false
    @State private var showExerciseDetail = false
=======
    @State private var showWarmup = true
    @State private var showMenu = false
    @State private var modal: WorkoutModal? = nil
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753

    var exercise: Exercise? {
        session.workout.exercises.indices.contains(exerciseIndex)
            ? session.workout.exercises[exerciseIndex] : nil
    }

    var body: some View {
<<<<<<< HEAD
        guard let ex = exercise else {
            return AnyView(
                VStack {
                    Spacer()
                    Text("Exercise not found")
                        .foregroundColor(.aura.text2)
                    Spacer()
                }
                .background(Color.aura.bg)
            )
        }
        return AnyView(mainContent(ex: ex))
=======
        if let ex = exercise {
            content(ex: ex)
        } else {
            Color.aura.bg.ignoresSafeArea()
        }
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
    }

    @ViewBuilder
    private func mainContent(ex: Exercise) -> some View {
        VStack(spacing: 0) {
            navBar(ex: ex)
<<<<<<< HEAD
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                    videoBanner(ex: ex)
                    headerSection(ex: ex)
                    if ex.isCable { pulleySection }
                    prTargetSection(ex: ex)
                    if !ex.warmup.isEmpty { warmupSection(ex: ex) }
                    if !ex.hint.isEmpty { formTipSection(ex: ex) }
                    setsSection(ex: ex)
                    exerciseNoteSection
                    actionButtons(ex: ex)
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s3)
=======
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    videoThumb
                    nameAndChips(ex: ex)
                    if ex.isCable { pulleyCard }
                    prTargetCards(ex: ex)
                    if !ex.warmup.isEmpty { warmupCard(ex: ex) }
                    if !ex.hint.isEmpty { formTip(ex.hint) }
                    workingSetsHeader(ex: ex)
                    setRows(ex: ex)
                    addSetButton
                    if extraHistory(ex: ex).count > 0 { extraSetsCard(ex: ex) }
                    exerciseNotes
                    completeButton
                }
                .padding(.horizontal, AuraSpacing.screenPad)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
                .padding(.bottom, 120)
            }
        }
        .background(Color.aura.bg)
        .sheet(isPresented: $showMenu) {
            ExerciseMenuSheet(exerciseIndex: exerciseIndex, onModal: { m in
                showMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { modal = m }
            })
                .environmentObject(session)
<<<<<<< HEAD
                .presentationDetents([.fraction(0.58)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showExerciseDetail) {
            if let entry = ExerciseDatabase.shared.entry(named: ex.name) {
                ExerciseEntryDetailView(entry: entry)
            } else {
                ExerciseDetailView(exercise: ex)
            }
        }
    }

    // MARK: Nav bar
    @ViewBuilder
    private func navBar(ex: Exercise) -> some View {
        HStack {
            Button {
                session.activeView = .overview
            } label: {
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

            VStack(spacing: 2) {
                Text("Exercise \(exerciseIndex + 1) of \(session.workout.exercises.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.aura.text3)
                let done = ex.sets.filter { $0.done }.count
                Text("\(done)/\(ex.sets.count) sets")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.aura.text)
            }

            Spacer()

            Button { showMenu = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(.aura.text)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
=======
                .presentationDetents([.fraction(0.6)])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $modal) { m in
            WorkoutModalsView(modal: m, presented: $modal)
                .environmentObject(session)
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
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

<<<<<<< HEAD
    // MARK: Video banner (16:10 aspect, design spec)
    @ViewBuilder
    private func videoBanner(ex: Exercise) -> some View {
        ZStack {
            Color.aura.surface2
            if let urlStr = ex.youtubeURL, !urlStr.isEmpty {
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.55))
                            .frame(width: 52, height: 52)
                        Image(systemName: "play.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    Text("Watch Demo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.aura.text3)
                }
            } else {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.aura.accent.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 22))
                            .foregroundColor(.aura.accent)
                    }
                    Text("Exercise Demo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.aura.text3)
                }
            }

            // Bottom-left: exercise name chip tap → detail
            VStack {
                Spacer()
                HStack {
                    Button { showExerciseDetail = true } label: {
                        HStack(spacing: 4) {
                            Text(ex.name)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.aura.text)
                                .lineLimit(1)
                            Image(systemName: "info.circle")
                                .font(.system(size: 10))
                                .foregroundColor(.aura.text2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.aura.surface.opacity(0.92))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(10)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16/10, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
    }

    // MARK: Header (name + chips)
    @ViewBuilder
    private func headerSection(ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { showExerciseDetail = true } label: {
                HStack(spacing: 4) {
                    Text(ex.name)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.aura.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "arrow.up.right.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.aura.text3)
                }
            }
            .buttonStyle(.plain)

            // Progress bar for this exercise
            let done = Double(ex.sets.filter { $0.done }.count)
            let total = Double(max(ex.sets.count, 1))
            AuraProgressBar(value: done / total, height: 4)

            HStack(spacing: AuraSpacing.s2) {
                AuraBadge(label: ex.equipment, color: .aura.blue)
                ForEach(ex.muscleGroups.prefix(2), id: \.self) { m in
                    AuraBadge(label: m, color: .aura.accent)
                }
                AuraBadge(label: ex.difficulty, color: .aura.text2)
                Spacer()
            }
        }
    }

    // MARK: Cable pulley
    private var pulleySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pulley")
                .font(AuraFont.sectionLabel())
                .foregroundColor(.aura.text3)
            AuraSegmentedPicker(
                options: ["Single", "Double"],
                selection: Binding(
                    get: {
                        session.workout.exercises.indices.contains(exerciseIndex)
                        && session.workout.exercises[exerciseIndex].pulley == "double"
                            ? "Double" : "Single"
                    },
                    set: { val in
                        session.onPulleyChange(exerciseIndex: exerciseIndex, pulley: val.lowercased())
                    }
                )
            )
        }
    }

    // MARK: PR + Target cards
    @ViewBuilder
    private func prTargetSection(ex: Exercise) -> some View {
        if ex.lastPR != nil || ex.target != nil {
            HStack(spacing: AuraSpacing.s3) {
                if let pr = ex.lastPR {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.aura.text3)
                            Text("Last PR")
                                .font(AuraFont.sectionLabel())
                                .foregroundColor(.aura.text3)
                        }
                        Text("\(formatW(pr.weight)) kg × \(pr.reps)")
                            .font(AuraFont.statNum(size: 18))
                            .foregroundColor(.aura.text)
                        Text(pr.date)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AuraSpacing.s3)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AuraRadius.md)
                        .stroke(Color.aura.separator2, lineWidth: 1))
                }

                if let t = ex.target {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.system(size: 11))
                                .foregroundColor(.aura.accent)
                            Text("Today's Target")
                                .font(AuraFont.sectionLabel())
                                .foregroundColor(.aura.accent)
                        }
                        Text("\(formatW(t.weight)) kg × \(t.reps)")
                            .font(AuraFont.statNum(size: 18))
                            .foregroundColor(.aura.accent)
                        Text(t.note)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AuraSpacing.s3)
                    .background(Color.aura.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AuraRadius.md)
                        .stroke(Color.aura.accent.opacity(0.3), lineWidth: 1))
                }
            }
        }
    }

    // MARK: Warmup (always shown, collapsible)
    @ViewBuilder
    private func warmupSection(ex: Exercise) -> some View {
        DisclosureGroup(isExpanded: $showWarmup) {
            VStack(spacing: 0) {
                ForEach(Array(ex.warmup.enumerated()), id: \.offset) { i, ws in
                    HStack(spacing: AuraSpacing.s3) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.aura.accentSoft)
                                .frame(width: 28, height: 24)
                            Text("W\(i + 1)")
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundColor(.aura.accent)
                        }
                        Text(ws.label)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                        Spacer()
                        Text("× \(ws.reps) reps")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.aura.text)
                    }
                    .padding(.vertical, 8)
                    if i < ex.warmup.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.top, AuraSpacing.s2)
        } label: {
            HStack(spacing: AuraSpacing.s2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.aura.accent)
                Text("Warm-up Protocol")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.aura.text)
                Spacer()
                Text("\(ex.warmup.count) sets")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text3)
            }
        }
        .padding(AuraSpacing.s3)
        .background(Color.aura.surface2)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .tint(.aura.accent)
    }

    // MARK: Form tip
    @ViewBuilder
    private func formTipSection(ex: Exercise) -> some View {
        HStack(alignment: .top, spacing: AuraSpacing.s3) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.aura.accent)
                .font(.system(size: 16))
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("Form Tip")
                    .font(AuraFont.sectionLabel())
                    .foregroundColor(.aura.text3)
                Text(ex.hint)
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AuraSpacing.s3)
        .background(Color.aura.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md)
            .stroke(Color.aura.accent.opacity(0.2), lineWidth: 1))
    }

    // MARK: Sets section
    @ViewBuilder
    private func setsSection(ex: Exercise) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 4) {
                    Text("Working Sets")
                        .font(AuraFont.sectionLabel())
                        .foregroundColor(.aura.text3)
                }
                Spacer()
                let done = ex.sets.filter { $0.done }.count
                Text("\(done) / \(ex.sets.count) done")
                    .font(AuraFont.secondary())
                    .foregroundColor(done == ex.sets.count && !ex.sets.isEmpty ? .aura.green : .aura.text2)
            }
            .padding(.bottom, AuraSpacing.s2)

            // Column labels
            HStack(spacing: AuraSpacing.s2) {
                Text("SET")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.aura.text3)
                    .tracking(0.5)
                    .frame(width: 44)
                Text("WEIGHT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.aura.text3)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity)
                Text("")
                    .frame(width: 14)
                Text("REPS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.aura.text3)
                    .tracking(0.5)
                    .frame(maxWidth: .infinity)
                Text("")
                    .frame(width: 44)
                Text("")
                    .frame(width: 44)
            }
            .padding(.horizontal, AuraSpacing.s3)
            .padding(.bottom, 4)

            // Set rows
            VStack(spacing: 0) {
                ForEach(Array(session.workout.exercises[exerciseIndex].sets.indices), id: \.self) { si in
                    SetRowView(
                        exerciseIndex: exerciseIndex,
                        setIndex: si,
                        set: Binding(
                            get: { session.workout.exercises[exerciseIndex].sets[si] },
                            set: { session.workout.exercises[exerciseIndex].sets[si] = $0 }
                        ),
                        previousWeight: si == 0 ? ex.lastPR?.weight : nil,
                        previousReps: si == 0 ? ex.lastPR?.reps : nil
                    )
                    if si < session.workout.exercises[exerciseIndex].sets.count - 1 {
                        Divider()
                            .padding(.leading, AuraSpacing.s3)
                    }
                }
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md)
                .stroke(Color.aura.separator2, lineWidth: 1))

            // Extra sets note (if beyond planned)
            if ex.sets.count > ex.plannedSets && ex.plannedSets > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.aura.blue)
                    Text("\(ex.sets.count - ex.plannedSets) extra \(ex.sets.count - ex.plannedSets == 1 ? "set" : "sets") beyond planned. Nice work.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                .padding(AuraSpacing.s3)
                .background(Color.aura.blue.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                .padding(.top, AuraSpacing.s2)
=======
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
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
            }
        }
    }

<<<<<<< HEAD
    // MARK: Exercise note
    private var exerciseNoteSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Exercise Note", systemImage: "note.text")
                .font(AuraFont.sectionLabel())
                .foregroundColor(.aura.text3)
            TextField("How did it feel? Cues to remember…",
                      text: Binding(
                        get: { session.workout.exercises[exerciseIndex].note },
                        set: { session.workout.exercises[exerciseIndex].note = $0 }
                      ),
                      axis: .vertical)
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text)
                .lineLimit(3, reservesSpace: true)
                .padding(AuraSpacing.s3)
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AuraRadius.md)
                    .stroke(Color.aura.separator2, lineWidth: 1))
        }
    }

    // MARK: Action buttons
    @ViewBuilder
    private func actionButtons(ex: Exercise) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            AuraTintedButton(label: "Add Set", icon: "plus") {
                session.onAddSet(to: exerciseIndex)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            AuraPrimaryButton(label: "Complete", icon: "checkmark") {
                session.onCompleteExercise(at: exerciseIndex)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    // MARK: Util
    private func formatW(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
=======
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
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
    }
}
