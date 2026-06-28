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
    @Published var workout: Workout
    @Published var activeView: ActiveWorkoutScreen = .overview

    // MARK: - Timer
    @Published var elapsedSeconds: Int = 0
    private var elapsedTimer: Timer? = nil

    // MARK: - Rest timer
    @Published var restActive: Bool = false
    @Published var restTotal: Int = 60
    @Published var restLeft: Int = 60
    @Published var restRunning: Bool = true
    private var restTimer: Timer? = nil

    // MARK: - Rest pill position
    @Published var pillPosition: CGPoint = CGPoint(x: 96, y: 600)

    // MARK: - Celebration
    @Published var celebration: CelebrationData? = nil
    private var celebTimer: Timer? = nil

    // MARK: - Session meta
    let startDate: Date = Date()
    @Published var sessionNotes: String = ""

    // MARK: - App reference (for settings)
    private weak var appState: AppState?

    // MARK: - Init
    init(workout: Workout, appState: AppState) {
        self.workout = workout
        self.appState = appState
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
                guard let self else { return }
                if case .summary = self.activeView { return }
                self.elapsedSeconds += 1
            }
        }
    }

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Rest timer
    func startRest(duration: Int) {
        guard appState?.autoRestTimer == true else { return }
        restTimer?.invalidate()
        restActive = true
        restTotal = duration
        restLeft = duration
        restRunning = true
        scheduleRestTick()
    }

    private func scheduleRestTick() {
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.restActive, self.restRunning else { return }
                if self.restLeft <= 1 {
                    self.restTimer?.invalidate()
                    self.restActive = false
                    self.restLeft = 0
                } else {
                    self.restLeft -= 1
                }
            }
        }
    }

    func pauseResumeRest() {
        restRunning.toggle()
        if restRunning { scheduleRestTick() } else { restTimer?.invalidate() }
    }

    func addRestTime(_ seconds: Int) {
        restLeft += seconds
    }

    func dismissRest() {
        restTimer?.invalidate()
        restActive = false
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

    func substituteExercise(at index: Int, with replacement: Exercise) {
        guard workout.exercises.indices.contains(index) else { return }
        var ex = replacement
        ex.sets = workout.exercises[index].sets
        workout.exercises[index] = ex
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
        // Clear all existing superset flags
        for i in workout.exercises.indices { workout.exercises[i].superset = false }
        // Move target adjacent to source
        let target = workout.exercises.remove(at: targetIndex)
        let insertAt = targetIndex > sourceIndex ? sourceIndex + 1 : sourceIndex
        workout.exercises.insert(target, at: insertAt)
        workout.exercises[sourceIndex].superset = true
    }

    func removeSuperset(at index: Int) {
        for i in workout.exercises.indices { workout.exercises[i].superset = false }
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
