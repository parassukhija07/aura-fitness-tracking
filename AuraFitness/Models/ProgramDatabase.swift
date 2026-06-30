import SwiftUI
import Combine

// MARK: - ProgramDatabase
// Owns all programs (predefined seed + user-created).
// Predefined programs mirror SeedData.programs but are editable per-user.
@MainActor
final class ProgramDatabase: ObservableObject {
    static let shared = ProgramDatabase()

    @Published var programs: [Program] = []

    private let storageKey = "aura_program_db_v1"

    // MARK: Queries
    var predefined: [Program] { programs.filter { $0.isPredefined } }
    var custom: [Program] { programs.filter { !$0.isPredefined } }

    func program(id: UUID) -> Program? { programs.first { $0.id == id } }

    func workout(id: UUID) -> Workout? {
        for prog in programs {
            if let w = prog.workouts.first(where: { $0.id == id }) { return w }
        }
        return nil
    }

    // All workouts across all programs (flat)
    var allWorkouts: [Workout] { programs.flatMap { $0.workouts } }

    // MARK: Program CRUD
    func addProgram(_ program: Program) {
        programs.append(program)
        persist()
    }

    func updateProgram(_ updated: Program) {
        guard let i = programs.firstIndex(where: { $0.id == updated.id }) else { return }
        programs[i] = updated
        persist()
    }

    func deleteProgram(id: UUID) {
        programs.removeAll { $0.id == id && !$0.isPredefined }
        persist()
    }

    // MARK: Workout CRUD within a program
    func addWorkout(_ workout: Workout, to programID: UUID) {
        guard let i = programs.firstIndex(where: { $0.id == programID }) else { return }
        programs[i].workouts.append(workout)
        persist()
    }

    func updateWorkout(_ updated: Workout, in programID: UUID) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }),
              let wi = programs[pi].workouts.firstIndex(where: { $0.id == updated.id }) else { return }
        programs[pi].workouts[wi] = updated
        persist()
    }

    func deleteWorkout(id: UUID, from programID: UUID) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }) else { return }
        programs[pi].workouts.removeAll { $0.id == id }
        persist()
    }

    // Add exercise to workout in program
    func addExercise(_ exercise: Exercise, to workoutID: UUID, in programID: UUID) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }),
              let wi = programs[pi].workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        programs[pi].workouts[wi].exercises.append(exercise)
        persist()
    }

    // Remove exercise from workout
    func removeExercise(id: UUID, from workoutID: UUID, in programID: UUID) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }),
              let wi = programs[pi].workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        programs[pi].workouts[wi].exercises.removeAll { $0.id == id }
        persist()
    }

    // Reorder exercises in workout
    func reorderExercises(workoutID: UUID, programID: UUID, from: IndexSet, to: Int) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }),
              let wi = programs[pi].workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        programs[pi].workouts[wi].exercises.move(fromOffsets: from, toOffset: to)
        persist()
    }

    // MARK: Persistence
    private func persist() {
        guard let data = try? JSONEncoder().encode(programs) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Program].self, from: data),
           !saved.isEmpty {
            programs = saved
        } else {
            programs = SeedData.programs
            persist()
        }
    }

    func resetSeedPrograms() {
        let userCustom = programs.filter { !$0.isPredefined }
        programs = SeedData.programs + userCustom
        persist()
    }
}

// MARK: - UserPlanDatabase
// My Plans — user's personal plan CRUD, schedule management, custom workouts.
@MainActor
final class UserPlanDatabase: ObservableObject {
    static let shared = UserPlanDatabase()

    @Published var plans: [UserPlan] = []

    private let storageKey = "aura_plans_db_v1"

    var defaultPlan: UserPlan? { plans.first { $0.isDefault } }

    // MARK: Plan CRUD
    func addPlan(_ plan: UserPlan) {
        plans.append(plan)
        if plans.count == 1 { setDefault(id: plan.id) }
        persist()
    }

    func updatePlan(_ updated: UserPlan) {
        guard let i = plans.firstIndex(where: { $0.id == updated.id }) else { return }
        plans[i] = updated
        persist()
    }

    func deletePlan(id: UUID) {
        let wasDefault = plans.first(where: { $0.id == id })?.isDefault ?? false
        plans.removeAll { $0.id == id }
        if wasDefault, let first = plans.first {
            setDefault(id: first.id)
        }
        persist()
    }

    func setDefault(id: UUID) {
        for i in plans.indices { plans[i].isDefault = (plans[i].id == id) }
        persist()
    }

    // MARK: Schedule editing
    func setWorkout(planID: UUID, dayIndex: Int, workoutID: UUID?) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].weekSchedule[dayIndex] = workoutID
        persist()
    }

    func setRestDay(planID: UUID, dayIndex: Int) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].weekSchedule[dayIndex] = .some(nil)
        persist()
    }

    func clearDay(planID: UUID, dayIndex: Int) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].weekSchedule.removeValue(forKey: dayIndex)
        persist()
    }

    // MARK: Custom workouts within a plan
    func addCustomWorkout(_ workout: Workout, to planID: UUID) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].customWorkouts.append(workout)
        persist()
    }

    func updateCustomWorkout(_ updated: Workout, in planID: UUID) {
        guard let pi = plans.firstIndex(where: { $0.id == planID }),
              let wi = plans[pi].customWorkouts.firstIndex(where: { $0.id == updated.id }) else { return }
        plans[pi].customWorkouts[wi] = updated
        persist()
    }

    func deleteCustomWorkout(id: UUID, from planID: UUID) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].customWorkouts.removeAll { $0.id == id }
        plans[i].weekSchedule = plans[i].weekSchedule.mapValues { wid in
            wid == id ? Optional(nil) : wid
        }
        persist()
    }

    func addExercise(_ exercise: Exercise, to workoutID: UUID, in planID: UUID) {
        guard let pi = plans.firstIndex(where: { $0.id == planID }),
              let wi = plans[pi].customWorkouts.firstIndex(where: { $0.id == workoutID }) else { return }
        plans[pi].customWorkouts[wi].exercises.append(exercise)
        persist()
    }

    func removeExercise(id: UUID, from workoutID: UUID, in planID: UUID) {
        guard let pi = plans.firstIndex(where: { $0.id == planID }),
              let wi = plans[pi].customWorkouts.firstIndex(where: { $0.id == workoutID }) else { return }
        plans[pi].customWorkouts[wi].exercises.removeAll { $0.id == id }
        persist()
    }

    // MARK: Create plan from existing program
    func createPlan(from program: Program, name: String? = nil) -> UserPlan {
        var plan = UserPlan(
            name: name ?? program.name,
            isDefault: plans.isEmpty,
            sourceProgramID: program.id,
            weekSchedule: [:],
            customWorkouts: []
        )
        // Auto-assign workouts sequentially to weekdays (Mon–Fri for 5-day, etc.)
        let startDay = 2 // Monday
        for (i, workout) in program.workouts.prefix(program.daysPerWeek).enumerated() {
            let dayIdx = (startDay + i) % 7
            plan.weekSchedule[dayIdx] = workout.id
        }
        return plan
    }

    // MARK: Persistence
    private func persist() {
        guard let data = try? JSONEncoder().encode(plans) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([UserPlan].self, from: data),
           !saved.isEmpty {
            plans = saved
        } else {
            // Boot: create default plan from first seed program
            if let prog = SeedData.programs.first {
                let plan = createPlan(from: prog)
                plans = [plan]
            }
            persist()
        }
    }
}
