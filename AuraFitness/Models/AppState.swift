import SwiftUI
import Combine

enum DarkModePreference: String, CaseIterable, Codable {
    case off, auto, on

    var label: String {
        switch self {
        case .off:  return "Off"
        case .auto: return "Auto"
        case .on:   return "On"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .off:  return .light
        case .auto: return nil
        case .on:   return .dark
        }
    }
}

@MainActor
class AppState: ObservableObject {
    // MARK: - Persistence keys (mirror shell.jsx localStorage keys)
    // NOTE: "aura_seeded_missed_v1" is now an orphaned key in existing installs —
    // it was used to persist the removed demo-only `seededMissed` mechanism and
    // is intentionally never read or written again (no migration/cleanup needed).
    private enum Keys {
        static let dark     = "aura_dark"      // DarkModePreference rawValue
        static let calStart = "aura_calstart"  // "Sun" | "Mon"
        static let logStat  = "aura_logstat"   // "Strength Score" | "Strength Balance" | "Both"
        static let workoutLogs      = "aura_workout_logs_v1"
        static let dayOverrides     = "aura_day_overrides_v1"
        static let quickLogs        = "aura_quick_logs_v1"
        static let measurements     = "aura_measurements_v1"
        static let bodyStats        = "aura_body_stats_v1"
        static let personalRecords  = "aura_personal_records_v1"
        static let userProfile      = "aura_user_profile_v1"
        static let progressPhotos   = "aura_progress_photos_v1"
        static let workoutPrefs     = "aura_workout_prefs_v1"  // bundles the preference scalars (see below)
    }

    /// Bundles the scattered workout-preference scalars into a single persisted blob.
    private struct WorkoutPrefs: Codable {
        var defaultSets: Int
        var defaultRepLow: Int
        var defaultRepHigh: Int
        var defaultRestBetweenSets: Int
        var defaultRestBetweenExercises: Int
        var autoRestTimer: Bool
        var autoPlayVideo: Bool
        var showPRsDuringWorkout: Bool
        var showRepsFirst: Bool
        var weightUnit: String
        var lengthUnit: String
        var notificationsEnabled: Bool
        var restSound: String
        var appleHealthConnected: Bool
        var googleHealthConnected: Bool
    }

    /// When true, `didSet` writers don't persist (used while loading in `init`).
    private var isLoading = false

    /// Combine subscriptions bridging external ObservableObject singletons
    /// (e.g. UserPlanDatabase, ProgramDatabase) into AppState.objectWillChange.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Appearance
    @Published var darkModePreference: DarkModePreference = .auto {
        didSet { persist(Keys.dark, darkModePreference.rawValue) }
    }

    // MARK: - Settings
    @Published var calendarStartDay: Int = 0 {       // 0=Sun, 1=Mon
        didSet { persist(Keys.calStart, calendarStartDay == 1 ? "Mon" : "Sun") }
    }
    @Published var logDisplayMode: String = "Both" { // "Strength Score" | "Strength Balance" | "Both"
        didSet { persist(Keys.logStat, logDisplayMode) }
    }

    // MARK: - Init: restore persisted cross-tab settings (defaults on fresh install)
    init() {
        isLoading = true
        let d = UserDefaults.standard
        if let raw = d.string(forKey: Keys.dark), let pref = DarkModePreference(rawValue: raw) {
            darkModePreference = pref
        }
        if let cs = d.string(forKey: Keys.calStart) {
            calendarStartDay = (cs == "Mon") ? 1 : 0
        }
        if let ls = d.string(forKey: Keys.logStat) {
            logDisplayMode = ls
        }
        if let v = loadCodable([WorkoutLog].self, Keys.workoutLogs)      { workoutLogs = v }
        if let v = loadCodable([String: DayOverride].self, Keys.dayOverrides) { dayOverrides = v }
        if let v = loadCodable([String: QuickLog].self, Keys.quickLogs)  { quickLogs = v }
        if let v = loadCodable([Measurement].self, Keys.measurements)    { measurements = v }
        if let v = loadCodable(BodyStats.self, Keys.bodyStats)           { bodyStats = v }
        if let v = loadCodable([PersonalRecord].self, Keys.personalRecords) { personalRecords = v }
        if let v = loadCodable(UserProfile.self, Keys.userProfile)       { userProfile = v }
        if let v = loadCodable([ProgressPhoto].self, Keys.progressPhotos){ progressPhotos = v }
        if let p = loadCodable(WorkoutPrefs.self, Keys.workoutPrefs) {
            defaultSets = p.defaultSets; defaultRepLow = p.defaultRepLow; defaultRepHigh = p.defaultRepHigh
            defaultRestBetweenSets = p.defaultRestBetweenSets; defaultRestBetweenExercises = p.defaultRestBetweenExercises
            autoRestTimer = p.autoRestTimer; autoPlayVideo = p.autoPlayVideo
            showPRsDuringWorkout = p.showPRsDuringWorkout; showRepsFirst = p.showRepsFirst
            weightUnit = p.weightUnit; lengthUnit = p.lengthUnit
            notificationsEnabled = p.notificationsEnabled; restSound = p.restSound
            appleHealthConnected = p.appleHealthConnected; googleHealthConnected = p.googleHealthConnected
        }
        isLoading = false

        // Bridge UserPlanDatabase/ProgramDatabase changes into AppState so
        // views that only observe AppState (e.g. Log tab) still refresh.
        UserPlanDatabase.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        ProgramDatabase.shared.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Persist a single key immediately (no debounce), skipped during initial load.
    private func persist(_ key: String, _ value: String) {
        guard !isLoading else { return }
        UserDefaults.standard.set(value, forKey: key)
    }

    /// Persist a Codable value immediately (no debounce), skipped during initial load.
    private func persistCodable<T: Encodable>(_ value: T, _ key: String) {
        guard !isLoading else { return }
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
    private func loadCodable<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Builds a `WorkoutPrefs` snapshot from the current scalar values and persists it.
    private func persistWorkoutPrefs() {
        let prefs = WorkoutPrefs(
            defaultSets: defaultSets, defaultRepLow: defaultRepLow, defaultRepHigh: defaultRepHigh,
            defaultRestBetweenSets: defaultRestBetweenSets, defaultRestBetweenExercises: defaultRestBetweenExercises,
            autoRestTimer: autoRestTimer, autoPlayVideo: autoPlayVideo,
            showPRsDuringWorkout: showPRsDuringWorkout, showRepsFirst: showRepsFirst,
            weightUnit: weightUnit, lengthUnit: lengthUnit,
            notificationsEnabled: notificationsEnabled, restSound: restSound,
            appleHealthConnected: appleHealthConnected, googleHealthConnected: googleHealthConnected
        )
        persistCodable(prefs, Keys.workoutPrefs)
    }

    // MARK: - Workout session (nil = no active workout)
    @Published var activeWorkoutSession: WorkoutSessionState? = nil

    /// Whether the full-screen Active Workout overlay is currently presented.
    /// A *minimized* session keeps `activeWorkoutSession` (timers run) but sets
    /// this `false` so the overlay hides and the resume banner can show.
    /// Mirrors shell.jsx `workoutOpen`.
    @Published var workoutOverlayOpen: Bool = false

    /// A session exists but the overlay is closed → drives the resume banner.
    /// Mirrors shell.jsx `inProgress`.
    var workoutInProgress: Bool { activeWorkoutSession != nil && !workoutOverlayOpen }

    // MARK: - Cross-tab deep links (FAB quick actions → Progress sub-sections)
    enum ProgressDeepLink: Equatable { case measurements, photos }
    /// Set by a FAB action; ProgressTabView consumes it to open the right sub-tab.
    @Published var progressDeepLink: ProgressDeepLink? = nil

    /// Set by the FAB "Start Workout" action while on the Log tab; LogTabView
    /// consumes it to open the add-workout source sheet (03-log §misc).
    @Published var requestLogAddSheet: Bool = false

    // MARK: - User data
    var userPlans: [UserPlan] { UserPlanDatabase.shared.plans }
    @Published var workoutLogs: [WorkoutLog] = [] {
        didSet { persistCodable(workoutLogs, Keys.workoutLogs) }
    }

    // MARK: - Log tab per-day state (mirrors combined/log.jsx)
    /// Day overrides keyed by ISO date string (yyyy-MM-dd).
    @Published var dayOverrides: [String: DayOverride] = [:] {
        didSet { persistCodable(dayOverrides, Keys.dayOverrides) }
    }
    /// Per-day quick logs keyed by ISO date string.
    @Published var quickLogs: [String: QuickLog] = [:] {
        didSet { persistCodable(quickLogs, Keys.quickLogs) }
    }
    @Published var measurements: [Measurement] = [] {
        didSet { persistCodable(measurements, Keys.measurements) }
    }
    @Published var bodyStats: BodyStats = BodyStats() {
        didSet { persistCodable(bodyStats, Keys.bodyStats) }
    }
    @Published var personalRecords: [PersonalRecord] = [] {
        didSet { persistCodable(personalRecords, Keys.personalRecords) }
    }
    @Published var userProfile: UserProfile = UserProfile() {
        didSet { persistCodable(userProfile, Keys.userProfile) }
    }
    // TODO: migrate progressPhotos image blobs to file storage (UserDefaults size pressure)
    @Published var progressPhotos: [ProgressPhoto] = [] {
        didSet { persistCodable(progressPhotos, Keys.progressPhotos) }
    }

    // MARK: - Workout preferences
    @Published var defaultSets: Int = 3 {
        didSet { persistWorkoutPrefs() }
    }
    @Published var defaultRepLow: Int = 6 {
        didSet { persistWorkoutPrefs() }
    }
    @Published var defaultRepHigh: Int = 10 {
        didSet { persistWorkoutPrefs() }
    }
    /// Derived "lo–hi" display string (mirrors the prototype's defRepsLo/Hi pair).
    var defaultRepRange: String { "\(defaultRepLow)–\(defaultRepHigh)" }
    @Published var defaultRestBetweenSets: Int = 60 {
        didSet { persistWorkoutPrefs() }
    }
    @Published var defaultRestBetweenExercises: Int = 90 {
        didSet { persistWorkoutPrefs() }
    }
    @Published var autoRestTimer: Bool = true {
        didSet { persistWorkoutPrefs() }
    }
    @Published var autoPlayVideo: Bool = false {
        didSet { persistWorkoutPrefs() }
    }
    @Published var showPRsDuringWorkout: Bool = true {
        didSet { persistWorkoutPrefs() }
    }
    @Published var showRepsFirst: Bool = true {
        didSet { persistWorkoutPrefs() }
    }
    @Published var weightUnit: String = "kg" {
        didSet { persistWorkoutPrefs() }
    }
    @Published var lengthUnit: String = "cm" {
        didSet { persistWorkoutPrefs() }
    }

    // MARK: - Notifications
    @Published var notificationsEnabled: Bool = true {
        didSet { persistWorkoutPrefs() }
    }
    @Published var restSound: String = "Ding" {    // "Ding" | "Alarm clock"
        didSet { persistWorkoutPrefs() }
    }

    // MARK: - Connected health apps
    @Published var appleHealthConnected: Bool = true {
        didSet { persistWorkoutPrefs() }
    }
    @Published var googleHealthConnected: Bool = false {
        didSet { persistWorkoutPrefs() }
    }

    /// Set by AccountDetailsView "Save Changes" on dismiss; the Profile root
    /// consumes it to flash a confirmation toast (mirrors prototype Save flow).
    @Published var profileSaveFlash: String? = nil

    // MARK: - Health & UI signals
    @Published var healthKitConnected: Bool = false

    // MARK: - Computed
    var defaultPlan: UserPlan? { userPlans.first(where: { $0.isDefault }) }

    // MARK: - Workout overlay lifecycle (mirrors shell.jsx startWorkout / onMinimize / onExit)

    /// Launch the Active Workout overlay for the SELECTED workout.
    /// Each exercise is seeded with `plannedSets` empty `WorkoutSet()`s and enriched
    /// with the user's real PR/history/target data. Elapsed time starts at 0.
    /// `emptyMode` = build-as-you-go (no exercises). The Push Day A demo lives behind
    /// `#if DEBUG` only (see `debugStartPushDayDemo`).
    func startWorkout(_ workout: Workout, emptyMode: Bool = false) {
        let seed: Workout
        if emptyMode {
            seed = Workout(name: workout.name.isEmpty ? "My Workout" : workout.name,
                           primaryMuscles: "—", estimatedMinutes: 0,
                           exercises: [], program: "Free Workout")
        } else {
            seed = buildSession(from: workout)
        }
        let session = WorkoutSessionState(workout: seed, appState: self, emptyMode: emptyMode)
        activeWorkoutSession = session
        workoutOverlayOpen = true
    }

    private static let prDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// Synthesizes a warm-up protocol for a given exercise position in a
    /// workout: full 4-set ladder for the first exercise, a lighter 2-set
    /// ladder for the second, and none thereafter.
    private static func synthesizedWarmup(forExerciseIndex index: Int) -> [WarmupSet] {
        switch index {
        case 0:
            return [
                WarmupSet(reps: 12, label: "Empty bar"),
                WarmupSet(reps: 8, label: "40%"),
                WarmupSet(reps: 5, label: "60%"),
                WarmupSet(reps: 3, label: "80%")
            ]
        case 1:
            return [
                WarmupSet(reps: 10, label: "50%"),
                WarmupSet(reps: 6, label: "75%")
            ]
        default:
            return []
        }
    }

    /// Build the live session workout from the selected `Workout`: seeds empty
    /// `plannedSets` sets per exercise and enriches with real PR/history/target
    /// data. Purely additive — never overwrites existing data with nil/empty.
    private func buildSession(from workout: Workout) -> Workout {
        var w = workout
        for i in w.exercises.indices {
            let planned = max(1, w.exercises[i].plannedSets)
            w.exercises[i].sets = (0..<planned).map { _ in WorkoutSet() }
            w.exercises[i].completed = false
            let exName = w.exercises[i].name

            // lastPR enrichment
            if let pr = personalRecords.first(where: { $0.exerciseName.lowercased() == exName.lowercased() }) {
                w.exercises[i].lastPR = PRRecord(weight: pr.weight, reps: pr.reps,
                                                  date: Self.prDateFormatter.string(from: pr.date))
            }

            // history enrichment: most-recent matching log
            let matchingLogs = workoutLogs.filter { log in
                log.exercises.contains { $0.name.lowercased() == exName.lowercased() }
            }
            if let latestLog = matchingLogs.max(by: { $0.date < $1.date }),
               let matchedExercise = latestLog.exercises.first(where: { $0.name.lowercased() == exName.lowercased() }) {
                let mappedHistory: [SetHistory] = matchedExercise.sets.compactMap { s in
                    if s.weight == nil && s.reps == nil { return nil }
                    let wStr = s.weight.map { String($0) } ?? "0"
                    let rStr = s.reps.map(String.init) ?? "0"
                    return SetHistory(weight: wStr, reps: rStr)
                }
                if !mappedHistory.isEmpty {
                    w.exercises[i].history = mappedHistory
                }
            }

            // target derivation (minimal rule — do NOT overbuild)
            if w.exercises[i].target == nil {
                if let pr = w.exercises[i].lastPR {
                    w.exercises[i].target = TargetRecord(weight: pr.weight, reps: pr.reps, note: "Match your last best")
                } else if let first = w.exercises[i].history.first,
                          let parsedWeight = Double(first.weight), let parsedReps = Int(first.reps) {
                    w.exercises[i].target = TargetRecord(weight: parsedWeight, reps: parsedReps, note: "Match last session")
                }
            }

            // warm-up synthesis (additive — never overwrite an existing warm-up)
            if w.exercises[i].warmup.isEmpty {
                w.exercises[i].warmup = Self.synthesizedWarmup(forExerciseIndex: i)
            }
        }
        return w
    }

    #if DEBUG
    /// Demo-only: launch the seeded Push Day A mid-session (fake PRs/history/elapsed).
    func debugStartPushDayDemo() {
        let seed = ActiveWorkoutSeed.pushDayA()
        let session = WorkoutSessionState(workout: seed, appState: self, emptyMode: false)
        activeWorkoutSession = session
        workoutOverlayOpen = true
    }
    #endif

    /// Minimize: keep the live session (timers, logged sets, rest) but close the
    /// overlay → lands on Log with the resume banner showing.
    func minimizeWorkout() {
        workoutOverlayOpen = false
    }

    /// Re-open the existing live session's overlay (the real "Resume").
    func resumeWorkout() {
        guard activeWorkoutSession != nil else { return }
        workoutOverlayOpen = true
    }

    /// Exit/discard: tear the session down entirely → no resume banner.
    func exitWorkout() {
        activeWorkoutSession = nil
        workoutOverlayOpen = false
    }

    func saveWorkout(_ session: WorkoutSessionState) {
        let log = WorkoutLog(
            date: session.startDate,
            workoutName: session.workout.name,
            exercises: session.workout.exercises,
            durationSeconds: session.elapsedSeconds,
            sessionNotes: session.sessionNotes
        )
        workoutLogs.append(log)

        // Stamp a `.logged` override for this day so the Log tab's dayInfo
        // state machine derives past-day completion from actual logs. Skip if
        // an override is already logged (idempotent re-save; avoids clobbering
        // a manually-set workoutId from a quick-log at LogSheetsView:881).
        let iso = AppState.iso(session.startDate)
        if dayOverrides[iso]?.kind != .logged {
            setOverride(DayOverride(kind: .logged, workoutId: session.workout.id), for: iso)
        }

        // Update personal records
        for ex in session.workout.exercises {
            for s in ex.sets where s.done {
                guard let w = s.weight, let r = s.reps, w > 0, r > 0 else { continue }
                let e1rm = PersonalRecord.compute1RM(weight: w, reps: r)
                let existing = personalRecords.first(where: {
                    $0.exerciseName.lowercased() == ex.name.lowercased()
                })
                if let pr = existing {
                    if e1rm > pr.estimated1RM {
                        personalRecords.removeAll { $0.id == pr.id }
                        personalRecords.append(PersonalRecord(
                            exerciseName: ex.name, muscle: ex.primaryMuscle,
                            weight: w, reps: r, date: Date(), estimated1RM: e1rm
                        ))
                    }
                } else {
                    personalRecords.append(PersonalRecord(
                        exerciseName: ex.name, muscle: ex.primaryMuscle,
                        weight: w, reps: r, date: Date(), estimated1RM: e1rm
                    ))
                }
            }
        }
        WorkoutPersistence.clearWorkout()
        activeWorkoutSession = nil
        workoutOverlayOpen = false
    }

    func discardWorkout() {
        WorkoutPersistence.clearWorkout()
        activeWorkoutSession = nil
        workoutOverlayOpen = false
    }

    // MARK: - Week schedule helper
    func todayWorkout() -> Workout? {
        guard let plan = defaultPlan else { return nil }
        let dayIndex = Calendar.current.component(.weekday, from: Date()) - 1
        return plan.workout(for: dayIndex, programs: ProgramDatabase.shared.programs)
    }

    func isRestDay(for date: Date = Date()) -> Bool {
        guard let plan = defaultPlan else { return false }
        let dayIndex = Calendar.current.component(.weekday, from: date) - 1
        guard plan.weekSchedule.keys.contains(dayIndex) else { return false } // unkeyed = empty/unplanned, not rest
        return plan.weekSchedule[dayIndex] == .some(nil) // explicit nil entry = rest day
    }

    func hasLog(for date: Date) -> Bool {
        let cal = Calendar.current
        return workoutLogs.contains { cal.isDate($0.date, inSameDayAs: date) }
    }

    func logs(for date: Date) -> [WorkoutLog] {
        let cal = Calendar.current
        return workoutLogs.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Log day engine (mirrors combined/log.jsx dayInfo)

    /// Resolved info for a single calendar day in the Log tab.
    struct DayInfo {
        var iso: String
        var dowIndex: Int          // 0=Sun … 6=Sat
        var date: Date
        var relation: DayState.Relation
        var workout: Workout?
        var state: DayState
        var override: DayOverride?
    }

    static func iso(_ date: Date) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Compute the full state for a given date, applying program schedule + overrides.
    func dayInfo(for date: Date) -> DayInfo {
        let cal = Calendar.current
        let iso = AppState.iso(date)
        let dow = cal.component(.weekday, from: date) - 1
        let startOfDay = cal.startOfDay(for: date)
        let startOfToday = cal.startOfDay(for: Date())
        let ov = dayOverrides[iso]

        // Resolve the workout for this day (program schedule, then overrides).
        var workout: Workout? = {
            guard let plan = defaultPlan else { return nil }
            return plan.workout(for: dow, programs: ProgramDatabase.shared.programs)
        }()

        if let ov {
            switch ov.kind {
            case .switched, .added, .logged:
                if let wid = ov.workoutId {
                    workout = ProgramDatabase.shared.programs.flatMap { $0.workouts }
                        .first { $0.id == wid }
                        ?? defaultPlan?.customWorkouts.first { $0.id == wid }
                        ?? workout
                }
            case .rest, .removed:
                workout = nil
            case .edited:
                break
            }
            if let edited = ov.editedExercises, var w = workout {
                w.exercises = edited
                workout = w
            }
        }

        // Relation to today.
        let relation: DayState.Relation =
            startOfDay < startOfToday ? .past :
            startOfDay > startOfToday ? .future : .today

        // State machine.
        let state: DayState
        if workout == nil {
            switch relation {
            case .today:
                state = (ov?.kind == .removed) ? .emptyToday : .restToday
            default:
                state = .rest
            }
        } else if ov?.kind == .logged {
            state = .done
        } else if relation == .today {
            state = .today
        } else if relation == .future {
            state = .future
        } else {
            // Past planned day: derive completion from actual logs, not an
            // optimistic default. A workout being `.added` doesn't force
            // `.done` on its own — if no log exists, it's still `.missed`.
            if hasLog(for: date) { state = .done }
            else { state = .missed }
        }

        return DayInfo(iso: iso, dowIndex: dow, date: date,
                       relation: relation, workout: workout, state: state, override: ov)
    }

    func setOverride(_ ov: DayOverride, for iso: String) {
        dayOverrides[iso] = ov
    }
    func clearOverride(for iso: String) {
        dayOverrides.removeValue(forKey: iso)
    }
}
