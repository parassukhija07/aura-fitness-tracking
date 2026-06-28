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
    // MARK: - Appearance
    @Published var darkModePreference: DarkModePreference = .auto

    // MARK: - Settings
    @Published var calendarStartDay: Int = 0         // 0=Sun, 1=Mon
    @Published var logDisplayMode: String = "Both"   // "Strength Score" | "Strength Balance" | "Both"

    // MARK: - Workout session (nil = no active workout)
    @Published var activeWorkoutSession: WorkoutSessionState? = nil

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

    // MARK: - Workout preferences
    @Published var defaultSets: Int = 3
    @Published var defaultRepRange: String = "6–10"
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
    @Published var restSound: String = "Ding"    // "Ding" | "Alarm"

    // MARK: - Computed
    var defaultPlan: UserPlan? { userPlans.first(where: { $0.isDefault }) }

    // MARK: - Helpers
    func startWorkout(_ workout: Workout) {
        let session = WorkoutSessionState(workout: workout, appState: self)
        activeWorkoutSession = session
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
        activeWorkoutSession = nil
    }

    func discardWorkout() {
        activeWorkoutSession = nil
    }

    // MARK: - Week schedule helper
    func todayWorkout() -> Workout? {
        guard let plan = defaultPlan else { return nil }
        let programs = SeedData.programs
        let dayIndex = Calendar.current.component(.weekday, from: Date()) - 1
        return plan.workout(for: dayIndex, programs: programs)
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
