import SwiftUI

struct MyPlansView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var planDB = UserPlanDatabase.shared
    @StateObject private var programDB = ProgramDatabase.shared
    @State private var showProgramLibrary = false
    @State private var showCreatePlan = false
    @State private var editingPlan: UserPlan? = nil
    @State private var planToDelete: UserPlan? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        AuraScreenScroll {
            VStack(alignment: .leading, spacing: 0) {
                // Plan cards
                AuraSectionLabel(title: "My Plans")
                    .padding(.horizontal, AuraSpacing.screenPad)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AuraSpacing.s3) {
                        ForEach(planDB.plans) { plan in
                            planCard(plan: plan)
                        }
                        addPlanButton
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.vertical, AuraSpacing.s3)
                }

                // Week schedule for default plan
                if let plan = planDB.defaultPlan {
                    AuraSectionLabel(title: "This Week — \(plan.name)")
                        .padding(.horizontal, AuraSpacing.screenPad)
                    weekScheduleView(plan: plan)
                        .padding(.horizontal, AuraSpacing.screenPad)
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
        .alert("Delete Plan", isPresented: $showDeleteAlert, presenting: planToDelete) { plan in
            Button("Delete", role: .destructive) {
                planDB.deletePlan(id: plan.id)
            }
            Button("Cancel", role: .cancel) {}
        } message: { plan in
            Text("'\(plan.name)' will be permanently deleted.")
        }
    }

    // MARK: Plan card
    @ViewBuilder
    private func planCard(plan: UserPlan) -> some View {
        let gradient = LinearGradient(
            colors: plan.isDefault
                ? [.aura.accent.opacity(0.85), .aura.accent.opacity(0.45)]
                : [Color.aura.fill, Color.aura.fill],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AuraRadius.xl)
                .fill(gradient)
                .frame(width: 180, height: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: AuraRadius.xl)
                        .stroke(plan.isDefault ? Color.clear : Color.aura.separator, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                if plan.isDefault {
                    AuraBadge(label: "Active", color: .white)
                }
                Spacer()
                Text(plan.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(plan.isDefault ? .white : .aura.text)
                    .lineLimit(2)
                Text("\(plan.weekSchedule.values.compactMap { $0 }.count) training days")
                    .font(AuraFont.secondary())
                    .foregroundColor(plan.isDefault ? .white.opacity(0.8) : .aura.text2)
            }
            .padding(AuraSpacing.s3)
            .frame(width: 180, height: 120, alignment: .topLeading)
        }
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
        Button { showProgramLibrary = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: AuraRadius.xl)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundColor(.aura.separator)
                    .frame(width: 160, height: 120)
                VStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.aura.text3)
                    Text("Add Plan")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Week schedule
    @ViewBuilder
    private func weekScheduleView(plan: UserPlan) -> some View {
        let days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        VStack(spacing: AuraSpacing.s2) {
            ForEach(0..<7, id: \.self) { i in
                let entry = plan.weekSchedule[i]
                let workout: Workout? = resolveWorkout(entry: entry, plan: plan)
                let isToday = Calendar.current.component(.weekday, from: Date()) - 1 == i

                HStack {
                    Text(days[i])
                        .font(.system(size: 13, weight: isToday ? .heavy : .bold))
                        .foregroundColor(isToday ? .aura.accent : .aura.text2)
                        .frame(width: 36, alignment: .leading)

                    if let w = workout {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.name)
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text)
                            Text("\(w.exercises.count) exercises · ~\(w.estimatedMinutes) min")
                                .font(.system(size: 11))
                                .foregroundColor(.aura.text3)
                        }
                        Spacer()
                        AuraBadge(label: w.primaryMuscles.isEmpty ? "Training" : w.primaryMuscles, color: .aura.accent)
                    } else if entry != nil {
                        Text("Rest")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text3)
                        Spacer()
                        Image(systemName: "moon.zzz")
                            .foregroundColor(.aura.text3)
                            .font(.system(size: 12))
                    } else {
                        Text("Unplanned")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text3)
                        Spacer()
                    }
                }
                .padding(AuraSpacing.s3)
                .background(isToday ? Color.aura.accentSoft : Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: AuraRadius.sm)
                        .stroke(isToday ? Color.aura.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                )
            }
        }
        .padding(.bottom, 8)
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
