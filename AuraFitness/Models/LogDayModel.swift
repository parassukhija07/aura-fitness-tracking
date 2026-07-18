import Foundation

// MARK: - Per-day override (mirrors combined/log.jsx `overrides[iso]`)

/// A user action applied to a single calendar day that diverges from the program.
/// Today-only — never mutates the underlying program/plan.
struct DayOverride: Codable, Hashable {
    enum Kind: String, Codable {
        case switched   // swapped today's workout for another (today only)
        case added      // added a workout to an otherwise rest/empty day
        case logged     // a completed log exists for this day
        case rest       // forced rest day
        case removed    // removed today's planned workout
        case edited     // edited today's exercises (sets/removed) — today only
    }
    var kind: Kind
    var workoutId: UUID? = nil
    /// Custom exercise list when the day's workout was edited for today.
    var editedExercises: [Exercise]? = nil
}

// MARK: - Quick-log model (per-day logged sets — mirrors `workoutLogs[iso]`)

struct QuickLogSet: Identifiable, Codable, Hashable {
    var id = UUID()
    var weight: String = ""
    var reps: String = ""
}

struct QuickLogExercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sets: [QuickLogSet]
}

struct QuickLog: Codable, Hashable {
    var time: String           // "HH:mm"
    var exercises: [QuickLogExercise]
    var durationMinutes: Int = 0

    init(time: String, exercises: [QuickLogExercise], durationMinutes: Int = 0) {
        self.time = time
        self.exercises = exercises
        self.durationMinutes = durationMinutes
    }

    // Manual decode: `durationMinutes` is a field added after initial ship,
    // so entries persisted before this change lack the key. A synthesized
    // decoder would throw on the missing key and silently drop the entire
    // quickLogs dictionary (`loadCodable` swallows decode errors).
    enum CodingKeys: String, CodingKey { case time, exercises, durationMinutes }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        time = try c.decode(String.self, forKey: .time)
        exercises = try c.decode([QuickLogExercise].self, forKey: .exercises)
        durationMinutes = try c.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 0
    }
}

// MARK: - Day state (mirrors `dayInfo().kind`)

enum DayState: Equatable {
    case today        // planned, today, not yet done
    case done         // completed (has a log)
    case missed       // past planned day with no log
    case future       // future planned day (read-only)
    case rest         // scheduled rest day (past/future)
    case restToday    // scheduled rest day, today
    case emptyToday   // today, nothing planned (removed or no plan)
    case restPlanned  // future/past empty day with nothing scheduled
}

extension DayState {
    /// Relationship of the represented date to today.
    enum Relation { case past, today, future }

    var isCardState: Bool {
        switch self {
        case .today, .done, .missed, .future: return true
        default: return false
        }
    }
}
