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
    @State private var showAddPlanOptions = false
    @State private var editingPlan: UserPlan? = nil
    @State private var planToDelete: UserPlan? = nil
    @State private var showDeleteAlert = false
    @State private var editorTarget: WorkoutEditorTarget? = nil
    @State private var workoutToDelete: Workout? = nil
    @State private var showWorkoutDeleteAlert = false

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
        .sheet(item: $editingPlan) { plan in
            PlanScheduleEditorView(plan: plan)
        }
        .sheet(item: $editorTarget) { target in
            NavigationStack {
                WorkoutEditorView(workout: target.workout, context: target.context)
            }
        }
        .confirmationDialog("Add Plan", isPresented: $showAddPlanOptions) {
            Button("Browse Programs") { showProgramLibrary = true }
            Button("Create Custom Plan") { showCreatePlan = true }
            Button("Cancel", role: .cancel) {}
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
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                        Text("Active").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.aura.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                Spacer()
                Text(plan.name)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(planSubtitle(plan))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(13)
        }
        .frame(width: plan.isDefault ? 150 : 130, height: 120)
        .contextMenu {
            Button {
                planDB.setDefault(id: plan.id)
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
        Button { showAddPlanOptions = true } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 22, weight: .medium))
                Text("New").font(.system(size: 12, weight: .bold))
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
        // weekSchedule keys: 0=Sun … 6=Sat; order honours the calendar-start pref.
        let order = appState.calendarStartDay == 0 ? [0, 1, 2, 3, 4, 5, 6] : [1, 2, 3, 4, 5, 6, 0]
        let labels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

        return VStack(alignment: .leading, spacing: 10) {
            AuraSectionLabel(title: "This week").padding(.top, 0)
            HStack(spacing: 4) {
                ForEach(order, id: \.self) { day in
                    dayTile(day: day, label: labels[day], plan: plan)
                }
            }
        }
    }

    @ViewBuilder
    private func dayTile(day: Int, label: String, plan: UserPlan) -> some View {
        let workout = resolveWorkout(entry: plan.weekSchedule[day], plan: plan)
        let isRest = workout == nil
        let c = planWkStyle(workout?.name)
        let shortName = workout.map {
            $0.name.replacingOccurrences(of: "workout", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: " ").first ?? ""
        } ?? "Rest"

        Button { editingPlan = plan } label: {
            VStack(spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(isRest ? .aura.text3 : c.tint)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isRest ? Color.aura.fill : c.bg)
                        .frame(width: 34, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isRest ? Color.aura.separator2 : c.border.opacity(0.45), lineWidth: 1.5)
                        )
                    Image(systemName: isRest ? "moon.fill" : planWkIcon(workout?.name))
                        .font(.system(size: isRest ? 14 : 16))
                        .foregroundColor(isRest ? .aura.text3 : c.tint)
                }
                Text(shortName)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isRest ? .aura.text3 : c.tint)
                    .lineLimit(1)
                    .frame(maxWidth: 34)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 2)
            .background(isRest ? Color.clear : c.bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRest ? Color.aura.separator2 : c.border.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Workouts in program

    private var workoutsInProgram: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                AuraSectionLabel(title: "Workouts in program").padding(.top, 0)
                Spacer()
                PlanIconButton(icon: "plus", size: 16, diameter: 28, accent: true) {
                    addWorkout()
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
        let c = planWkStyle(w.name)
        let muscles = w.primaryMuscles
            .components(separatedBy: ", ")
            .joined(separator: " · ")
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(c.bg)
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(c.border.opacity(0.35), lineWidth: 1.5))
                Image(systemName: planWkIcon(w.name))
                    .font(.system(size: 20)).foregroundColor(c.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(w.name).font(.system(size: 15, weight: .heavy)).foregroundColor(.aura.text)
                Text(muscles.isEmpty ? "Custom" : muscles)
                    .font(.system(size: 12, weight: .medium)).foregroundColor(c.tint)
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
            .font(.system(size: 14, weight: .medium))
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

    private func addWorkout() {
        guard let plan = defaultPlan else { return }
        let blank = Workout(name: "", primaryMuscles: "", estimatedMinutes: 45, exercises: [])
        if let prog = sourceProgram {
            editorTarget = WorkoutEditorTarget(workout: blank, context: .createInProgram(programID: prog.id))
        } else {
            editorTarget = WorkoutEditorTarget(workout: blank, context: .createInPlan(planID: plan.id))
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
                .font(.system(size: 14, weight: .bold))
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
