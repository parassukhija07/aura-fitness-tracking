import SwiftUI

// MARK: - SetType
enum SetType: String, CaseIterable, Codable, Hashable {
    case normal, drop, restPause, failure, partials

    var label: String {
        switch self {
        case .normal:    return "Normal"
        case .drop:      return "Drop set"
        case .restPause: return "Rest-pause"
        case .failure:   return "To failure"
        case .partials:  return "Partials"
        }
    }

    var shortLabel: String {
        switch self {
        case .normal:    return ""
        case .drop:      return "D"
        case .restPause: return "R"
        case .failure:   return "F"
        case .partials:  return "P"
        }
    }

    var color: Color {
        switch self {
        case .normal:    return .aura.text2
        case .drop:      return .aura.purple
        case .restPause: return .aura.blue
        case .failure:   return .aura.red
        case .partials:  return .aura.green
        }
    }
}

// MARK: - WorkoutSet
struct WorkoutSet: Identifiable, Codable, Hashable {
    var id = UUID()
    var weight: Double? = nil
    var reps: Int? = nil
    var done: Bool = false
    var type: SetType = .normal
    var note: String = ""
}

// MARK: - WarmupSet
struct WarmupSet: Codable, Hashable {
    var reps: Int
    var label: String   // percentage / cue, e.g. "40%" or "Empty bar" (design's `pct`)
}

// MARK: - SetHistory (last session's value for a given set index)
struct SetHistory: Codable, Hashable {
    var weight: String
    var reps: String
}

// MARK: - PRRecord
struct PRRecord: Codable, Hashable {
    var weight: Double
    var reps: Int
    var date: String
}

// MARK: - TargetRecord
struct TargetRecord: Codable, Hashable {
    var weight: Double
    var reps: Int
    var note: String
}

// MARK: - Exercise
struct Exercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var primaryMuscle: String
    var muscleGroups: [String]
    var equipment: String
    var difficulty: String
    var isCable: Bool
    var pulley: String = "single"   // "single" | "double"
    // No defaults: sets/reps must be resolved explicitly at every creation
    // site — either from the catalog entry, the user's Workout Settings, or
    // `Exercise.fallback*` — so a generic 3×8–12 can never be stamped silently.
    var repRange: String
    var plannedSets: Int
    var lastPR: PRRecord? = nil
    var target: TargetRecord? = nil
    var history: [SetHistory] = []   // last session's per-set values (design `history`)
    var warmup: [WarmupSet] = []
    var hint: String = ""
    var imageURL: String? = nil
    var youtubeURL: String? = nil
    var sets: [WorkoutSet] = []
    var completed: Bool = false
    var supersetGroupID: UUID? = nil
    var note: String = ""

    // Convenience: total done sets
    var doneSetsCount: Int { sets.filter { $0.done }.count }
    var isFullyDone: Bool { completed || (doneSetsCount == sets.count && !sets.isEmpty) }

    /// Volume for done sets
    var doneVolume: Double {
        sets.filter { $0.done }.reduce(0) { acc, s in
            acc + (s.weight ?? 0) * Double(s.reps ?? 0)
        }
    }

    /// Neutral fallbacks for contexts where the user's Workout Settings must
    /// NOT apply — imported history, decoded archives, tests — and as the last
    /// resort when `AppStateBridge.shared` is unavailable during creation.
    static let fallbackRepRange = "8–12"
    static let fallbackSets = 3
}

// MARK: - Workout
struct Workout: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var primaryMuscles: String
    var estimatedMinutes: Int
    var exercises: [Exercise]
    var restBetweenSets: Int = 60
    var restBetweenExercises: Int = 90
    var program: String? = nil   // program name tag for display in Active Workout overview
}

// MARK: - Program
struct Program: Identifiable, Codable {
    var id = UUID()
    var name: String
    var daysPerWeek: Int
    var level: String
    var style: String
    var description: String
    var workouts: [Workout]
    var isPredefined: Bool = true

    /// The week the program actually prescribes: 7 entries, day 1 first,
    /// `nil` = rest. Rest placement is part of the program — three lower-body
    /// days on Tue/Thu/Sat is a different program from the same three stacked
    /// Mon/Tue/Wed — and a day may repeat a workout, which `workouts` (the set
    /// of distinct sessions) cannot express on its own.
    ///
    /// Empty means "no pattern given" and `UserPlanDatabase.addPlan(from:)`
    /// falls back to filling weekdays sequentially. Custom programs built in
    /// the editor leave it empty, as do programs persisted before this field
    /// existed — hence the default, which keeps those rows decodable.
    var weekPattern: [UUID?] = []
}

// MARK: - UserPlan
struct UserPlan: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isDefault: Bool = false
    var sourceProgramID: UUID? = nil
    /// day of week (0=Sun … 6=Sat) → workout id (nil = rest day)
    var weekSchedule: [Int: UUID?] = [:]
    var customWorkouts: [Workout] = []

    /// The calendar day (start-of-day) this plan's schedule begins applying
    /// from. Days *before* it resolve to whichever plan was active earlier (or
    /// stay empty), so making a plan default never rewrites the past.
    ///
    /// `nil` = a legacy plan that never recorded an activation; treated as
    /// active from the distant past so existing installs keep showing their
    /// week unchanged. Added after initial ship, so old persisted rows decode
    /// to `nil` (Optional → `decodeIfPresent`).
    var activationDate: Date? = nil

    func workout(for dayIndex: Int, programs: [Program]) -> Workout? {
        guard let entry = weekSchedule[dayIndex], let wid = entry else { return nil }
        if let cw = customWorkouts.first(where: { $0.id == wid }) { return cw }
        for prog in programs {
            if let w = prog.workouts.first(where: { $0.id == wid }) { return w }
        }
        return nil
    }
}
