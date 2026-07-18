import SwiftUI

// MARK: - Exercise Detail (full-screen)
// Mirrors ExerciseDetail in plan/exercise-detail.jsx. Launched two ways:
//  • from the Exercises library with showActions (bottom action bar)
//  • from the workout editor with workoutCtx (leading Workout tab + A/B toggle)

struct PlanWorkoutCtx {
    var sets: Int
    var reps: String
    var restTime: Int
    var isSuperset: Bool
    var ssRole: String          // "A" (leader) or "B"
    var partner: PlanLibExercise?
}

struct PlanExerciseDetailView: View {
    let exercise: PlanLibExercise
    var showActions: Bool = false
    var workoutCtx: PlanWorkoutCtx? = nil
    var onSave: ((Int, String, Int) -> Void)? = nil
    var onBack: () -> Void

    @State private var tab: String
    @State private var ssSubTab = "a"          // a = leader, b = partner
    @State private var addSheet: AddRoute? = nil

    enum AddRoute: Identifiable {
        case pickWorkout
        case targetWorkout(PlanWorkout)
        var id: String { switch self { case .pickWorkout: return "pick"; case .targetWorkout(let w): return "t-\(w.id)" } }
    }

    init(exercise: PlanLibExercise, showActions: Bool = false,
         workoutCtx: PlanWorkoutCtx? = nil,
         onSave: ((Int, String, Int) -> Void)? = nil,
         onBack: @escaping () -> Void) {
        self.exercise = exercise
        self.showActions = showActions
        self.workoutCtx = workoutCtx
        self.onSave = onSave
        self.onBack = onBack
        _tab = State(initialValue: workoutCtx != nil ? "workout" : "overview")
    }

    private var isSuperset: Bool { workoutCtx?.isSuperset == true }
    /// Which exercise's Overview/History is shown (leader vs partner).
    private var activeEx: PlanLibExercise {
        if isSuperset, ssSubTab == "b", let p = workoutCtx?.partner { return p }
        return exercise
    }
    private var tabs: [String] { workoutCtx != nil ? ["workout", "overview", "history"] : ["overview", "history"] }
    private func tabLabel(_ t: String) -> String { ["workout": "Workout", "overview": "Overview", "history": "History"][t] ?? t }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                Group {
                    switch tab {
                    case "workout":
                        PlanWorkoutTab(exercise: exercise, ctx: workoutCtx, onSave: onSave)
                    case "overview":
                        PlanOverviewTab(ex: activeEx) { ssTabsView }
                    default:
                        PlanHistoryTab(ex: activeEx) { ssTabsView }
                    }
                }
                .padding(.top, 8)
                Color.clear.frame(height: 28)
            }
            if showActions { actionBar }
        }
        .background(Color.aura.bg)
        .sheet(item: $addSheet) { route in
            addSheetView(route)
                .presentationDetents(route.id == "pick" ? [.fraction(0.62)] : [.fraction(0.76)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Header (back + title + segmented tabs)

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
                        Text("Back").font(.system(size: 17))
                    }
                    .foregroundColor(.aura.accent)
                }
                Spacer()
                PlanIconButton(icon: "heart") {}
            }
            .padding(.horizontal, 14).padding(.top, AuraSpacing.s1).padding(.bottom, 4)

            Text(exercise.name)
                .font(.system(size: 20, weight: .heavy)).tracking(-0.4)
                .foregroundColor(.aura.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.bottom, 8)

            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { t in
                    Button { tab = t } label: {
                        Text(tabLabel(t))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(tab == t ? .aura.text : .aura.text2)
                            .frame(maxWidth: .infinity).frame(height: 36)
                            .background(
                                Capsule().fill(tab == t ? Color.aura.surface : Color.clear)
                                    .auraShadowSm()
                                    .opacity(tab == t ? 1 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.aura.fill)
            .clipShape(Capsule())
            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 10)
            .overlay(alignment: .top) { Rectangle().fill(Color.aura.separator2).frame(height: 1) }
        }
    }

    @ViewBuilder
    private var ssTabsView: some View {
        if isSuperset {
            let names = [("a", exercise), ("b", workoutCtx?.partner)]
            HStack(spacing: 0) {
                ForEach(names, id: \.0) { key, ex in
                    Button { ssSubTab = key } label: {
                        Text((ssSubTab == key ? "● " : "") + (ex.map { $0.name.split(separator: " ").prefix(2).joined(separator: " ") } ?? "Exercise"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(ssSubTab == key ? .white : .aura.accent)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity).frame(height: 30)
                            .background(ssSubTab == key ? Color.aura.accent : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.aura.accent.opacity(0.14))
            .clipShape(Capsule())
            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 2)
        }
    }

    // MARK: Action bar (showActions)

    private var actionBar: some View {
        VStack(spacing: 8) {
            AuraPrimaryButton(label: "Add to Today's Workout", icon: "plus") {}
            AuraTintedButton(label: "Add to a Plan", icon: "dumbbell.fill") { addSheet = .pickWorkout }
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, AuraSpacing.s4)
        .overlay(alignment: .top) { Rectangle().fill(Color.aura.separator2).frame(height: 1) }
    }

    @ViewBuilder
    private func addSheetView(_ route: AddRoute) -> some View {
        switch route {
        case .pickWorkout:
            PlanSheet(title: "Add to which workout?", onClose: { addSheet = nil }) {
                Text("From your active plan · Push Pull Legs")
                    .font(.system(size: 12)).foregroundColor(.aura.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4).padding(.bottom, 12)
                PlanList {
                    ForEach(Array(PlanData.workouts.enumerated()), id: \.element.id) { i, w in
                        Button { addSheet = .targetWorkout(w) } label: {
                            HStack(spacing: AuraSpacing.s3) {
                                Text(String(w.name.prefix(1)))
                                    .font(.system(size: 13, weight: .bold)).foregroundColor(.aura.accent)
                                    .frame(width: 30, height: 30).background(Color.aura.accentSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(w.name).font(.system(size: 16, weight: .medium)).foregroundColor(.aura.text)
                                    Text("\(w.exCount) exercises").font(AuraFont.secondary()).foregroundColor(.aura.text2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.aura.text3)
                            }
                            .padding(.vertical, 11).padding(.horizontal, 14).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        if i < PlanData.workouts.count - 1 { Divider().padding(.leading, 14) }
                    }
                }
            }
        case .targetWorkout(let w):
            PlanSheet(title: "\(exercise.name) → \(w.name)", onClose: { addSheet = nil }) {
                AuraPrimaryButton(label: "Add as new exercise", icon: "plus") { addSheet = nil }
                    .padding(.vertical, 8)
                AuraSectionLabel(title: "Or replace one")
                VStack(spacing: 9) {
                    ForEach(PlanData.exercises.filter { $0.muscle == exercise.muscle && $0.name != exercise.name }.prefix(4)) { e in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.name).font(.system(size: 15, weight: .bold)).foregroundColor(.aura.text)
                                Text("3 sets · 8–12 reps").font(.system(size: 13)).foregroundColor(.aura.text2)
                            }
                            Spacer()
                            Button { addSheet = nil } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 13))
                                    Text("Replace").font(AuraFont.badge())
                                }
                                .foregroundColor(.aura.text2)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.aura.fill).clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                    }
                }
            }
        }
    }
}

// MARK: - Workout tab (editor inline edit)

private struct PlanWorkoutTab: View {
    let exercise: PlanLibExercise
    let ctx: PlanWorkoutCtx?
    var onSave: ((Int, String, Int) -> Void)?

    @State private var sets: Int
    @State private var reps: String
    @State private var rest: Int
    private let steps = [30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

    init(exercise: PlanLibExercise, ctx: PlanWorkoutCtx?, onSave: ((Int, String, Int) -> Void)?) {
        self.exercise = exercise; self.ctx = ctx; self.onSave = onSave
        _sets = State(initialValue: ctx?.sets ?? 3)
        _reps = State(initialValue: ctx?.reps ?? "8–12")
        _rest = State(initialValue: ctx?.restTime ?? 90)
    }

    private var ri: Int { max(0, steps.firstIndex(of: rest) ?? 4) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            videoPlaceholder.padding(.horizontal, 14).padding(.bottom, 14)
            Text(exercise.name).font(.system(size: 22, weight: .heavy)).tracking(-0.44)
                .foregroundColor(.aura.text).padding(.horizontal, 14).padding(.bottom, 16)
            VStack(spacing: 10) {
                card {
                    HStack {
                        Text("Sets").font(.system(size: 14, weight: .semibold)).foregroundColor(.aura.text)
                        Spacer()
                        HStack(spacing: 10) {
                            stepBtn("minus", accent: false) { sets = max(1, sets - 1) }
                            Text("\(sets)").font(.system(size: 17, weight: .heavy)).frame(minWidth: 24).foregroundColor(.aura.text)
                            stepBtn("plus", accent: true) { sets += 1 }
                        }
                    }
                }
                card {
                    HStack {
                        Text("Rep range").font(.system(size: 14, weight: .semibold)).foregroundColor(.aura.text)
                        Spacer()
                        TextField("", text: $reps)
                            .multilineTextAlignment(.center).font(.system(size: 15, weight: .bold)).foregroundColor(.aura.text)
                            .frame(width: 80, height: 34).background(Color.aura.fill)
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xs))
                            .overlay(RoundedRectangle(cornerRadius: AuraRadius.xs).stroke(Color.aura.separator2, lineWidth: 1))
                    }
                }
                card {
                    VStack(spacing: 10) {
                        Text("REST BETWEEN SETS").font(.system(size: 11, weight: .bold)).tracking(0.55)
                            .foregroundColor(.aura.text2).frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 8) {
                            stepBtn("minus", accent: false) { if ri > 0 { rest = steps[ri - 1] } }
                            Text(RestPicker.fmt(rest))
                                .font(.system(size: 26, weight: .heavy).monospacedDigit()).tracking(-0.78)
                                .foregroundColor(.aura.accent).frame(maxWidth: .infinity)
                            stepBtn("plus", accent: true) { if ri < steps.count - 1 { rest = steps[ri + 1] } }
                        }
                        HStack(spacing: 4) {
                            ForEach(steps, id: \.self) { s in
                                Capsule().fill(s == rest ? Color.aura.accent : Color.aura.separator2)
                                    .frame(width: s == rest ? 14 : 5, height: 4)
                            }
                        }
                    }
                }
                AuraPrimaryButton(label: "Save Changes", icon: "checkmark") {
                    onSave?(sets, reps, rest)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 14)
        }
    }

    private var videoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AuraRadius.lg).fill(Color.aura.fill).aspectRatio(16.0/10.0, contentMode: .fit)
            Circle().fill(Color.white).frame(width: 48, height: 48)
                .overlay(Image(systemName: "play.fill").font(.system(size: 20)).foregroundColor(.aura.text))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
    }

    private func stepBtn(_ icon: String, accent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                .foregroundColor(accent ? .aura.accent : .aura.text)
                .frame(width: 34, height: 34)
                .background(accent ? Color.aura.accentSoft : Color.aura.fill.opacity(0.5)).clipShape(Circle())
        }
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content().padding(14)
            .frame(maxWidth: .infinity)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
    }
}

// MARK: - Overview tab

private struct PlanOverviewTab<SS: View>: View {
    let ex: PlanLibExercise
    @ViewBuilder var ssTabs: () -> SS

    private var info: XDInfo { PlanExerciseDetail.info(for: ex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ssTabs()
            // Stats pill
            HStack(spacing: 0) {
                statCell("CATEGORY", ex.muscle)
                Divider().frame(height: 40)
                statCell("EQUIPMENT", ex.equip)
                Divider().frame(height: 40)
                statCell("LEVEL", PlanExerciseDetail.level(for: ex.equip))
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
            .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 14)

            // Video
            ZStack {
                RoundedRectangle(cornerRadius: AuraRadius.lg).fill(Color.aura.fill).aspectRatio(16.0/10.0, contentMode: .fit)
                Circle().fill(Color.white).frame(width: 48, height: 48)
                    .overlay(Image(systemName: "play.fill").font(.system(size: 20)).foregroundColor(.aura.text))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
            }
            .padding(.horizontal, 14).padding(.bottom, 18)

            Text(info.desc).font(.system(size: 14)).foregroundColor(.aura.text2).lineSpacing(4)
                .padding(.horizontal, 14).padding(.bottom, 18)

            // Pro tip
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "lightbulb.fill").font(.system(size: 18)).foregroundColor(.aura.accent).padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pro tip").font(.system(size: 13, weight: .bold)).foregroundColor(.aura.accent)
                    Text(info.tips.first ?? "").font(AuraFont.secondary()).foregroundColor(.aura.text2)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.aura.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.accent.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 14).padding(.bottom, 18)

            AuraSectionLabel(title: "Muscle activation").padding(.horizontal, 14)
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        legendDot(.aura.accent, "Primary")
                        legendDot(.aura.blue, "Secondary")
                    }
                    .padding(.bottom, 10)
                    ForEach(info.activation, id: \.muscle) { a in
                        let isPrimary = info.primary.contains { a.muscle == $0 || a.muscle.contains($0) }
                        VStack(spacing: 3) {
                            HStack {
                                Text(a.muscle).font(.system(size: 12, weight: .bold)).foregroundColor(.aura.text)
                                Spacer()
                                Text("\(a.p)%").font(.system(size: 12, weight: .bold)).foregroundColor(.aura.text2)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.aura.track).frame(height: 5)
                                    Capsule().fill(isPrimary ? Color.aura.accent : Color.aura.blue)
                                        .frame(width: geo.size.width * CGFloat(a.p) / 100, height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                        .padding(.bottom, 7)
                    }
                }
                PlanBodyMap(primary: info.primary, secondary: info.secondary)
            }
            .padding(14)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator2, lineWidth: 1))
            .padding(.horizontal, 14).padding(.bottom, 18)

            AuraSectionLabel(title: "Key takeaways").padding(.horizontal, 14)
            VStack(spacing: 8) {
                ForEach(Array(info.tips.enumerated()), id: \.offset) { i, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(i + 1)").font(.system(size: 10, weight: .black)).foregroundColor(.aura.accent)
                            .frame(width: 20, height: 20).background(Color.aura.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 6)).padding(.top, 1)
                        Text(tip).font(.system(size: 13)).foregroundColor(.aura.text).lineSpacing(3)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 13).padding(.vertical, 11)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                }
            }
            .padding(.horizontal, 14)
        }
    }

    private func statCell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 12, weight: .bold)).foregroundColor(.aura.text2)
            Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(.aura.text)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 11).padding(.horizontal, 8)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(color)
        }
    }
}

// MARK: - History tab

private struct PlanHistoryTab<SS: View>: View {
    @EnvironmentObject var appState: AppState
    let ex: PlanLibExercise
    @ViewBuilder var ssTabs: () -> SS

    @State private var open: Int? = nil

    var body: some View {
        let history = appState.realHistory(forExercise: ex.name)
        VStack(alignment: .leading, spacing: 0) {
            ssTabs()
            if history.isEmpty {
                emptyState
            } else {
                let pbs = PlanExerciseDetail.calcPBs(history)
                AuraSectionLabel(title: "Personal best").padding(.top, 0)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    pbCard("EST. 1RM", fmt(pbs.e1rm), "Epley formula")
                    pbCard("MAX WEIGHT", fmt(pbs.maxW), "Single set")
                    pbCard("MAX REPS", "\(pbs.maxR)", "Single set")
                    pbCard("MAX VOLUME", pbs.maxVol > 0 ? UnitFormatter.weight(pbs.maxVol, unit: appState.weightUnit) : "BW", "Per session")
                }

                AuraSectionLabel(title: "Session history")
                VStack(spacing: 8) {
                    ForEach(Array(history.enumerated()), id: \.offset) { i, s in
                        sessionRow(i, s)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private var emptyState: some View {
        VStack(spacing: AuraSpacing.s2) {
            Image(systemName: "chart.bar")
                .font(.system(size: 32))
                .foregroundColor(.aura.text3)
            Text("No history yet")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.aura.text2)
            Text("Log this exercise in a workout to see your personal bests and session history here.")
                .font(.system(size: 13))
                .foregroundColor(.aura.text3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AuraSpacing.s6)
    }

    private func fmt(_ v: Double) -> String { v > 0 ? UnitFormatter.weight(v, unit: appState.weightUnit) : "BW" }

    private func pbCard(_ label: String, _ value: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 11, weight: .bold)).tracking(0.3).foregroundColor(.aura.text2).padding(.bottom, 5)
            Text(value).font(.system(size: 22, weight: .heavy).monospacedDigit()).tracking(-0.44).foregroundColor(.aura.accent)
            Text(sub).font(.system(size: 11)).foregroundColor(.aura.text3).padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 13).padding(.vertical, 12)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
    }

    @ViewBuilder
    private func sessionRow(_ i: Int, _ s: PlanExerciseDetail.HistSession) -> some View {
        VStack(spacing: 0) {
            Button { open = (open == i) ? nil : i } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.date).font(.system(size: 14, weight: .bold)).foregroundColor(.aura.text)
                        Text("\(s.sets.count) sets · " + (s.sets[0].weight > 0 ? "top \(UnitFormatter.weight(s.sets[0].weight, unit: appState.weightUnit))" : "bodyweight"))
                            .font(.system(size: 12)).foregroundColor(.aura.text2)
                    }
                    Spacer()
                    Image(systemName: open == i ? "chevron.up" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.aura.text3)
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
            }
            .buttonStyle(.plain)

            if open == i {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        colHead("SET", flex: 0.5); colHead("WEIGHT"); colHead("REPS"); colHead("EST 1RM")
                    }
                    .padding(.bottom, 6)
                    ForEach(Array(s.sets.enumerated()), id: \.offset) { si, st in
                        HStack(spacing: 6) {
                            cell("\(si + 1)", flex: 0.5, color: .aura.text3, weight: .bold)
                            cell(st.weight > 0 ? UnitFormatter.weight(st.weight, unit: appState.weightUnit) : "BW", weight: .semibold)
                            cell("\(st.reps)", weight: .semibold)
                            cell(UnitFormatter.weight(PlanExerciseDetail.epley(st.weight, st.reps), unit: appState.weightUnit), color: .aura.accent, weight: .bold)
                        }
                        .padding(.vertical, 5)
                        .overlay(alignment: .top) {
                            if si > 0 { Rectangle().fill(Color.aura.separator2).frame(height: 1) }
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.top, 8).padding(.bottom, 12)
                .overlay(alignment: .top) { Rectangle().fill(Color.aura.separator2).frame(height: 1) }
            }
        }
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
    }

    private func colHead(_ t: String, flex: CGFloat = 1) -> some View {
        Text(t).font(.system(size: 11, weight: .bold)).foregroundColor(.aura.text3)
            .frame(maxWidth: .infinity, alignment: .leading).layoutPriority(Double(flex))
    }
    private func cell(_ t: String, flex: CGFloat = 1, color: Color = .aura.text, weight: Font.Weight = .regular) -> some View {
        Text(t).font(.system(size: 13, weight: weight)).foregroundColor(color)
            .frame(maxWidth: .infinity, alignment: .leading).layoutPriority(Double(flex))
    }
}
