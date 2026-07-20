import SwiftUI

// MARK: - Plan tab
//
// Faithful native port of `.design-import-v9/plan/app.jsx` (Phase 4 · 04-plan.html).
// The four sub-tabs render the prototype-styled bodies (PlanSubtabViews) fed by
// the real databases; taps route into the existing DB-backed detail/editor
// screens (ProgramDetailView, WorkoutEditorView, ExerciseEntryDetailView).

struct PlanTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var programDB = ProgramDatabase.shared
    @StateObject private var planDB = UserPlanDatabase.shared
    @StateObject private var exerciseDB = ExerciseDatabase.shared

    private enum Subtab: String, CaseIterable {
        case myplans, programs, workouts, exercises
        var label: String {
            switch self { case .myplans: return "My Plans"; case .programs: return "Programs"
            case .workouts: return "Workouts"; case .exercises: return "Exercises" }
        }
    }

    @State private var subtab: Subtab = .myplans
    @State private var selectedProgram: Program? = nil
    @State private var selectedWorkout: Workout? = nil
    @State private var selectedEntry: ExerciseEntry? = nil
    @State private var showCreateProgram = false
    @State private var showCreateWorkout = false
    @State private var showCreateExercise = false

    var body: some View {
        VStack(spacing: 0) {
            navbar
            Group {
                switch subtab {
                case .myplans:
                    MyPlansView()
                case .programs:
                    PlanProgramsBody(
                        programs: programDB.programs,
                        addedProgramIDs: Set(planDB.plans.compactMap(\.sourceProgramID)),
                        onProgram: { selectedProgram = $0 }
                    )
                case .workouts:
                    NavigationStack {
                        PlanWorkoutsBody(workouts: programDB.allWorkouts,
                                         onEdit: { selectedWorkout = $0 })
                            .background(Color.aura.bg)
                            .toolbar(.hidden, for: .navigationBar)
                            .navigationDestination(item: $selectedWorkout) { w in
                                WorkoutEditorView(workout: w, context: .view)
                            }
                    }
                case .exercises:
                    PlanExercisesBody(entries: exerciseDB.entries,
                                      onExercise: { selectedEntry = $0 })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.aura.bg)
        .sheet(item: $selectedProgram) { program in
            ProgramDetailView(program: program)
        }
        .sheet(item: $selectedEntry) { entry in
            ExerciseEntryDetailView(entry: entry, showActions: true)
        }
        .sheet(isPresented: $showCreateProgram) {
            ProgramEditorView(mode: .create)
        }
        .sheet(isPresented: $showCreateWorkout) {
            WorkoutEditorView(
                workout: Workout(name: "", primaryMuscles: "", estimatedMinutes: 45, exercises: []),
                context: .createStandalone
            )
        }
        .sheet(isPresented: $showCreateExercise) {
            CreateExerciseView()
        }
    }

    private var navbar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Plan").font(AuraFont.largeTitleStyle()).tracking(AuraFont.largeTitleTracking)
                    .foregroundColor(.aura.text)
                Spacer()
                if let create = createAction {
                    PlanIconButton(icon: "plus", accent: true, action: create)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Subtab.allCases, id: \.self) { st in
                        PlanFilterChip(label: st.label, active: subtab == st) { subtab = st }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, AuraSpacing.s1)
        .padding(.bottom, AuraSpacing.s2)
    }

    /// Contextual "+" for the library subtabs (My Plans has its own add flows).
    private var createAction: (() -> Void)? {
        switch subtab {
        case .myplans:   return nil
        case .programs:  return { showCreateProgram = true }
        case .workouts:  return { showCreateWorkout = true }
        case .exercises: return { showCreateExercise = true }
        }
    }
}
