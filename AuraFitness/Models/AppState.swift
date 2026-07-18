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

    /// Bundles the scattered workout-preference scalars into a single
    /// persisted blob. Public (not `private`) + renamed `RemotePrefs` (H8) so
    /// it can also be used as the `aura_preferences` Supabase JSONB payload
    /// and the `DataArchive.preferences` export snapshot. Also carries the
    /// three top-level pref scalars (`darkModePreference`, `calendarStartDay`,
    /// `logDisplayMode`) per the H8 spec (`aura_preferences` payload note).
    struct RemotePrefs: Codable {
        var defaultSets: Int = 3
        var defaultRepLow: Int = 6
        var defaultRepHigh: Int = 10
        var defaultRestBetweenSets: Int = 60
        var defaultRestBetweenExercises: Int = 90
        var autoRestTimer: Bool = true
        var autoPlayVideo: Bool = false
        var showPRsDuringWorkout: Bool = true
        var showRepsFirst: Bool = true
        var weightUnit: String = "kg"
        var lengthUnit: String = "cm"
        var notificationsEnabled: Bool = true
        var restSound: String = "Ding"
        var appleHealthConnected: Bool = false
        var darkModePreference: String = DarkModePreference.auto.rawValue
        var calendarStartDay: Int = 0
        var logDisplayMode: String = "Both"
    }
    private typealias WorkoutPrefs = RemotePrefs

    /// When true, `didSet` writers don't persist (used while loading in `init`).
    private var isLoading = false

    /// When true, `didSet` writers persist locally (disk must match) but do
    /// NOT push to Supabase — set while applying pulled remote rows so a
    /// pull never triggers an immediate re-push (push/pull echo guard).
    private var isApplyingRemote = false

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
            appleHealthConnected = p.appleHealthConnected
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

    /// Builds a `RemotePrefs` snapshot from the current scalar values.
    func currentPrefsBlob() -> RemotePrefs {
        RemotePrefs(
            defaultSets: defaultSets, defaultRepLow: defaultRepLow, defaultRepHigh: defaultRepHigh,
            defaultRestBetweenSets: defaultRestBetweenSets, defaultRestBetweenExercises: defaultRestBetweenExercises,
            autoRestTimer: autoRestTimer, autoPlayVideo: autoPlayVideo,
            showPRsDuringWorkout: showPRsDuringWorkout, showRepsFirst: showRepsFirst,
            weightUnit: weightUnit, lengthUnit: lengthUnit,
            notificationsEnabled: notificationsEnabled, restSound: restSound,
            appleHealthConnected: appleHealthConnected,
            darkModePreference: darkModePreference.rawValue, calendarStartDay: calendarStartDay,
            logDisplayMode: logDisplayMode
        )
    }

    /// Builds + persists the `RemotePrefs` blob, then write-through pushes it
    /// (fire-and-forget; skipped while loading or applying a remote pull).
    private func persistWorkoutPrefs() {
        let prefs = currentPrefsBlob()
        persistCodable(prefs, Keys.workoutPrefs)
        guard !isLoading, !isApplyingRemote, let uid = AuthService.shared.userID else { return }
        SupabaseSyncService.shared.push(prefs, id: uid, table: .preferences)
    }

    // MARK: - Remote apply hooks (SupabaseSyncService.pullAll reconcile target)
    //
    // Each of these assigns local state without re-pushing (isApplyingRemote
    // guard) and always re-persists so disk matches after a pull.

    /// Merges pulled remote rows over local (LWW reconcile target — used by
    /// `SupabaseSyncService.pullAll()`, which already only hands us rows it
    /// decided should win). NOT used for reset — passing `[]` here is
    /// deliberately a no-op merge, not a clear. See `clearWorkoutLogs()` etc.
    /// below for the real "replace with empty" reset path.
    func applyRemoteWorkoutLogs(_ logs: [WorkoutLog]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        var byID: [UUID: WorkoutLog] = [:]
        for l in workoutLogs { byID[l.id] = l }
        for l in logs { byID[l.id] = l }
        workoutLogs = Array(byID.values)
    }

    func applyRemoteMeasurements(_ items: [Measurement]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        var byID: [UUID: Measurement] = [:]
        for m in measurements { byID[m.id] = m }
        for m in items { byID[m.id] = m }
        measurements = Array(byID.values)
    }

    func applyRemotePersonalRecords(_ items: [PersonalRecord]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        var byID: [UUID: PersonalRecord] = [:]
        for p in personalRecords { byID[p.id] = p }
        for p in items { byID[p.id] = p }
        personalRecords = Array(byID.values)
    }

    func applyRemoteProgressPhotos(_ items: [ProgressPhoto]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        var byID: [UUID: ProgressPhoto] = [:]
        for p in progressPhotos { byID[p.id] = p }
        for p in items { byID[p.id] = p }
        progressPhotos = Array(byID.values)
    }

    func applyRemoteDayOverrides(_ items: [String: DayOverride]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        var merged = dayOverrides
        for (k, v) in items { merged[k] = v }
        dayOverrides = merged
    }

    func applyRemoteQuickLogs(_ items: [String: QuickLog]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        var merged = quickLogs
        for (k, v) in items { merged[k] = v }
        quickLogs = merged
    }

    func applyRemoteBodyStats(_ stats: BodyStats) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        bodyStats = stats
    }

    func applyRemoteUserProfile(_ profile: UserProfile) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        userProfile = profile
    }

    // MARK: - Reset support (hard REPLACE, not merge)
    //
    // `applyRemote*` above are union-merge helpers for pull reconcile and
    // must never double as the reset mechanism (passing `[]`/`[:]` there is
    // a no-op). These `clear*` methods actually reassign the `@Published`
    // collection to the given value, guarded the same way so the write
    // doesn't get pushed back to Supabase mid-reset (the caller,
    // `DataResetService`, separately wipes the remote tables when
    // `alsoRemote` is true).

    func clearWorkoutLogs() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        workoutLogs = []
    }
    func clearMeasurements() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        measurements = []
    }
    func clearPersonalRecords() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        personalRecords = []
    }
    func clearProgressPhotos() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        progressPhotos = []
    }
    func clearDayOverrides() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        dayOverrides = [:]
    }
    func clearQuickLogs() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        quickLogs = [:]
    }
    /// §5.1 — Body tab and Account Details show the same age/sex fact under
    /// different names (`bodyStats.age`/`.sex` vs `userProfile.birthday`/`.gender`).
    /// Call after editing either side so both stay consistent.
    func syncBodyAndProfile() {
        let years = Calendar.current.dateComponents([.year], from: userProfile.birthday, to: Date()).year ?? bodyStats.age
        bodyStats.age = years
        if userProfile.gender == "Male" || userProfile.gender == "Female" {
            bodyStats.sex = userProfile.gender
        }
    }

    /// Called from the Body/Nutrition tab: age is edited as a raw number
    /// there (no birthday picker), so back-derive an approximate birthday.
    func syncProfileFromBodyStats() {
        if let approx = Calendar.current.date(byAdding: .year, value: -bodyStats.age, to: Date()) {
            userProfile.birthday = approx
        }
        if bodyStats.sex == "Male" || bodyStats.sex == "Female" {
            userProfile.gender = bodyStats.sex
        }
    }

    func resetBodyStats() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        bodyStats = BodyStats()
    }
    func resetUserProfile() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        userProfile = UserProfile()
    }
    func resetPrefs() {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        applyRemotePrefsRaw(RemotePrefs())
    }

    func applyRemotePrefs(_ prefs: RemotePrefs) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        applyRemotePrefsRaw(prefs)
    }

    /// Shared scalar-assignment body for `applyRemotePrefs`/`resetPrefs` —
    /// factored out so both can guard `isApplyingRemote` at their own call
    /// site without a nested double set/reset.
    private func applyRemotePrefsRaw(_ prefs: RemotePrefs) {
        defaultSets = prefs.defaultSets; defaultRepLow = prefs.defaultRepLow; defaultRepHigh = prefs.defaultRepHigh
        defaultRestBetweenSets = prefs.defaultRestBetweenSets; defaultRestBetweenExercises = prefs.defaultRestBetweenExercises
        autoRestTimer = prefs.autoRestTimer; autoPlayVideo = prefs.autoPlayVideo
        showPRsDuringWorkout = prefs.showPRsDuringWorkout; showRepsFirst = prefs.showRepsFirst
        weightUnit = prefs.weightUnit; lengthUnit = prefs.lengthUnit
        notificationsEnabled = prefs.notificationsEnabled; restSound = prefs.restSound
        appleHealthConnected = prefs.appleHealthConnected
        if let pref = DarkModePreference(rawValue: prefs.darkModePreference) { darkModePreference = pref }
        calendarStartDay = prefs.calendarStartDay
        logDisplayMode = prefs.logDisplayMode
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
        didSet {
            persistCodable(workoutLogs, Keys.workoutLogs)
            syncDiff(old: oldValue, new: workoutLogs, table: .workoutLogs, idOf: { $0.id.uuidString })
        }
    }

    // MARK: - Log tab per-day state (mirrors combined/log.jsx)
    /// Day overrides keyed by ISO date string (yyyy-MM-dd).
    @Published var dayOverrides: [String: DayOverride] = [:] {
        didSet {
            persistCodable(dayOverrides, Keys.dayOverrides)
            syncDiffKeyed(old: oldValue, new: dayOverrides, table: .dayOverrides)
        }
    }
    /// Per-day quick logs keyed by ISO date string.
    @Published var quickLogs: [String: QuickLog] = [:] {
        didSet {
            persistCodable(quickLogs, Keys.quickLogs)
            syncDiffKeyed(old: oldValue, new: quickLogs, table: .quickLogs)
        }
    }
    @Published var measurements: [Measurement] = [] {
        didSet {
            persistCodable(measurements, Keys.measurements)
            syncDiff(old: oldValue, new: measurements, table: .measurements, idOf: { $0.id.uuidString })
        }
    }
    @Published var bodyStats: BodyStats = BodyStats() {
        didSet {
            persistCodable(bodyStats, Keys.bodyStats)
            syncSingleton(bodyStats, table: .bodyStats)
        }
    }
    @Published var personalRecords: [PersonalRecord] = [] {
        didSet {
            persistCodable(personalRecords, Keys.personalRecords)
            syncDiff(old: oldValue, new: personalRecords, table: .personalRecords, idOf: { $0.id.uuidString })
        }
    }
    @Published var userProfile: UserProfile = UserProfile() {
        didSet {
            persistCodable(userProfile, Keys.userProfile)
            syncSingleton(userProfile, table: .userProfile)
        }
    }
    // TODO: migrate progressPhotos image blobs to file storage (UserDefaults size pressure)
    @Published var progressPhotos: [ProgressPhoto] = [] {
        didSet {
            persistCodable(progressPhotos, Keys.progressPhotos)
            syncDiff(old: oldValue, new: progressPhotos, table: .progressPhotos, idOf: { $0.id.uuidString })
        }
    }

    // MARK: - Write-through diff helpers (whole-array `didSet` hazard)
    //
    // Assigning the entire array/dict fires one `didSet`; naively "pushing
    // everything" on every keystroke would be wasteful and racy. These diff
    // old vs new and push only changed/added rows + delete removed rows.
    // Skipped entirely during initial load or while applying a remote pull
    // (both guarded, mirroring the `isLoading` guard already used for local
    // persistence).

    private func syncDiff<T: Encodable>(old: [T], new: [T], table: SupabaseSyncService.Table, idOf: (T) -> String) {
        guard !isLoading, !isApplyingRemote else { return }
        let oldByID = Dictionary(uniqueKeysWithValues: old.map { (idOf($0), $0) })
        let newByID = Dictionary(uniqueKeysWithValues: new.map { (idOf($0), $0) })
        for (id, value) in newByID {
            // Push if new or changed. Encodable structs aren't Equatable here,
            // so compare via JSON bytes (cheap relative to a network round
            // trip, and correct without requiring every model to add
            // Equatable just for this).
            if oldByID[id] == nil || !jsonEqual(oldByID[id]!, value) {
                SupabaseSyncService.shared.push(value, id: id, table: table)
            }
        }
        for id in oldByID.keys where newByID[id] == nil {
            SupabaseSyncService.shared.delete(id: id, table: table)
        }
    }

    private func syncDiffKeyed<T: Encodable & Equatable>(old: [String: T], new: [String: T], table: SupabaseSyncService.Table) {
        guard !isLoading, !isApplyingRemote else { return }
        for (key, value) in new {
            if old[key] != value {
                SupabaseSyncService.shared.push(value, id: key, table: table)
            }
        }
        for key in old.keys where new[key] == nil {
            SupabaseSyncService.shared.delete(id: key, table: table)
        }
    }

    private func syncSingleton<T: Encodable>(_ value: T, table: SupabaseSyncService.Table) {
        guard !isLoading, !isApplyingRemote, let uid = AuthService.shared.userID else { return }
        SupabaseSyncService.shared.push(value, id: uid, table: table)
    }

    private func jsonEqual<T: Encodable>(_ a: T, _ b: T) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let da = try? encoder.encode(a), let db = try? encoder.encode(b) else { return false }
        return da == db
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
    /// True only after the user has actually granted HealthKit authorization
    /// (see `HealthKitService.requestAuthorization`) — never defaulted to
    /// true, since that claimed a connection that didn't exist (§5.7).
    @Published var appleHealthConnected: Bool = false {
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

    /// §2.27 — write an in-workout exercise-list edit (add/remove/substitute)
    /// back into the source Program or UserPlan custom workout, instead of
    /// letting it live only in the session's detached in-memory copy. No-op
    /// (returns false) if the workout has no resolvable source, e.g. an
    /// empty/build-as-you-go session — those have nothing to save "back" into.
    @discardableResult
    func savePermanently(exercises: [Exercise], forWorkoutID workoutID: UUID, name: String) -> Bool {
        if let programID = ProgramDatabase.shared.owningProgramID(forWorkout: workoutID),
           var w = ProgramDatabase.shared.workout(id: workoutID) {
            w.exercises = exercises
            w.name = name
            ProgramDatabase.shared.updateWorkout(w, in: programID)
            return true
        }
        if let planID = UserPlanDatabase.shared.owningPlanID(forCustomWorkout: workoutID),
           let plan = UserPlanDatabase.shared.plans.first(where: { $0.id == planID }),
           var w = plan.customWorkouts.first(where: { $0.id == workoutID }) {
            w.exercises = exercises
            w.name = name
            UserPlanDatabase.shared.updateCustomWorkout(w, in: planID)
            return true
        }
        return false
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

        // Update personal records — append-only log (never delete) so
        // history survives for per-exercise PR charting; "current best" is
        // derived at read time (see `currentBestPRs`). A set counts as a new
        // PR if it beats the existing best on either e1RM or raw weight, so
        // a heavier-weight/lower-rep set that lowers e1RM is still recorded.
        for ex in session.workout.exercises {
            for s in ex.sets where s.done {
                guard let w = s.weight, let r = s.reps, w > 0, r > 0 else { continue }
                let e1rm = PersonalRecord.compute1RM(weight: w, reps: r)
                let best = bestPR(forExercise: ex.name)
                if best == nil || e1rm > best!.estimated1RM || w > best!.weight {
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

    /// Real session history for an exercise, derived from `workoutLogs` — most
    /// recent sessions first. Replaces `PlanExerciseDetail.history(for:)`'s
    /// fabricated formula-generated data in the Exercise Library detail screen.
    func realHistory(forExercise name: String, limit: Int = 5) -> [PlanExerciseDetail.HistSession] {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US")
        fmt.dateFormat = "MMM d, yyyy"

        let matching = workoutLogs
            .compactMap { log -> (Date, Exercise)? in
                guard let ex = log.exercises.first(where: { $0.name.lowercased() == name.lowercased() }) else { return nil }
                return (log.date, ex)
            }
            .sorted { $0.0 > $1.0 }
            .prefix(limit)

        return matching.map { date, ex in
            let sets = ex.sets.filter { $0.done }.map {
                PlanExerciseDetail.HistSet(weight: $0.weight ?? 0, reps: $0.reps ?? 0)
            }
            return PlanExerciseDetail.HistSession(date: fmt.string(from: date), sets: sets)
        }
    }

    /// Current-best PR for an exercise, derived from the append-only
    /// `personalRecords` log (highest e1RM wins; ties broken by heavier weight).
    func bestPR(forExercise name: String) -> PersonalRecord? {
        personalRecords
            .filter { $0.exerciseName.lowercased() == name.lowercased() }
            .max { a, b in
                (a.estimated1RM, a.weight) < (b.estimated1RM, b.weight)
            }
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

    /// Day-key string, always Gregorian regardless of the device's calendar
    /// identifier (Buddhist/Japanese/etc. would otherwise leak non-Gregorian
    /// year numbers into this key, corrupting every dayOverrides/quickLogs
    /// lookup keyed by it).
    static func iso(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 1970, c.month ?? 1, c.day ?? 1)
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
            if let edited = ov.editedExercises {
                if var w = workout {
                    w.exercises = edited
                    workout = w
                } else {
                    // Workout lookup failed (e.g. `.added` referenced a
                    // workout id no longer resolvable in any program/plan)
                    // but the user still has an edited exercise list for
                    // this day — synthesize a placeholder rather than
                    // silently dropping their data.
                    workout = Workout(id: ov.workoutId ?? UUID(),
                                       name: "Custom Workout",
                                       primaryMuscles: "",
                                       estimatedMinutes: 0,
                                       exercises: edited)
                }
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
