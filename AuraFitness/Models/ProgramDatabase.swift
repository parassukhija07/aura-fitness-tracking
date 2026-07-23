import SwiftUI
import Combine

// MARK: - ProgramDatabase
// Owns all programs: the bundled library (`SeedData.programs`, flagged
// `isPredefined`) plus everything the user built. The library is reference
// content — it backs the Plan tab's Programs and Workouts subtabs, and nothing
// here adopts any of it into My Plans; see the policy note in SeedData.swift.
//
// `mergeLibrary()` keeps that library present rather than trusting whatever was
// last persisted, so a device that has been through a version carrying a
// different library — including the version that shipped none at all — picks up
// the current one on its next launch.
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
        // `byID.values` comes out in hash order, which would reshuffle the
        // Programs list on every pull. Restores the library's own order at the
        // front and persists if anything moved.
        mergeLibrary()
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

    /// Restores the bundled library, preserving any user-created custom
    /// programs (used by DataResetService — NOT a full wipe; see `hardReset()`).
    func resetToSeed() {
        resetSeedPrograms()
    }

    /// Drops user-created programs and returns the library to what shipped —
    /// distinct from `resetToSeed()`/`resetSeedPrograms()`, which keep customs.
    func hardReset() {
        programs = SeedData.programs
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
    /// Only matches by name, so it renumbers a persisted program solely when
    /// the CURRENT library ships one under the same name. The five retired
    /// programs are no longer in the library, so they fall through to
    /// `SeedPurgeMigration`, which removes them outright.
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
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([Program].self, from: data) {
            programs = saved
        }
        // Runs whether or not anything was decoded: a fresh install has no key
        // at all, and an install upgrading from the version that shipped no
        // library has the key with the library missing from it. Both need the
        // same fill.
        mergeLibrary()
    }

    /// Puts the bundled library at the front of `programs`, in the library's
    /// own order, adding any entry that isn't already there.
    ///
    /// A library program ALREADY on disk is kept as-is rather than replaced:
    /// `addWorkout`/`updateWorkout` can write to a predefined program, and
    /// overwriting here would silently revert that. New releases therefore add
    /// programs and reorder them, but never rewrite one the device already has.
    private func mergeLibrary() {
        let library = SeedData.programs
        guard !library.isEmpty else { return }

        let onDisk = Dictionary(programs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let libraryIDs = Set(library.map(\.id))
        let merged = library.map { onDisk[$0.id] ?? $0 }
                   + programs.filter { !libraryIDs.contains($0.id) }

        // Comparing the id sequence catches an addition, a removal and a
        // reorder in one go, and avoids needing `Program: Equatable`.
        guard merged.map(\.id) != programs.map(\.id) else { return }
        programs = merged
        persist()
    }

    /// Removes specific programs by id, whatever their `isPredefined` flag —
    /// the one path that can drop a predefined program, used by
    /// `SeedPurgeMigration` to retire content that shipped in an earlier
    /// version. Deliberately not routed through `deleteProgram(id:)`, which
    /// refuses predefined rows by policy and would push a tombstone for a row
    /// that never synced.
    func removePrograms(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let before = programs.count
        programs.removeAll { ids.contains($0.id) }
        guard programs.count != before else { return }
        persist()
    }

    /// Discards local edits to library programs and restores them as shipped,
    /// keeping user-created ones. The filter-then-merge is what makes it a
    /// RESTORE rather than a top-up: `mergeLibrary()` alone would keep whatever
    /// is already on disk, which is the opposite of what a reset is for.
    func resetSeedPrograms() {
        programs = programs.filter { !$0.isPredefined }
        mergeLibrary()
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

    /// Make a plan the default, recording the day its schedule starts applying.
    ///
    /// `activationDate` (start-of-day) gates the Log calendar: the plan only
    /// schedules workouts on that day and after. Days before it fall back to
    /// the previously-active plan, so the switch never rewrites past days.
    /// Defaults to today. A plan being *demoted* keeps (or inherits
    /// `.distantPast`) its activation so it stays the schedule source for the
    /// dates before the new plan begins.
    func setDefault(id: UUID, activationDate: Date? = nil) {
        let effective = Calendar.current.startOfDay(for: activationDate ?? Date())
        for i in plans.indices {
            if plans[i].id == id {
                plans[i].isDefault = true
                plans[i].activationDate = effective
            } else {
                plans[i].isDefault = false
                if plans[i].activationDate == nil { plans[i].activationDate = .distantPast }
            }
        }
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

    /// Lay the program's week onto the user's calendar, then insert + persist.
    /// `startDay` is 0=Sunday, 1=Monday — pass `appState.calendarStartDay`
    /// (defaults to Monday, matching most training-split conventions when no
    /// preference is available).
    ///
    /// A program that declares a `weekPattern` is copied day for day from its
    /// own day 1, rest days included: a lower-body program that trains days 2,
    /// 4 and 6 must not collapse into three sessions back to back, and one that
    /// repeats a session inside the week has to repeat it here too. Rest lands
    /// as `.some(nil)` — an explicit rest day, not an unplanned one.
    ///
    /// Programs without a pattern (anything built in the editor) keep the old
    /// behaviour: workouts fill consecutive days from `startDay`.
    @discardableResult
    func addPlan(from program: Program, name: String? = nil, startDay: Int = 1) -> UserPlan {
        var plan = UserPlan(
            name: name ?? program.name,
            isDefault: plans.isEmpty,
            sourceProgramID: program.id,
            weekSchedule: [:],
            customWorkouts: []
        )
        if program.weekPattern.isEmpty {
            for (i, workout) in program.workouts.prefix(program.daysPerWeek).enumerated() {
                plan.weekSchedule[(startDay + i) % 7] = workout.id
            }
        } else {
            for (i, workoutID) in program.weekPattern.prefix(7).enumerated() {
                plan.weekSchedule[(startDay + i) % 7] = .some(workoutID)
            }
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

    /// The five programs that shipped as starter content, matched BY NAME.
    ///
    /// Name, not id, and not the `isPredefined` flag: these installs may hold
    /// either the old random ids or the `StableID` ones depending on when they
    /// upgraded, and `isPredefined` is now also worn by the bundled library —
    /// purging on that flag would wipe the library this migration runs
    /// alongside. Nothing else is retired, so this list stays frozen.
    private static let retiredPrograms: Set<String> = [
        "Push · Pull · Legs", "StrongLifts 5×5", "Upper / Lower", "Full Body 3×", "HIIT Cardio"
    ]

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
        let retired = ProgramDatabase.shared.programs.filter { retiredPrograms.contains($0.name) }
        guard !retired.isEmpty else { return }

        let programIDs = Set(retired.map(\.id))
        let workoutIDs = Set(retired.flatMap { $0.workouts.map(\.id) })

        ProgramDatabase.shared.removePrograms(ids: programIDs)
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
