import SwiftUI

// MARK: - SetType
enum SetType: String, CaseIterable, Codable {
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
struct WorkoutSet: Identifiable, Codable {
    var id = UUID()
    var weight: Double? = nil
    var reps: Int? = nil
    var done: Bool = false
    var type: SetType = .normal
    var note: String = ""
}

// MARK: - WarmupSet
struct WarmupSet: Codable {
    var reps: Int
    var label: String
}

// MARK: - PRRecord
struct PRRecord: Codable {
    var weight: Double
    var reps: Int
    var date: String
}

// MARK: - TargetRecord
struct TargetRecord: Codable {
    var weight: Double
    var reps: Int
    var note: String
}

// MARK: - Exercise
struct Exercise: Identifiable, Codable {
    var id = UUID()
    var name: String
    var primaryMuscle: String
    var muscleGroups: [String]
    var equipment: String
    var difficulty: String
    var isCable: Bool
    var pulley: String = "single"   // "single" | "double"
    var repRange: String = "8–12"
    var plannedSets: Int = 3
    var lastPR: PRRecord? = nil
    var target: TargetRecord? = nil
    var warmup: [WarmupSet] = []
    var hint: String = ""
    var imageURL: String? = nil
    var youtubeURL: String? = nil
    var sets: [WorkoutSet] = []
    var completed: Bool = false
    var superset: Bool = false
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
}

// MARK: - Workout
struct Workout: Identifiable, Codable {
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

    func workout(for dayIndex: Int, programs: [Program]) -> Workout? {
        guard let entry = weekSchedule[dayIndex], let wid = entry else { return nil }
        if let cw = customWorkouts.first(where: { $0.id == wid }) { return cw }
        for prog in programs {
            if let w = prog.workouts.first(where: { $0.id == wid }) { return w }
        }
        return nil
    }
}
