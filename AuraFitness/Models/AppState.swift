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
    private enum Keys {
        static let dark     = "aura_dark"      // DarkModePreference rawValue
        static let calStart = "aura_calstart"  // "Sun" | "Mon"
        static let logStat  = "aura_logstat"   // "Strength Score" | "Strength Balance" | "Both"
    }

    /// When true, `didSet` writers don't persist (used while loading in `init`).
    private var isLoading = false

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
        isLoading = false
    }

    /// Persist a single key immediately (no debounce), skipped during initial load.
    private func persist(_ key: String, _ value: String) {
        guard !isLoading else { return }
        UserDefaults.standard.set(value, forKey: key)
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
    @Published var userPlans: [UserPlan] = []
    @Published var workoutLogs: [WorkoutLog] = []

    // MARK: - Log tab per-day state (mirrors combined/log.jsx)
    /// Day overrides keyed by ISO date string (yyyy-MM-dd).
    @Published var dayOverrides: [String: DayOverride] = [:]
    /// Per-day quick logs keyed by ISO date string.
    @Published var quickLogs: [String: QuickLog] = [:]
    /// Past days seeded as "missed" for the demo (no log exists).
    @Published var seededMissed: Set<String> = []
    @Published var measurements: [Measurement] = []
    @Published var bodyStats: BodyStats = BodyStats()
    @Published var personalRecords: [PersonalRecord] = []
    @Published var userProfile: UserProfile = UserProfile()
    @Published var progressPhotos: [ProgressPhoto] = []

    // MARK: - Workout preferences
    @Published var defaultSets: Int = 3
    @Published var defaultRepLow: Int = 6
    @Published var defaultRepHigh: Int = 10
    /// Derived "lo–hi" display string (mirrors the prototype's defRepsLo/Hi pair).
    var defaultRepRange: String { "\(defaultRepLow)–\(defaultRepHigh)" }
    @Published var defaultRestBetweenSets: Int = 60
    @Published var defaultRestBetweenExercises: Int = 90
    @Published var autoRestTimer: Bool = true
    @Published var autoPlayVideo: Bool = false
    @Published var showPRsDuringWorkout: Bool = true
    @Published var showRepsFirst: Bool = true
    @Published var weightUnit: String = "kg"
    @Published var lengthUnit: String = "cm"

    // MARK: - Notifications
    @Published var notificationsEnabled: Bool = true
    @Published var restSound: String = "Ding"    // "Ding" | "Alarm clock"

    // MARK: - Connected health apps
    @Published var appleHealthConnected: Bool = true
    @Published var googleHealthConnected: Bool = false

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
            return plan.workout(for: dow, programs: SeedData.programs)
        }()

        if let ov {
            switch ov.kind {
            case .switched, .added, .logged:
                if let wid = ov.workoutId {
                    workout = SeedData.programs.flatMap { $0.workouts }
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
            // Past planned day: done unless seeded as missed.
            if ov?.kind == .added { state = .done }
            else if seededMissed.contains(iso) { state = .missed }
            else { state = .done }
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
