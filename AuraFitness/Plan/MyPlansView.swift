import SwiftUI

// MARK: - My Plans subtab
//
// Mirrors plan/app.jsx `myplans`: gradient plan carousel → WeekStrip (7 day
// tiles) → "Workouts in program" cards with edit/delete, all fed by
// UserPlanDatabase/ProgramDatabase.

struct MyPlansView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var planDB = UserPlanDatabase.shared
    @StateObject private var programDB = ProgramDatabase.shared
    @State private var showProgramLibrary = false
    @State private var showCreatePlan = false
    @State private var showBuildProgram = false
    @State private var editingPlan: UserPlan? = nil
    @State private var planToDelete: UserPlan? = nil
    @State private var showDeleteAlert = false
    @State private var editorTarget: WorkoutEditorTarget? = nil
    @State private var workoutToDelete: Workout? = nil
    @State private var showWorkoutDeleteAlert = false

    // MARK: Bottom-sheet host (add-plan / assign / day-menu / add-workout / create-workout)
    @State private var activeSheet: MyPlanSheet? = nil
    /// create-workout form: name + selected icon keyword (default = first tile).
    @State private var cwName = ""
    @State private var cwIcon = MyPlansView.createWorkoutIcons[0].label

    enum MyPlanSheet: Identifiable {
        case addPlan
        case assign(day: Int)
        case dayMenu(day: Int)
        case addWorkout
        case createWorkout
        /// "Set as active" → choose the day the plan starts scheduling from.
        case activate(planID: UUID)

        var id: String {
            switch self {
            case .addPlan:        return "addPlan"
            case .assign(let d):  return "assign-\(d)"
            case .dayMenu(let d): return "dayMenu-\(d)"
            case .addWorkout:     return "addWorkout"
            case .createWorkout:  return "createWorkout"
            case .activate(let p): return "activate-\(p)"
            }
        }
    }

    /// Chosen start day for the activation sheet's "Pick a date" option.
    @State private var activateDate = Date()
    /// Reveals the inline calendar in the activation sheet.
    @State private var showActivatePicker = false

    /// 12 create-workout picker tiles (4×3), in exact design order.
    struct CreateWorkoutIcon: Identifiable {
        let label: String
        var id: String { label }
    }
    static let createWorkoutIcons: [CreateWorkoutIcon] = [
        "Push", "Pull", "Legs", "Upper", "Weights", "Full Body",
        "Core", "Strength", "Cardio", "Cable", "Hypertrophy", "Recovery"
    ].map(CreateWorkoutIcon.init)

    /// SF Symbol per create-workout tile label.
    private func createWorkoutSymbol(_ label: String) -> String {
        switch label {
        case "Push":        return "flame.fill"
        case "Pull":        return "bolt.fill"
        case "Legs":        return "trophy.fill"
        case "Upper":       return "arrow.up"
        case "Weights":     return "dumbbell.fill"
        case "Full Body":   return "figure.strengthtraining.traditional"
        case "Core":        return "circle.grid.cross.fill"
        case "Strength":    return "figure.strengthtraining.functional"
        case "Cardio":      return "heart.fill"
        case "Cable":       return "cable.connector"
        case "Hypertrophy": return "chart.line.uptrend.xyaxis"
        case "Recovery":    return "leaf.fill"
        default:            return "dumbbell.fill"
        }
    }

    /// Sheet payload: which workout to open in which editor context.
    struct WorkoutEditorTarget: Identifiable {
        let id = UUID()
        let workout: Workout
        let context: WorkoutEditorContext
    }

    // MARK: Derived

    private var defaultPlan: UserPlan? { planDB.defaultPlan }

    private var sourceProgram: Program? {
        defaultPlan?.sourceProgramID.flatMap { programDB.program(id: $0) }
    }

    /// Workouts shown under "Workouts in program" for the active plan.
    private var planWorkouts: [Workout] {
        guard let plan = defaultPlan else { return [] }
        return (sourceProgram?.workouts ?? []) + plan.customWorkouts
    }

    var body: some View {
        AuraScreenScroll {
            VStack(alignment: .leading, spacing: 0) {
                planCarousel
                    .padding(.top, AuraSpacing.s2)

                if let plan = defaultPlan {
                    weekStrip(plan: plan)
                        .padding(.horizontal, 14)
                        .padding(.top, AuraSpacing.s4)

                    workoutsInProgram
                        .padding(.horizontal, 14)
                        .padding(.top, AuraSpacing.s4)
                }

                AuraSectionLabel(title: "Options")
                    .padding(.horizontal, AuraSpacing.screenPad)

                VStack(spacing: 0) {
                    AuraListRow(iconName: "plus.circle", iconColor: .aura.accent,
                                title: "Create Custom Plan") {
                        showCreatePlan = true
                    }
                    Divider().padding(.leading, 52)
                    AuraListRow(iconName: "books.vertical", iconColor: .aura.blue,
                                title: "Browse Programs") {
                        showProgramLibrary = true
                    }
                }
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.horizontal, AuraSpacing.screenPad)
            }
        }
        .background(Color.aura.bgGrouped)
        .sheet(isPresented: $showProgramLibrary) {
            ProgramLibraryView()
        }
        .sheet(isPresented: $showCreatePlan) {
            CreatePlanView()
        }
        .sheet(isPresented: $showBuildProgram) {
            ProgramEditorView(mode: .create)
        }
        .sheet(item: $editingPlan) { plan in
            PlanScheduleEditorView(plan: plan)
        }
        .sheet(item: $editorTarget) { target in
            NavigationStack {
                WorkoutEditorView(workout: target.workout, context: target.context)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            planSheet(sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Delete Plan", isPresented: $showDeleteAlert, presenting: planToDelete) { plan in
            Button("Delete", role: .destructive) {
                planDB.deletePlan(id: plan.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { plan in
            Text("'\(plan.name)' will be permanently deleted.")
        }
        .alert("Remove Workout", isPresented: $showWorkoutDeleteAlert, presenting: workoutToDelete) { w in
            Button("Remove", role: .destructive) { deleteWorkout(w) }
            Button("Cancel", role: .cancel) {}
        } message: { w in
            Text("'\(w.name)' will be removed from this plan.")
        }
    }

    // MARK: Plan carousel (.plan-card)

    private var planCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(planDB.plans.enumerated()), id: \.element.id) { idx, plan in
                    planCard(plan: plan, index: idx)
                }
                addPlanButton
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
        }
    }

    /// Gradient art per card: active = amber, others cycle blue/green
    /// (mirrors .plan-card / .alt / .alt2).
    private func planGradientColors(index: Int, isDefault: Bool) -> [Color] {
        if isDefault { return [Color(hex: "#F59E0B"), Color(hex: "#C85A2C")] }
        let alts: [[Color]] = [
            [Color(hex: "#4A6FB5"), Color(hex: "#3D3A78")],
            [Color(hex: "#3E8C6E"), Color(hex: "#2E6359")],
        ]
        return alts[index % alts.count]
    }

    private func planSubtitle(_ plan: UserPlan) -> String {
        let days = plan.weekSchedule.values.compactMap { $0 }.count
        let level = plan.sourceProgramID
            .flatMap { programDB.program(id: $0) }?.level ?? "Custom"
        return "\(days) days · \(level)"
    }

    @ViewBuilder
    private func planCard(plan: UserPlan, index: Int) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .fill(LinearGradient(colors: planGradientColors(index: index, isDefault: plan.isDefault),
                                     startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(alignment: .leading, spacing: 1) {
                if plan.isDefault {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").font(AuraFont.jakarta(11, .bold))
                        Text("Active").font(AuraFont.jakarta(12, .bold))
                    }
                    .foregroundColor(.aura.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                Spacer()
                Text(plan.name)
                    .font(AuraFont.jakarta(14, .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(planSubtitle(plan))
                    .font(AuraFont.jakarta(12))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(13)
        }
        .frame(width: plan.isDefault ? 150 : 130, height: 120)
        .contextMenu {
            Button {
                // Don't activate immediately — let the user choose the start day
                // (today / tomorrow / a date) so it schedules forward without
                // rewriting the past.
                activateDate = Date()
                showActivatePicker = false
                activeSheet = .activate(planID: plan.id)
            } label: {
                Label("Set as Active", systemImage: "star.fill")
            }
            Button { editingPlan = plan } label: {
                Label("Edit Schedule", systemImage: "calendar")
            }
            Divider()
            Button(role: .destructive) {
                planToDelete = plan
                showDeleteAlert = true
            } label: {
                Label("Delete Plan", systemImage: "trash")
            }
        }
    }

    private var addPlanButton: some View {
        Button { activeSheet = .addPlan } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus").font(AuraFont.jakarta(22, .medium))
                Text("New").font(AuraFont.jakarta(12, .bold))
            }
            .foregroundColor(.aura.text3)
            .frame(width: 96, height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.lg)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundColor(.aura.separator)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Week strip (7 day tiles)

    private func weekStrip(plan: UserPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            AuraSectionLabel(title: "This week").padding(.top, 0)
            WeekStripView(
                calendarStartDay: appState.calendarStartDay,
                workoutForDay: { day in resolveWorkout(entry: plan.weekSchedule[day], plan: plan) },
                onTapDay: { day in
                    // Training day → actions menu; rest/unplanned day → assign.
                    if resolveWorkout(entry: plan.weekSchedule[day], plan: plan) != nil {
                        activeSheet = .dayMenu(day: day)
                    } else {
                        activeSheet = .assign(day: day)
                    }
                }
            )
        }
    }

    // MARK: Workouts in program

    private var workoutsInProgram: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                AuraSectionLabel(title: "Workouts in program").padding(.top, 0)
                Spacer()
                PlanIconButton(icon: "plus", size: 16, diameter: 28, accent: true) {
                    activeSheet = .addWorkout
                }
            }
            .padding(.bottom, 10)

            VStack(spacing: 10) {
                ForEach(planWorkouts) { w in
                    workoutCard(w)
                }
            }
        }
    }

    @ViewBuilder
    private func workoutCard(_ w: Workout) -> some View {
        let theme = workoutTheme(for: w.name)
        let muscles = w.primaryMuscles
            .components(separatedBy: ", ")
            .joined(separator: " · ")
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.color.opacity(0.14))
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.color.opacity(0.35), lineWidth: 1.5))
                Image(systemName: theme.icon)
                    .font(AuraFont.jakarta(20)).foregroundColor(theme.color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(w.name).font(AuraFont.jakarta(15, .heavy)).foregroundColor(.aura.text)
                Text(muscles.isEmpty ? "Custom" : muscles)
                    .font(AuraFont.jakarta(12, .medium)).foregroundColor(theme.color)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 5) {
                Button { editWorkout(w) } label: {
                    smallGlyph("pencil", color: .aura.text)
                }
                Button {
                    workoutToDelete = w
                    showWorkoutDeleteAlert = true
                } label: {
                    smallGlyph("trash", color: .aura.red)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
    }

    private func smallGlyph(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(AuraFont.jakarta(14, .medium))
            .foregroundColor(color)
            .frame(width: 30, height: 30)
            .background(Color.aura.fill.opacity(0.5))
            .clipShape(Circle())
    }

    // MARK: Workout CRUD routing

    private func editWorkout(_ w: Workout) {
        guard let plan = defaultPlan else { return }
        if plan.customWorkouts.contains(where: { $0.id == w.id }) {
            editorTarget = WorkoutEditorTarget(workout: w, context: .editInPlan(planID: plan.id))
        } else if let prog = sourceProgram {
            editorTarget = WorkoutEditorTarget(workout: w, context: .editInProgram(programID: prog.id))
        } else {
            editorTarget = WorkoutEditorTarget(workout: w, context: .view)
        }
    }

    private func deleteWorkout(_ w: Workout) {
        guard var plan = defaultPlan else { return }
        if plan.customWorkouts.contains(where: { $0.id == w.id }) {
            plan.customWorkouts.removeAll { $0.id == w.id }
            // Clear any schedule slots pointing at the removed workout.
            for (day, entry) in plan.weekSchedule where entry == w.id {
                plan.weekSchedule.removeValue(forKey: day)
            }
            planDB.updatePlan(plan)
        } else if let prog = sourceProgram {
            programDB.deleteWorkout(id: w.id, from: prog.id)
        }
    }

    private func resolveWorkout(entry: UUID??, plan: UserPlan) -> Workout? {
        guard let outer = entry, let wid = outer else { return nil }
        if let cw = plan.customWorkouts.first(where: { $0.id == wid }) { return cw }
        return programDB.workout(id: wid)
    }

    // MARK: - Bottom sheets

    @ViewBuilder
    private func planSheet(_ sheet: MyPlanSheet) -> some View {
        switch sheet {
        case .addPlan:            addPlanSheet
        case .assign(let day):    assignSheet(day: day)
        case .dayMenu(let day):   dayMenuSheet(day: day)
        case .addWorkout:         addWorkoutSheet
        case .createWorkout:      createWorkoutSheet
        case .activate(let pid):  activateSheet(planID: pid)
        }
    }

    // MARK: activate (choose start day)

    private func activateSheet(planID: UUID) -> some View {
        let plan = planDB.plans.first { $0.id == planID }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return PlanSheet(title: "Set as Active Plan", subtitle: plan?.name,
                         onClose: { activeSheet = nil }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pick when this plan starts scheduling. Earlier days keep your current plan — nothing already logged is changed.")
                        .font(AuraFont.secondary()).foregroundColor(.aura.text2)
                        .fixedSize(horizontal: false, vertical: true)

                    PlanSourceCard(icon: "bolt.fill", iconBg: .aura.accentSoft, iconTint: .aura.accent,
                                   title: "Start Today", subtitle: "Schedule from today forward") {
                        activate(planID: planID, on: Date())
                    }
                    PlanSourceCard(icon: "sunrise.fill", iconBg: .aura.blue.opacity(0.16), iconTint: .aura.blue,
                                   title: "Start Tomorrow", subtitle: "Keep today on your current plan") {
                        activate(planID: planID, on: tomorrow)
                    }
                    PlanSourceCard(icon: "calendar", iconBg: .aura.green.opacity(0.16), iconTint: .aura.green,
                                   title: "Pick a date",
                                   subtitle: showActivatePicker ? activateDateLabel : "Choose a start day") {
                        withAnimation(.easeInOut(duration: 0.22)) { showActivatePicker.toggle() }
                    }

                    if showActivatePicker {
                        DatePicker("", selection: $activateDate,
                                   in: Calendar.current.startOfDay(for: Date())...,
                                   displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.aura.accent)
                            .padding(.horizontal, 4)

                        AuraPrimaryButton(label: "Start on \(activateDateLabel)") {
                            activate(planID: planID, on: activateDate)
                        }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s2)
                .padding(.bottom, AuraSpacing.s4)
            }
        }
    }

    private var activateDateLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: activateDate)
    }

    /// Commit the activation: the plan becomes default and starts scheduling on
    /// `date`; days before it keep the previously-active plan.
    private func activate(planID: UUID, on date: Date) {
        planDB.setDefault(id: planID, activationDate: date)
        showActivatePicker = false
        activeSheet = nil
    }

    // MARK: add-plan

    private var addPlanSheet: some View {
        PlanSheet(title: "Add to My Plans", onClose: { activeSheet = nil }) {
            VStack(spacing: 12) {
                PlanSourceCard(icon: "square.stack.3d.up.fill", iconBg: .aura.accentSoft, iconTint: .aura.accent,
                               title: "Browse programs", subtitle: "Adopt a predefined program") {
                    activeSheet = nil
                    appState.planSubtabRequest = .programs
                }
                PlanSourceCard(icon: "square.and.pencil", iconBg: .aura.blue.opacity(0.16), iconTint: .aura.blue,
                               title: "Build from scratch", subtitle: "Create a custom program") {
                    activeSheet = nil
                    showBuildProgram = true
                }
                let hasDefault = defaultPlan != nil
                PlanSourceCard(icon: "doc.on.doc.fill",
                               iconBg: hasDefault ? .aura.green.opacity(0.16) : .aura.fill,
                               iconTint: hasDefault ? .aura.green : .aura.text3,
                               title: "Duplicate active plan",
                               subtitle: hasDefault ? "Copy your current plan" : "No active plan to copy") {
                    guard hasDefault else { return }
                    duplicateActivePlan()
                }
                .disabled(!hasDefault)
                .opacity(hasDefault ? 1 : 0.5)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)
            .padding(.bottom, AuraSpacing.s4)
        }
    }

    private func duplicateActivePlan() {
        guard let src = defaultPlan else { return }
        let copy = UserPlan(name: "\(src.name) copy", isDefault: false,
                            sourceProgramID: src.sourceProgramID,
                            weekSchedule: src.weekSchedule, customWorkouts: src.customWorkouts)
        _ = planDB.addPlan(copy)   // DB enforces the 3-plan cap; no-op at cap
        activeSheet = nil
    }

    // MARK: assign

    @ViewBuilder
    private func assignSheet(day: Int) -> some View {
        if let plan = defaultPlan {
            // Read the live entry each render so re-opening reflects current state.
            let current = resolveWorkout(entry: plan.weekSchedule[day], plan: plan)
            PlanSheet(title: "Assign workout", subtitle: dayName(day), onClose: { activeSheet = nil }) {
                VStack(spacing: 10) {
                    ForEach(planWorkouts) { w in
                        let isCurrent = current?.id == w.id
                        Button {
                            planDB.setWorkout(planID: plan.id, dayIndex: day, workoutID: w.id)
                            activeSheet = nil
                        } label: {
                            assignRow(workout: w, selected: isCurrent)
                        }
                        .buttonStyle(.plain)
                    }

                    PlanSourceCard(icon: "plus", iconBg: .aura.accentSoft, iconTint: .aura.accent,
                                   title: "Create new workout", subtitle: "Build a custom workout") {
                        activeSheet = .createWorkout
                    }

                    Button {
                        planDB.setRestDay(planID: plan.id, dayIndex: day)
                        activeSheet = nil
                    } label: {
                        HStack(spacing: AuraSpacing.s3) {
                            Image(systemName: "moon.fill").font(AuraFont.jakarta(16)).foregroundColor(.aura.text3)
                                .frame(width: 24)
                            Text("Keep as Rest Day").font(AuraFont.body()).foregroundColor(.aura.text)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 13)
                        .frame(maxWidth: .infinity)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s2)
                .padding(.bottom, AuraSpacing.s4)
            }
        }
    }

    private func assignRow(workout w: Workout, selected: Bool) -> some View {
        let theme = workoutTheme(for: w.name)
        return HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.color.opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: theme.icon).font(AuraFont.jakarta(18)).foregroundColor(theme.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(w.name).font(AuraFont.jakarta(15, .bold)).foregroundColor(.aura.text)
                Text("\(w.exercises.count) exercises").font(AuraFont.secondary()).foregroundColor(.aura.text2)
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark.circle.fill").font(AuraFont.jakarta(20)).foregroundColor(.aura.accent)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(selected ? Color.aura.accentSoft : Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md)
            .stroke(selected ? Color.aura.accent : Color.aura.separator2, lineWidth: selected ? 2 : 1))
    }

    // MARK: day-menu

    @ViewBuilder
    private func dayMenuSheet(day: Int) -> some View {
        if let plan = defaultPlan, let w = resolveWorkout(entry: plan.weekSchedule[day], plan: plan) {
            PlanSheet(title: w.name, subtitle: dayName(day), onClose: { activeSheet = nil }) {
                PlanList {
                    dayMenuRow(icon: "pencil", bg: .aura.accent, label: "Edit workout") {
                        activeSheet = nil
                        editWorkout(w)
                    }
                    Divider().padding(.leading, 58)
                    dayMenuRow(icon: "arrow.left.arrow.right", bg: .aura.blue, label: "Change workout") {
                        activeSheet = .assign(day: day)
                    }
                    Divider().padding(.leading, 58)
                    dayMenuRow(icon: "moon.fill", bg: Color(hex: "#5A6B8C"), label: "Make it a rest day") {
                        planDB.setRestDay(planID: plan.id, dayIndex: day)
                        activeSheet = nil
                    }
                    Divider().padding(.leading, 58)
                    dayMenuRow(icon: "trash", bg: .aura.red, label: "Remove from program", danger: true) {
                        planDB.clearDay(planID: plan.id, dayIndex: day)
                        activeSheet = nil
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s2)
                .padding(.bottom, AuraSpacing.s4)
            }
        }
    }

    private func dayMenuRow(icon: String, bg: Color, label: String, danger: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AuraRadius.xs).fill(bg).frame(width: 30, height: 30)
                    Image(systemName: icon).foregroundColor(.white).font(AuraFont.jakarta(15, .semibold))
                }
                Text(label).font(AuraFont.jakarta(16, .medium)).foregroundColor(danger ? .aura.red : .aura.text)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    // MARK: add-workout

    private var addWorkoutSheet: some View {
        PlanSheet(title: "Add a Workout", onClose: { activeSheet = nil }) {
            VStack(spacing: 12) {
                PlanSourceCard(icon: "books.vertical.fill", iconBg: .aura.blue.opacity(0.16), iconTint: .aura.blue,
                               title: "From Workout Library", subtitle: "Pick a saved workout") {
                    activeSheet = nil
                    appState.planSubtabRequest = .workouts
                }
                PlanSourceCard(icon: "plus", iconBg: .aura.accentSoft, iconTint: .aura.accent,
                               title: "Create custom workout", subtitle: "Name it, pick an icon, add exercises") {
                    activeSheet = .createWorkout
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)
            .padding(.bottom, AuraSpacing.s4)
        }
    }

    // MARK: create-workout (name + 12-icon grid)

    private var createWorkoutSheet: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        let trimmed = cwName.trimmingCharacters(in: .whitespaces)
        return PlanSheet(title: "Create Workout", onClose: { activeSheet = nil }) {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                TextField("Workout name", text: $cwName)
                    .font(AuraFont.body())
                    .padding(AuraSpacing.s3)
                    .background(Color.aura.fill)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))

                Text("ICON").font(AuraFont.jakarta(11, .bold)).foregroundColor(.aura.text3).tracking(0.6)

                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(Self.createWorkoutIcons) { item in
                        createWorkoutTile(item.label)
                    }
                }

                AuraPrimaryButton(label: "Continue → Add Exercises") {
                    startCreateWorkout(name: trimmed, icon: cwIcon)
                }
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)
            .padding(.bottom, AuraSpacing.s4)
        }
    }

    private func createWorkoutTile(_ label: String) -> some View {
        let selected = cwIcon == label
        let theme = workoutTheme(for: label)
        return Button { cwIcon = label } label: {
            VStack(spacing: 5) {
                Image(systemName: createWorkoutSymbol(label))
                    .font(AuraFont.jakarta(20))
                    .foregroundColor(selected ? theme.color : .aura.text2)
                Text(label)
                    .font(AuraFont.jakarta(10, .bold))
                    .foregroundColor(selected ? theme.color : .aura.text3)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(selected ? theme.color.opacity(0.12) : Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.sm)
                .stroke(selected ? theme.color : Color.aura.separator2, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    /// Build the named workout (colour derived from `workoutTheme(for:)`) and
    /// immediately open the editor in the plan's create context. The editor
    /// persists it on its own Save.
    private func startCreateWorkout(name: String, icon: String) {
        guard !name.isEmpty, let plan = defaultPlan else { return }
        let blank = Workout(name: name, primaryMuscles: icon, estimatedMinutes: 45, exercises: [])
        activeSheet = nil
        editorTarget = WorkoutEditorTarget(workout: blank, context: .createInPlan(planID: plan.id))
        cwName = ""
        cwIcon = Self.createWorkoutIcons[0].label
    }

    private func dayName(_ day: Int) -> String {
        ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"][day]
    }
}

// MARK: - Create Plan View
struct CreatePlanView: View {
    @StateObject private var planDB = UserPlanDatabase.shared
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Plan Details") {
                    TextField("Plan Name", text: $name)
                }
                Section {
                    Text("After creating, use 'Edit Schedule' to assign workouts to days of the week.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
            }
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let plan = UserPlan(
                            name: name.isEmpty ? "My Plan" : name,
                            isDefault: planDB.plans.isEmpty,
                            weekSchedule: [:]
                        )
                        planDB.addPlan(plan)
                        dismiss()
                    }
                    .foregroundColor(.aura.accent)
                }
            }
        }
    }
}

// MARK: - Plan Schedule Editor
struct PlanScheduleEditorView: View {
    @StateObject private var planDB = UserPlanDatabase.shared
    @StateObject private var programDB = ProgramDatabase.shared
    @EnvironmentObject var appState: AppState
    @State var plan: UserPlan
    @Environment(\.dismiss) var dismiss

    private let days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    private var allWorkouts: [Workout] {
        plan.customWorkouts + programDB.allWorkouts
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<7, id: \.self) { i in
                    let entry = plan.weekSchedule[i]
                    let workout: Workout? = {
                        guard let outer = entry, let wid = outer else { return nil }
                        return plan.customWorkouts.first(where: { $0.id == wid })
                            ?? programDB.workout(id: wid)
                    }()

                    dayRow(dayIndex: i, dayName: days[i], workout: workout, isRest: entry != nil && entry! == nil)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        planDB.updatePlan(plan)
                        dismiss()
                    }
                    .foregroundColor(.aura.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func dayRow(dayIndex: Int, dayName: String, workout: Workout?, isRest: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayName)
                .font(AuraFont.jakarta(14, .bold))
                .foregroundColor(.aura.text)

            if let w = workout {
                HStack {
                    Text(w.name)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text)
                    Spacer()
                    Button {
                        plan.weekSchedule.removeValue(forKey: dayIndex)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.aura.text3)
                    }
                }
            } else if isRest {
                HStack {
                    Label("Rest Day", systemImage: "moon.zzz")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text3)
                    Spacer()
                    Button {
                        plan.weekSchedule.removeValue(forKey: dayIndex)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.aura.text3)
                    }
                }
            } else {
                HStack(spacing: AuraSpacing.s2) {
                    Menu {
                        Button("Set as Rest Day") {
                            plan.weekSchedule[dayIndex] = .some(nil)
                        }
                        Divider()
                        ForEach(allWorkouts) { w in
                            Button(w.name) {
                                plan.weekSchedule[dayIndex] = w.id
                            }
                        }
                    } label: {
                        Label("Assign Workout", systemImage: "plus.circle")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.accent)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.aura.surface)
    }
}
