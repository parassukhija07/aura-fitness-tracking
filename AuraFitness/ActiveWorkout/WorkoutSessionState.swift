import SwiftUI
import Combine

enum ActiveWorkoutScreen {
    case overview
    case exercise(index: Int)
    case superset(index: Int)
    case summary
}

struct CelebrationData: Identifiable {
    var id = UUID()
    var emoji: String
    var title: String
    var message: String
}

@MainActor
class WorkoutSessionState: ObservableObject {
    // MARK: - Workout state (draft — not committed until Save)
    @Published var workout: Workout { didSet { WorkoutPersistence.saveWorkout(workout) } }
    @Published var activeView: ActiveWorkoutScreen = .overview {
        didSet {
            if case .summary = activeView { freezeElapsed() }
        }
    }

    /// Empty / build-as-you-go launch (no seed restore, no elapsed seed).
    let isEmptyMode: Bool

    // MARK: - Timer
    /// Base seconds accumulated before the current run (i.e. across pauses /
    /// background suspends where the tick loop itself may have frozen).
    private var baseElapsed: Int = 0 { didSet { WorkoutPersistence.saveElapsed(baseElapsed) } }
    /// Wall-clock start of the current run; nil while paused (never, today —
    /// elapsed always runs until summary). Persisted so a relaunch mid-session
    /// still derives correct elapsed from real time, not a frozen tick count.
    private var runStart: Date? = nil { didSet { WorkoutPersistence.saveRunStart(runStart) } }
    private var elapsedTimer: Timer? = nil

    /// Elapsed = base + wall-clock time since runStart. Computed from `Date`
    /// so backgrounding (which suspends `Timer`) can't cause drift — the timer
    /// below only exists to tick the UI, not to count seconds.
    @Published private(set) var elapsedSeconds: Int = 0

    // MARK: - Rest timer
    @Published var restActive: Bool = false
    @Published var restTotal: Int = 60
    /// Target end of the current rest window; countdown is derived from this,
    /// not from decrementing a counter, so a backgrounded app still reports
    /// the correct remaining time on return.
    private var restEndDate: Date? = nil
    @Published var restLeft: Int = 60
    @Published var restRunning: Bool = true
    private var restTimer: Timer? = nil

    // MARK: - Rest pill position
    @Published var pillPosition: CGPoint = CGPoint(x: 96, y: 690) { didSet { WorkoutPersistence.savePill(pillPosition) } }

    // MARK: - Celebration
    @Published var celebration: CelebrationData? = nil
    private var celebTimer: Timer? = nil

    // MARK: - Session meta
    let startDate: Date = Date()
    @Published var sessionNotes: String = ""

    // MARK: - App reference (for settings)
    private weak var appState: AppState?

    // MARK: - Init
    /// - Parameters:
    ///   - workout: the seed (Push Day A) or an empty workout.
    ///   - emptyMode: build-as-you-go launch — skips restore + elapsed seeding.
    init(workout seed: Workout, appState: AppState, emptyMode: Bool = false) {
        self.isEmptyMode = emptyMode
        self.appState = appState

        if emptyMode {
            self.workout = seed
            self.baseElapsed = 0
            self.pillPosition = CGPoint(x: 96, y: 690)
        } else {
            // Schema-gated restore onto the fresh seed (mirrors app.jsx).
            var restored = seed
            WorkoutPersistence.restore(into: &restored, workoutKey: seed.name)
            self.workout = restored
            self.baseElapsed = WorkoutPersistence.restoredElapsed(default: 0)
            self.pillPosition = WorkoutPersistence.restoredPill(default: CGPoint(x: 96, y: 690))
        }
        self.runStart = WorkoutPersistence.restoredRunStart() ?? Date()
        refreshElapsed()
        startElapsedTimer()
    }

    deinit {
        elapsedTimer?.invalidate()
        restTimer?.invalidate()
        celebTimer?.invalidate()
    }

    // MARK: - Elapsed timer
    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshElapsed()
            }
        }
    }

    private func refreshElapsed() {
        if case .summary = activeView { return }
        guard let runStart else { return }
        elapsedSeconds = baseElapsed + max(0, Int(Date().timeIntervalSince(runStart)))
    }

    /// Fold the current run into `baseElapsed` and persist the tally. Called on
    /// summary entry so the freeze there matches pre-refactor behavior (elapsed
    /// stops advancing once the workout is done).
    private func freezeElapsed() {
        refreshElapsed()
        baseElapsed = elapsedSeconds
        runStart = nil
    }

    /// Recompute elapsed/rest from wall-clock time immediately — call on
    /// scenePhase → .active so a backgrounded session's UI catches up instantly
    /// instead of waiting for the next 1s tick.
    func refreshOnForeground() {
        refreshElapsed()
        refreshRest()
    }

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Rest timer
    func startRest(duration: Int) {
        guard appState?.autoRestTimer == true else { return }
        restActive = true
        restTotal = duration
        restLeft = duration
        restRunning = true
        restEndDate = Date().addingTimeInterval(TimeInterval(duration))
        scheduleRestTick()
    }

    private func scheduleRestTick() {
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshRest()
            }
        }
    }

    /// Recompute `restLeft` from `restEndDate` (wall clock), not a decremented
    /// counter — a background suspend can't cause the countdown to freeze.
    private func refreshRest() {
        guard restActive, restRunning, let restEndDate else { return }
        let remaining = Int(restEndDate.timeIntervalSince(Date()).rounded(.up))
        if remaining <= 0 {
            restTimer?.invalidate()
            restActive = false
            restLeft = 0
        } else {
            restLeft = remaining
        }
    }

    func pauseResumeRest() {
        restRunning.toggle()
        if restRunning {
            restEndDate = Date().addingTimeInterval(TimeInterval(restLeft))
            scheduleRestTick()
        } else {
            restTimer?.invalidate()
        }
    }

    func addRestTime(_ seconds: Int) {
        restLeft += seconds
        restTotal += seconds
        if let restEndDate { self.restEndDate = restEndDate.addingTimeInterval(TimeInterval(seconds)) }
    }

    func dismissRest() {
        restTimer?.invalidate()
        restActive = false
        restEndDate = nil
    }

    var restFormatted: String {
        let m = restLeft / 60
        let s = restLeft % 60
        return String(format: "%d:%02d", m, s)
    }

    var restProgress: Double {
        restTotal > 0 ? Double(restLeft) / Double(restTotal) : 0
    }

    // MARK: - Celebration
    func triggerCelebration(emoji: String, title: String, message: String) {
        celebTimer?.invalidate()
        celebration = CelebrationData(emoji: emoji, title: title, message: message)
        celebTimer = Timer.scheduledTimer(withTimeInterval: 2.4, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.celebration = nil
            }
        }
    }

    // MARK: - Set interactions
    func onSetCompleted(exerciseIndex ei: Int, setIndex si: Int) {
        guard workout.exercises.indices.contains(ei),
              workout.exercises[ei].sets.indices.contains(si) else { return }

        workout.exercises[ei].sets[si].done = true

        let ex = workout.exercises[ei]
        let s = ex.sets[si]

        // Celebration checks
        if let w = s.weight, let pr = ex.lastPR, w > pr.weight {
            triggerCelebration(emoji: "🏆", title: "New PR!",
                message: "\(w) kg beats your \(pr.weight) kg best.")
        } else if let r = s.reps, let t = ex.target,
                  r > t.reps, let w = s.weight, w >= t.weight {
            triggerCelebration(emoji: "🔥", title: "Extra reps!",
                message: "\(r) reps — above today's target.")
        }

        // Rest timer — NOT after final set
        if si < ex.sets.count - 1 {
            let dur = appState?.defaultRestBetweenSets ?? 60
            startRest(duration: dur)
        }
    }

    /// Marking a superset set done (A or B): hard 60s rest, **no** PR/extra-reps
    /// celebration, and the rest fires regardless of whether it's the final set
    /// (mirrors superset.jsx `onToggleA/B`).
    func onSupersetSetDone(exerciseIndex ei: Int, setIndex si: Int) {
        guard workout.exercises.indices.contains(ei),
              workout.exercises[ei].sets.indices.contains(si) else { return }
        workout.exercises[ei].sets[si].done = true
        startRest(duration: 60)
    }

    func onAddSet(to exerciseIndex: Int) {
        guard workout.exercises.indices.contains(exerciseIndex) else { return }
        workout.exercises[exerciseIndex].sets.append(WorkoutSet())
        let dur = appState?.defaultRestBetweenSets ?? 60
        startRest(duration: dur)
    }

    func onCompleteExercise(at exerciseIndex: Int) {
        guard workout.exercises.indices.contains(exerciseIndex) else { return }

        // Strip empty sets
        workout.exercises[exerciseIndex].sets.removeAll { s in
            s.weight == nil && s.reps == nil && !s.done
        }
        // Mark remaining filled sets done
        for i in workout.exercises[exerciseIndex].sets.indices {
            let s = workout.exercises[exerciseIndex].sets[i]
            if s.weight != nil && s.reps != nil {
                workout.exercises[exerciseIndex].sets[i].done = true
            }
        }
        workout.exercises[exerciseIndex].completed = true

        let doneSets = workout.exercises[exerciseIndex].sets.filter { $0.done }.count
        triggerCelebration(emoji: "💪", title: "Exercise done",
            message: "\(doneSets) solid sets logged. On to the next.")
        startRest(duration: appState?.defaultRestBetweenExercises ?? 90)
        activeView = .overview
    }

    func onDeleteSet(exerciseIndex: Int, setIndex: Int) {
        guard workout.exercises.indices.contains(exerciseIndex),
              workout.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        workout.exercises[exerciseIndex].sets.remove(at: setIndex)
    }

    func onSetTypeChange(exerciseIndex: Int, setIndex: Int, type: SetType) {
        guard workout.exercises.indices.contains(exerciseIndex),
              workout.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        workout.exercises[exerciseIndex].sets[setIndex].type = type
    }

    func onPulleyChange(exerciseIndex: Int, pulley: String) {
        guard workout.exercises.indices.contains(exerciseIndex) else { return }
        workout.exercises[exerciseIndex].pulley = pulley
    }

    /// Substitute swaps only name + equipment + recomputed `isCable` (mirrors
    /// app.jsx `substitute`); PR, target, history, warm-up, hint and logged sets
    /// all stay put on the existing exercise.
    func substituteExercise(at index: Int, name: String, equipment: String) {
        guard workout.exercises.indices.contains(index) else { return }
        workout.exercises[index].name = name
        workout.exercises[index].equipment = equipment
        workout.exercises[index].isCable = (equipment == "Cable")
    }

    func removeExercise(at index: Int) {
        guard workout.exercises.indices.contains(index) else { return }
        workout.exercises.remove(at: index)
    }

    func addExercise(_ exercise: Exercise) {
        var ex = exercise
        ex.sets = (0..<ex.plannedSets).map { _ in WorkoutSet() }
        workout.exercises.append(ex)
    }

    func createSuperset(sourceIndex: Int, targetIndex: Int) {
        guard workout.exercises.indices.contains(sourceIndex),
              workout.exercises.indices.contains(targetIndex) else { return }

        // Dissolve any group either party already belongs to first, so a
        // groupID is never left held by exactly one exercise.
        for existingGID in [workout.exercises[sourceIndex].supersetGroupID,
                             workout.exercises[targetIndex].supersetGroupID].compactMap({ $0 }) {
            for i in workout.exercises.indices where workout.exercises[i].supersetGroupID == existingGID {
                workout.exercises[i].supersetGroupID = nil
            }
        }

        // Move target adjacent to source. Removing target can shift source's own
        // index (when target sat before source), so track source's position
        // through the removal before computing where to insert.
        let target = workout.exercises.remove(at: targetIndex)
        let leader = targetIndex < sourceIndex ? sourceIndex - 1 : sourceIndex
        workout.exercises.insert(target, at: leader + 1)
        let newGroupID = UUID()
        workout.exercises[leader].supersetGroupID = newGroupID
        workout.exercises[leader + 1].supersetGroupID = newGroupID
    }

    func removeSuperset(at index: Int) {
        guard workout.exercises.indices.contains(index),
              let gid = workout.exercises[index].supersetGroupID else { return }
        for i in workout.exercises.indices where workout.exercises[i].supersetGroupID == gid {
            workout.exercises[i].supersetGroupID = nil
        }
    }

    func moveExercise(from: IndexSet, to: Int) {
        workout.exercises.move(fromOffsets: from, toOffset: to)
    }

    // MARK: - Computed stats
    var totalSets: Int { workout.exercises.reduce(0) { $0 + $1.sets.count } }
    var doneSets: Int { workout.exercises.reduce(0) { $0 + $1.sets.filter { $0.done }.count } }
    var progressFraction: Double { totalSets > 0 ? Double(doneSets) / Double(totalSets) : 0 }
    var totalVolume: Double {
        workout.exercises.reduce(0) { acc, ex in
            acc + ex.sets.filter { $0.done }.reduce(0) { b, s in
                b + (s.weight ?? 0) * Double(s.reps ?? 0)
            }
        }
    }
    var newPRsCount: Int {
        workout.exercises.filter { ex in
            ex.sets.contains { s in
                guard let w = s.weight, let pr = ex.lastPR else { return false }
                return w > pr.weight && s.done
            }
        }.count
    }
}
