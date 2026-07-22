import SwiftUI
import Combine

// MARK: - ProgramDatabase
// Owns all programs. `SeedData.programs` is empty by design (see SeedData.swift),
// so a fresh install starts with NO programs at all and everything here is
// user-created. The `isPredefined` flag and the predefined/custom split are kept
// because installs made before the seed was dropped still hold predefined rows
// on disk until `SeedPurgeMigration` removes them.
@MainActor
final class ProgramDatabase: ObservableObject {
    static let shared = ProgramDatabase()

    @Published var programs: [Program] = []

    private let storageKey = "aura_program_db_v1"

    /// Guards against a push loop: while applying pulled remote rows, local
    /// `persist()` still runs (disk must match), but writes must NOT be
    /// re-pushed to Supabase (mirrors `AppState.isLoading` at AppState.swift:65).
    private var isApplyingRemote = false

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

    /// Which program (if any) owns a workout id — lets a caller resolve
    /// where to write a permanent edit back to.
    func owningProgramID(forWorkout id: UUID) -> UUID? {
        programs.first { prog in prog.workouts.contains { $0.id == id } }?.id
    }

    // All workouts across all programs (flat)
    var allWorkouts: [Workout] { programs.flatMap { $0.workouts } }

    // MARK: Program CRUD
    func addProgram(_ program: Program) {
        programs.append(program)
        persist()
        syncPush(program)
    }

    func updateProgram(_ updated: Program) {
        guard let i = programs.firstIndex(where: { $0.id == updated.id }) else { return }
        programs[i] = updated
        persist()
        syncPush(updated)
    }

    /// Returns `false` (no-op) if `id` refers to a predefined program —
    /// those can't be deleted by policy. Callers should surface that to the
    /// user (e.g. a toast) rather than failing silently.
    @discardableResult
    func deleteProgram(id: UUID) -> Bool {
        guard let target = programs.first(where: { $0.id == id }), !target.isPredefined else { return false }
        programs.removeAll { $0.id == id }
        persist()
        syncDelete(id: id)
        return true
    }

    // MARK: Workout CRUD within a program
    func addWorkout(_ workout: Workout, to programID: UUID) {
        guard let i = programs.firstIndex(where: { $0.id == programID }) else { return }
        programs[i].workouts.append(workout)
        persist()
        syncPush(programs[i])
    }

    func updateWorkout(_ updated: Workout, in programID: UUID) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }),
              let wi = programs[pi].workouts.firstIndex(where: { $0.id == updated.id }) else { return }
        programs[pi].workouts[wi] = updated
        persist()
        syncPush(programs[pi])
    }

    func deleteWorkout(id: UUID, from programID: UUID) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }) else { return }
        programs[pi].workouts.removeAll { $0.id == id }
        persist()
        syncPush(programs[pi])
    }

    // Add exercise to workout in program
    func addExercise(_ exercise: Exercise, to workoutID: UUID, in programID: UUID) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }),
              let wi = programs[pi].workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        programs[pi].workouts[wi].exercises.append(exercise)
        persist()
        syncPush(programs[pi])
    }

    // Remove exercise from workout
    func removeExercise(id: UUID, from workoutID: UUID, in programID: UUID) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }),
              let wi = programs[pi].workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        programs[pi].workouts[wi].exercises.removeAll { $0.id == id }
        persist()
        syncPush(programs[pi])
    }

    // Reorder exercises in workout
    func reorderExercises(workoutID: UUID, programID: UUID, from: IndexSet, to: Int) {
        guard let pi = programs.firstIndex(where: { $0.id == programID }),
              let wi = programs[pi].workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        programs[pi].workouts[wi].exercises.move(fromOffsets: from, toOffset: to)
        persist()
        syncPush(programs[pi])
    }

    // MARK: - Remote sync hooks
    /// Single chokepoint for every program write-through in this class — all
    /// the CRUD methods above route here, so the ownership gate only has to
    /// exist once.
    private func syncPush(_ program: Program) {
        guard !isApplyingRemote else { return }
        // Predefined programs are identical on every install; syncing them
        // would store the same rows per user for nothing. See Syncable.swift.
        guard program.isSyncable else { return }
        program.syncPush(table: .programs)
    }
    private func syncDelete(id: UUID) {
        guard !isApplyingRemote else { return }
        SupabaseSyncService.shared.delete(id: id.uuidString, table: .programs)
    }

    /// Replaces `programs` with pulled remote rows + un-pulled local
    /// customs, without re-pushing (guards the push loop). Predefined
    /// programs are preserved by ID; any local custom program not present
    /// remotely is kept as-is (LWW already decided the push direction).
    /// Non-syncable rows are dropped on the way in: devices predating the
    /// ownership policy pushed their predefined programs, and those legacy
    /// rows must never overwrite the local seed (they carry another install's
    /// random ids and stale content). Belt-and-braces alongside the push gate
    /// in `syncPush` and the one-time `cleanupPredefinedRemoteRows` sweep.
    func applyRemote(_ remotePrograms: [Program]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        var byID: [UUID: Program] = [:]
        for p in programs { byID[p.id] = p }
        for p in remotePrograms where p.isSyncable { byID[p.id] = p }
        programs = Array(byID.values)
        persist()
    }

    /// Drops programs deleted on another device, as reported by the
    /// `aura_deletions` tombstones in a delta pull. Distinct from
    /// `applyRemote` (a union merge that can only ever ADD rows) — without
    /// this, a remote delete is invisible to a pulling client and the row
    /// gets re-pushed on the next local write. Guarded like every other
    /// remote apply so removing the row doesn't echo a delete back up.
    func applyRemoteDeletions(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        let before = programs.count
        programs.removeAll { ids.contains($0.id) }
        guard programs.count != before else { return }
        persist()
    }

    /// Drops predefined programs, preserving any user-created custom programs
    /// (used by DataResetService — NOT a full wipe; see `hardReset()`). There
    /// is no seed to restore any more, so this only ever removes.
    func resetToSeed() {
        resetSeedPrograms()
    }

    /// Drops ALL programs (predefined + custom) — distinct from
    /// `resetToSeed()`/`resetSeedPrograms()` which preserves customs.
    func hardReset() {
        programs = []
        persist()
    }

    /// Rewrites the ids of already-persisted predefined programs and their
    /// workouts to the deterministic `StableID` values, matching by name.
    /// Returns the old -> new id map so callers can fix every reference held
    /// elsewhere (plan schedules, day overrides) before those references
    /// dangle. Run once, by `SeedIDMigration`.
    ///
    /// Custom programs are untouched — their ids were user-generated and are
    /// already unique and meaningful.
    ///
    /// Inert now that `SeedData.programs` is empty: the name lookup below finds
    /// nothing, so the map comes back empty and every caller no-ops. Kept
    /// because `SeedIDMigration` still runs on upgrade, and deleting it would
    /// only move the no-op somewhere less obvious. `SeedPurgeMigration` removes
    /// the rows this used to renumber.
    func migrateSeedIDs() -> [UUID: UUID] {
        var map: [UUID: UUID] = [:]
        let seedByName = Dictionary(SeedData.programs.map { ($0.name, $0) },
                                    uniquingKeysWith: { first, _ in first })

        for i in programs.indices where programs[i].isPredefined {
            guard let seed = seedByName[programs[i].name] else { continue }
            if programs[i].id != seed.id {
                map[programs[i].id] = seed.id
                programs[i].id = seed.id
            }
            let seedWorkoutIDs = Dictionary(seed.workouts.map { ($0.name, $0.id) },
                                            uniquingKeysWith: { first, _ in first })
            for j in programs[i].workouts.indices {
                guard let newID = seedWorkoutIDs[programs[i].workouts[j].name] else { continue }
                let oldID = programs[i].workouts[j].id
                guard oldID != newID else { continue }
                map[oldID] = newID
                programs[i].workouts[j].id = newID
            }
        }

        guard !map.isEmpty else { return [:] }
        persist()
        return map
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
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([Program].self, from: data) else { return }
        // An empty array is now a legitimate persisted state, not a signal to
        // re-seed, so it is decoded and kept like any other. Nothing is written
        // back here: an install with no programs must leave the key absent so
        // this stays a pure read.
        programs = saved
    }

    func resetSeedPrograms() {
        programs = programs.filter { !$0.isPredefined }
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

    /// Guards against a push loop while applying pulled remote rows.
    private var isApplyingRemote = false

    var defaultPlan: UserPlan? { plans.first { $0.isDefault } }

    /// Which plan (if any) owns a custom-workout id — lets a caller resolve
    /// where to write a permanent edit back to.
    func owningPlanID(forCustomWorkout id: UUID) -> UUID? {
        plans.first { plan in plan.customWorkouts.contains { $0.id == id } }?.id
    }

    /// §3.1.1 — My Plans caps adopted plans at 3.
    static let maxPlans = 3

    // MARK: Plan CRUD
    /// Returns `false` (no-op) if the plan cap (`maxPlans`) is already reached.
    @discardableResult
    func addPlan(_ plan: UserPlan) -> Bool {
        guard plans.count < Self.maxPlans else { return false }
        plans.append(plan)
        if plans.count == 1 { setDefault(id: plan.id) }
        persist()
        syncPush(plan)
        return true
    }

    func updatePlan(_ updated: UserPlan) {
        guard let i = plans.firstIndex(where: { $0.id == updated.id }) else { return }
        plans[i] = updated
        persist()
        syncPush(updated)
    }

    func deletePlan(id: UUID) {
        let wasDefault = plans.first(where: { $0.id == id })?.isDefault ?? false
        plans.removeAll { $0.id == id }
        if wasDefault, let first = plans.first {
            setDefault(id: first.id)
        }
        persist()
        syncDelete(id: id)
    }

    func setDefault(id: UUID) {
        for i in plans.indices { plans[i].isDefault = (plans[i].id == id) }
        persist()
        for plan in plans { syncPush(plan) }
    }

    // MARK: Schedule editing
    func setWorkout(planID: UUID, dayIndex: Int, workoutID: UUID?) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].weekSchedule[dayIndex] = workoutID
        persist()
        syncPush(plans[i])
    }

    func setRestDay(planID: UUID, dayIndex: Int) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].weekSchedule[dayIndex] = .some(nil)
        persist()
        syncPush(plans[i])
    }

    func clearDay(planID: UUID, dayIndex: Int) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].weekSchedule.removeValue(forKey: dayIndex)
        persist()
        syncPush(plans[i])
    }

    // MARK: Custom workouts within a plan
    func addCustomWorkout(_ workout: Workout, to planID: UUID) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].customWorkouts.append(workout)
        persist()
        syncPush(plans[i])
    }

    func updateCustomWorkout(_ updated: Workout, in planID: UUID) {
        guard let pi = plans.firstIndex(where: { $0.id == planID }),
              let wi = plans[pi].customWorkouts.firstIndex(where: { $0.id == updated.id }) else { return }
        plans[pi].customWorkouts[wi] = updated
        persist()
        syncPush(plans[pi])
    }

    func deleteCustomWorkout(id: UUID, from planID: UUID) {
        guard let i = plans.firstIndex(where: { $0.id == planID }) else { return }
        plans[i].customWorkouts.removeAll { $0.id == id }
        plans[i].weekSchedule = plans[i].weekSchedule.mapValues { wid in
            wid == id ? Optional(nil) : wid
        }
        persist()
        syncPush(plans[i])
    }

    func addExercise(_ exercise: Exercise, to workoutID: UUID, in planID: UUID) {
        guard let pi = plans.firstIndex(where: { $0.id == planID }),
              let wi = plans[pi].customWorkouts.firstIndex(where: { $0.id == workoutID }) else { return }
        plans[pi].customWorkouts[wi].exercises.append(exercise)
        persist()
        syncPush(plans[pi])
    }

    func removeExercise(id: UUID, from workoutID: UUID, in planID: UUID) {
        guard let pi = plans.firstIndex(where: { $0.id == planID }),
              let wi = plans[pi].customWorkouts.firstIndex(where: { $0.id == workoutID }) else { return }
        plans[pi].customWorkouts[wi].exercises.removeAll { $0.id == id }
        persist()
        syncPush(plans[pi])
    }

    /// Auto-assign workouts sequentially to weekdays, then insert + persist.
    /// `startDay` is 0=Sunday, 1=Monday — pass `appState.calendarStartDay`
    /// (defaults to Monday, matching most training-split conventions when no
    /// preference is available, e.g. during boot-time seeding).
    @discardableResult
    func addPlan(from program: Program, name: String? = nil, startDay: Int = 1) -> UserPlan {
        var plan = UserPlan(
            name: name ?? program.name,
            isDefault: plans.isEmpty,
            sourceProgramID: program.id,
            weekSchedule: [:],
            customWorkouts: []
        )
        for (i, workout) in program.workouts.prefix(program.daysPerWeek).enumerated() {
            let dayIdx = (startDay + i) % 7
            plan.weekSchedule[dayIdx] = workout.id
        }
        addPlan(plan)
        return plan
    }

    // MARK: - Remote sync hooks
    private func syncPush(_ plan: UserPlan) {
        guard !isApplyingRemote else { return }
        plan.syncPush(table: .plans)
    }
    private func syncDelete(id: UUID) {
        guard !isApplyingRemote else { return }
        SupabaseSyncService.shared.delete(id: id.uuidString, table: .plans)
    }

    /// Replaces `plans` with pulled remote rows merged over local (LWW
    /// already decided direction upstream), without re-pushing.
    ///
    /// An empty result is left empty. This used to re-seed a default plan, but
    /// with no seed programs to build one from, "no plans" is simply the state
    /// of an account whose owner has not made one yet.
    func applyRemote(_ remotePlans: [UserPlan]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        var byID: [UUID: UserPlan] = [:]
        for p in plans { byID[p.id] = p }
        for p in remotePlans { byID[p.id] = p }
        plans = Array(byID.values)
        persist()
    }

    /// Repoints every reference a plan holds at a seeded program or workout
    /// from its old random id to the new deterministic one. Without this the
    /// `migrateSeedIDs()` rewrite would orphan `weekSchedule` — every day
    /// would resolve to no workout at all.
    ///
    /// The remapped plans ARE pushed: plans sync, and a device that has
    /// migrated must publish the stable ids so other devices converge instead
    /// of trading references neither can resolve.
    func remapSeedReferences(_ map: [UUID: UUID]) {
        guard !map.isEmpty else { return }
        var changed = false

        for i in plans.indices {
            if let source = plans[i].sourceProgramID, let newID = map[source] {
                plans[i].sourceProgramID = newID
                changed = true
            }
            for (day, entry) in plans[i].weekSchedule {
                guard let workoutID = entry, let newID = map[workoutID] else { continue }
                plans[i].weekSchedule[day] = newID
                changed = true
            }
        }

        guard changed else { return }
        persist()
        for plan in plans { syncPush(plan) }
    }

    /// Drops plans deleted on another device, as reported by the
    /// `aura_deletions` tombstones in a delta pull.
    ///
    /// If the tombstones remove the last plan, the user is left with none —
    /// that is what they asked for on the other device. Re-seeding one here
    /// would resurrect a plan the delete was meant to get rid of.
    func applyRemoteDeletions(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        let before = plans.count
        plans.removeAll { ids.contains($0.id) }
        guard plans.count != before else { return }
        persist()
    }

    /// Removes plans adopted from programs that no longer exist, and clears
    /// any scheduled day still pointing at one of their workouts. Used once, by
    /// `SeedPurgeMigration`; plans the user built themselves are untouched.
    ///
    /// A dropped reference becomes an explicit rest day (`.some(nil)`) rather
    /// than a removed key, so the week keeps its shape instead of silently
    /// re-collapsing to "unplanned".
    func purge(programIDs: Set<UUID>, workoutIDs: Set<UUID>) {
        guard !programIDs.isEmpty || !workoutIDs.isEmpty else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }

        plans.removeAll { plan in
            guard let source = plan.sourceProgramID else { return false }
            return programIDs.contains(source)
        }
        for i in plans.indices {
            for (day, entry) in plans[i].weekSchedule {
                guard let workoutID = entry, workoutIDs.contains(workoutID) else { continue }
                plans[i].weekSchedule[day] = .some(nil)
            }
        }

        // `isDefault` can leave with the plan that held it.
        if !plans.isEmpty, !plans.contains(where: { $0.isDefault }) {
            plans[0].isDefault = true
        }
        // Persisted unconditionally: this runs once behind a done-flag, so a
        // redundant write costs one encode rather than needing `UserPlan` to
        // gain an `Equatable` conformance purely to detect a no-op.
        persist()
    }

    /// Drops every plan. Named `resetToSeed()` for symmetry with the other
    /// stores' reset entry points (DataResetService calls all three); there is
    /// no seed to restore, so reset means empty.
    func resetToSeed() {
        plans = []
        persist()
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
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([UserPlan].self, from: data) else { return }
        // No boot-time seeding: a fresh install has no plans until the user
        // creates one. An empty persisted array is decoded and kept as-is.
        plans = saved
    }
}

// MARK: - SeedIDMigration
//
// One-shot upgrade for installs created before seeded programs/workouts got
// deterministic ids (see `StableID` in SeedData.swift). Those installs hold
// random per-install ids on disk, which is why a plan synced to a second
// device used to resolve to an empty week.
//
// Order is load-bearing: the id rewrite has to happen FIRST, and every holder
// of a reference has to be repointed in the same pass, or the references
// dangle. Fresh installs seed with stable ids already, so the map comes back
// empty and every step below no-ops.
@MainActor
enum SeedIDMigration {
    private static let doneKey = "aura_stable_seed_ids_v1"

    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }

        let map = ProgramDatabase.shared.migrateSeedIDs()
        if !map.isEmpty {
            UserPlanDatabase.shared.remapSeedReferences(map)
            AppStateBridge.shared?.remapSeedReferences(map)
        }

        // Set on completion regardless of whether anything moved: an empty map
        // means there was nothing to migrate, which is just as done.
        UserDefaults.standard.set(true, forKey: doneKey)
    }
}

// MARK: - SeedPurgeMigration
//
// One-shot cleanup for installs created while the app still shipped starter
// content: five predefined programs, a "My PPL Plan" adopted from the first of
// them, and an example body profile (Alex Jordan, 178 cm / 78.4 kg).
//
// Dropping the seed from the source only changes what a FRESH install builds.
// Everything above was written to UserDefaults the first time the app launched,
// so without this pass an existing device keeps showing all of it forever.
//
// Deliberately surgical rather than a `DataResetService.resetAll`: it removes
// only rows the app itself created, and never touches a program, plan, log,
// measurement or PR the user entered. Anything the user made survives — that is
// the difference between clearing seed data and wiping an account.
@MainActor
enum SeedPurgeMigration {
    private static let doneKey = "aura_seed_purge_v1"

    /// The example profile as it shipped. Matched in full before clearing, so a
    /// user who edited even one field keeps everything they typed.
    private static let mockFirstName = "Alex"
    private static let mockLastName = "Jordan"
    private static let mockHeight: Double = 178
    private static let mockWeight: Double = 78.4

    static func runIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: doneKey) else { return }
        // Set first: a crash midway must not leave this looping on every launch,
        // and each step below is independently safe to have skipped.
        UserDefaults.standard.set(true, forKey: doneKey)

        purgeSeededPrograms()
        purgeMockProfile()
    }

    /// Order matters: the program ids have to be collected BEFORE the programs
    /// are removed, or there is nothing left to match the plans against.
    private static func purgeSeededPrograms() {
        let seeded = ProgramDatabase.shared.predefined
        guard !seeded.isEmpty else { return }

        let programIDs = Set(seeded.map(\.id))
        let workoutIDs = Set(seeded.flatMap { $0.workouts.map(\.id) })

        ProgramDatabase.shared.resetSeedPrograms()   // keeps user-created customs
        UserPlanDatabase.shared.purge(programIDs: programIDs, workoutIDs: workoutIDs)
        AppStateBridge.shared?.purgeDayOverrides(workoutIDs: workoutIDs)
    }

    /// Clears the example body profile only while it is still untouched. The
    /// email is left alone either way — it comes from the account, not the seed.
    private static func purgeMockProfile() {
        guard let state = AppStateBridge.shared else { return }

        if state.userProfile.firstName == mockFirstName,
           state.userProfile.lastName == mockLastName {
            let email = state.userProfile.email
            state.resetUserProfile()
            state.userProfile.email = email
        }

        if state.bodyStats.height == mockHeight, state.bodyStats.weight == mockWeight {
            state.resetBodyStats()
        }
    }
}
