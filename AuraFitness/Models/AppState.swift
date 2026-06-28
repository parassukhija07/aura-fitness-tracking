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
}
