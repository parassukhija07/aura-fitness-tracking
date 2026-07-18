import SwiftUI

// MARK: - Plan tab seed data & models
//
// Self-contained mirror of `.design-import-v9/plan/data.jsx` + the editor-only
// seeds in `plan/app.jsx`. Kept independent of the global Workout/Exercise models
// (Models/WorkoutModels.swift) so this surface matches the v9 prototype 1:1.
// Types are `Plan`-prefixed to avoid colliding with those global types.

// MARK: PLAN_WORKOUTS

struct PlanWorkout: Identifiable, Hashable {
    let id: String
    var name: String
    var exCount: Int
    var muscles: String
    var duration: Int
}

enum PlanData {
    /// `PLAN_WORKOUTS` (5)
    static let workouts: [PlanWorkout] = [
        PlanWorkout(id: "push-a", name: "Push Day A", exCount: 6, muscles: "Chest, Shoulders, Triceps", duration: 58),
        PlanWorkout(id: "pull-a", name: "Pull Day A", exCount: 6, muscles: "Back, Biceps", duration: 52),
        PlanWorkout(id: "leg-a",  name: "Leg Day A",  exCount: 5, muscles: "Quads, Hamstrings", duration: 55),
        PlanWorkout(id: "push-b", name: "Push Day B", exCount: 6, muscles: "Shoulders focus", duration: 55),
        PlanWorkout(id: "pull-b", name: "Pull Day B", exCount: 5, muscles: "Back, Biceps", duration: 50),
    ]

    /// `PLAN_PROGRAMS` (6)
    static let programs: [PlanProgram] = [
        PlanProgram(id: "ppl",    name: "Push Pull Legs",      days: 6, level: "Intermediate", tag: "Hypertrophy", active: true),
        PlanProgram(id: "ul",     name: "Upper / Lower 4-Day", days: 4, level: "Strength",     tag: "Barbell",     active: false),
        PlanProgram(id: "arnold", name: "Arnold Split",        days: 6, level: "Advanced",     tag: "Volume",      active: false),
        PlanProgram(id: "fb3",    name: "Full Body 3×",        days: 3, level: "Beginner",     tag: "Compound",    active: false),
        PlanProgram(id: "phul",   name: "PHUL",                days: 4, level: "Intermediate", tag: "Power",       active: false),
        PlanProgram(id: "bro",    name: "Bro Split 5-Day",     days: 5, level: "Intermediate", tag: "Isolation",   active: false),
    ]

    /// `PLAN_EXERCISES_LIB` (47)
    static let exercises: [PlanLibExercise] = [
        // Chest
        PlanLibExercise(id: "bbar",  name: "Barbell Bench Press", muscle: "Chest", equip: "Barbell"),
        PlanLibExercise(id: "idb",   name: "Incline DB Press",    muscle: "Chest", equip: "Dumbbell"),
        PlanLibExercise(id: "cfly",  name: "Cable Fly",           muscle: "Chest", equip: "Cable"),
        PlanLibExercise(id: "peck",  name: "Pec Deck",            muscle: "Chest", equip: "Machine"),
        PlanLibExercise(id: "dfly",  name: "Dumbbell Fly",        muscle: "Chest", equip: "Dumbbell"),
        PlanLibExercise(id: "smbp",  name: "Smith Machine Bench", muscle: "Chest", equip: "Smith"),
        PlanLibExercise(id: "decbp", name: "Decline Bench Press", muscle: "Chest", equip: "Barbell"),
        PlanLibExercise(id: "pushup",name: "Push-up",             muscle: "Chest", equip: "Bodyweight"),
        // Back
        PlanLibExercise(id: "brow",  name: "Barbell Row",         muscle: "Back", equip: "Barbell"),
        PlanLibExercise(id: "pull",  name: "Pull-ups",            muscle: "Back", equip: "Bodyweight"),
        PlanLibExercise(id: "crow",  name: "Cable Row",           muscle: "Back", equip: "Cable"),
        PlanLibExercise(id: "latpd", name: "Lat Pulldown",        muscle: "Back", equip: "Machine"),
        PlanLibExercise(id: "drow",  name: "Dumbbell Row",        muscle: "Back", equip: "Dumbbell"),
        PlanLibExercise(id: "dead",  name: "Deadlift",            muscle: "Back", equip: "Barbell"),
        PlanLibExercise(id: "tbar",  name: "T-Bar Row",           muscle: "Back", equip: "Barbell"),
        PlanLibExercise(id: "smrow", name: "Smith Machine Row",   muscle: "Back", equip: "Smith"),
        // Shoulders
        PlanLibExercise(id: "ohp",   name: "Overhead Press",      muscle: "Shoulders", equip: "Barbell"),
        PlanLibExercise(id: "latdb", name: "Lateral Raise",       muscle: "Shoulders", equip: "Dumbbell"),
        PlanLibExercise(id: "latc",  name: "Cable Lateral Raise", muscle: "Shoulders", equip: "Cable"),
        PlanLibExercise(id: "fp",    name: "Face Pull",           muscle: "Shoulders", equip: "Cable"),
        PlanLibExercise(id: "arnp",  name: "Arnold Press",        muscle: "Shoulders", equip: "Dumbbell"),
        PlanLibExercise(id: "frt",   name: "Front Raise",         muscle: "Shoulders", equip: "Dumbbell"),
        PlanLibExercise(id: "smohp", name: "Smith Machine Press", muscle: "Shoulders", equip: "Smith"),
        // Biceps
        PlanLibExercise(id: "bcurl", name: "Barbell Curl",        muscle: "Biceps", equip: "Barbell"),
        PlanLibExercise(id: "hcurl", name: "Hammer Curl",         muscle: "Biceps", equip: "Dumbbell"),
        PlanLibExercise(id: "ccurl", name: "Cable Curl",          muscle: "Biceps", equip: "Cable"),
        PlanLibExercise(id: "icurl", name: "Incline DB Curl",     muscle: "Biceps", equip: "Dumbbell"),
        PlanLibExercise(id: "pccurl",name: "Preacher Curl",       muscle: "Biceps", equip: "Machine"),
        PlanLibExercise(id: "concur",name: "Concentration Curl",  muscle: "Biceps", equip: "Dumbbell"),
        // Triceps
        PlanLibExercise(id: "tpush", name: "Tricep Pushdown",     muscle: "Triceps", equip: "Cable"),
        PlanLibExercise(id: "skull", name: "Skull Crushers",      muscle: "Triceps", equip: "Barbell"),
        PlanLibExercise(id: "ohext", name: "Overhead Extension",  muscle: "Triceps", equip: "Dumbbell"),
        PlanLibExercise(id: "tdips", name: "Tricep Dips",         muscle: "Triceps", equip: "Bodyweight"),
        PlanLibExercise(id: "kbext", name: "Kickback",            muscle: "Triceps", equip: "Dumbbell"),
        PlanLibExercise(id: "clpush",name: "Close-Grip Bench",    muscle: "Triceps", equip: "Barbell"),
        // Legs
        PlanLibExercise(id: "squat", name: "Barbell Squat",       muscle: "Legs", equip: "Barbell"),
        PlanLibExercise(id: "rdl",   name: "Romanian Deadlift",   muscle: "Legs", equip: "Barbell"),
        PlanLibExercise(id: "legpr", name: "Leg Press",           muscle: "Legs", equip: "Machine"),
        PlanLibExercise(id: "legcr", name: "Leg Curl",            muscle: "Legs", equip: "Machine"),
        PlanLibExercise(id: "legex", name: "Leg Extension",       muscle: "Legs", equip: "Machine"),
        PlanLibExercise(id: "lunge", name: "Barbell Lunge",       muscle: "Legs", equip: "Barbell"),
        PlanLibExercise(id: "gobsq", name: "Goblet Squat",        muscle: "Legs", equip: "Dumbbell"),
        PlanLibExercise(id: "sumo",  name: "Sumo Deadlift",       muscle: "Legs", equip: "Barbell"),
        PlanLibExercise(id: "smsq",  name: "Smith Machine Squat", muscle: "Legs", equip: "Smith"),
        // Core
        PlanLibExercise(id: "plank", name: "Plank",               muscle: "Core", equip: "Bodyweight"),
        PlanLibExercise(id: "crunch",name: "Cable Crunch",        muscle: "Core", equip: "Cable"),
        PlanLibExercise(id: "hangk", name: "Hanging Knee Raise",  muscle: "Core", equip: "Bodyweight"),
        PlanLibExercise(id: "abwh",  name: "Ab Wheel Rollout",    muscle: "Core", equip: "Bodyweight"),
        PlanLibExercise(id: "rus",   name: "Russian Twist",       muscle: "Core", equip: "Bodyweight"),
    ]

    /// `DEFAULT_SCHEDULE` — Mon push-a · Tue pull-a · Wed rest · Thu leg-a · Fri push-b · Sat/Sun rest
    static let defaultSchedule: [PlanDay: String?] = [
        .mon: "push-a", .tue: "pull-a", .wed: nil, .thu: "leg-a", .fri: "push-b", .sat: nil, .sun: nil,
    ]

    static func workout(by id: String?) -> PlanWorkout? {
        guard let id else { return nil }
        return workouts.first { $0.id == id }
    }

    static func libExercise(named name: String) -> PlanLibExercise {
        exercises.first { $0.name == name }
            ?? PlanLibExercise(id: "x", name: name, muscle: "Unknown", equip: "Unknown")
    }

    /// `WK_SEEDS` — per-workout exercise lists (falls back to push-a).
    static func seedExercises(for workoutId: String) -> [PlanEditorExercise] {
        wkSeeds[workoutId] ?? wkSeeds["push-a"]!
    }

    private static let wkSeeds: [String: [PlanEditorExercise]] = [
        "push-a": [
            .init(name: "Barbell Bench Press", sets: 4, reps: "6–8"),
            .init(name: "Incline DB Press", sets: 3, reps: "8–10"),
            .init(name: "Cable Fly", sets: 3, reps: "12–15"),
            .init(name: "Overhead Press", sets: 3, reps: "8–10"),
            .init(name: "Lateral Raise", sets: 4, reps: "12–15"),
            .init(name: "Tricep Pushdown", sets: 3, reps: "12–15"),
        ],
        "pull-a": [
            .init(name: "Barbell Row", sets: 4, reps: "6–8"),
            .init(name: "Pull-ups", sets: 3, reps: "6–10"),
            .init(name: "Cable Row", sets: 3, reps: "10–12"),
            .init(name: "Face Pull", sets: 3, reps: "15–20"),
            .init(name: "Barbell Curl", sets: 3, reps: "8–12"),
            .init(name: "Hammer Curl", sets: 3, reps: "10–12"),
        ],
        "leg-a": [
            .init(name: "Barbell Squat", sets: 4, reps: "6–8"),
            .init(name: "Leg Press", sets: 3, reps: "10–12"),
            .init(name: "Romanian Deadlift", sets: 3, reps: "8–10"),
            .init(name: "Leg Curl", sets: 3, reps: "12–15"),
            .init(name: "Leg Extension", sets: 3, reps: "15–20"),
        ],
        "push-b": [
            .init(name: "Overhead Press", sets: 4, reps: "6–8"),
            .init(name: "DB Lateral Raise", sets: 4, reps: "12–15"),
            .init(name: "Incline DB Press", sets: 3, reps: "8–10"),
            .init(name: "Cable Lateral Raise", sets: 3, reps: "15–20"),
            .init(name: "Skull Crushers", sets: 3, reps: "10–12"),
            .init(name: "Tricep Dips", sets: 3, reps: "10–15"),
        ],
    ]
}

// MARK: PLAN_PROGRAMS

struct PlanProgram: Identifiable, Hashable {
    let id: String
    var name: String
    var days: Int
    var level: String
    var tag: String
    var active: Bool
}

// MARK: PLAN_EXERCISES_LIB

struct PlanLibExercise: Identifiable, Hashable {
    let id: String
    var name: String
    var muscle: String
    var equip: String
}

// MARK: Editor exercise (WK_SEEDS row)

struct PlanEditorExercise: Identifiable, Hashable {
    let id: String
    var name: String
    var sets: Int
    var reps: String
    /// A superset pair shares the same non-nil `supersetGroupID`; the partner
    /// is the next exercise in the array (pairs are kept physically adjacent).
    var supersetGroupID: UUID?

    init(id: String = "e\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(4))",
         name: String, sets: Int, reps: String, supersetGroupID: UUID? = nil) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.supersetGroupID = supersetGroupID
    }
}

// MARK: Weekday

enum PlanDay: String, CaseIterable, Hashable {
    case mon = "MON", tue = "TUE", wed = "WED", thu = "THU", fri = "FRI", sat = "SAT", sun = "SUN"

    /// Two-letter strip label (Mo/Tu/We…).
    var shortLabel: String {
        switch self {
        case .mon: return "Mo"; case .tue: return "Tu"; case .wed: return "We"
        case .thu: return "Th"; case .fri: return "Fr"; case .sat: return "Sa"; case .sun: return "Su"
        }
    }

    /// Day order honouring the user's `calStart` preference.
    static func ordered(calStartSun: Bool) -> [PlanDay] {
        calStartSun
            ? [.sun, .mon, .tue, .wed, .thu, .fri, .sat]
            : [.mon, .tue, .wed, .thu, .fri, .sat, .sun]
    }
}

// MARK: - Keyword colour / icon heuristics (wkStyle / wkIcon)

/// Keyword-driven theming for workout tiles. Inspects the lowercased name:
/// push → accent+flame, pull → blue+bolt, leg → green+trophy, upper → purple+arrow-up,
/// else accent+dumbbell. Mirrors `wkStyle(w)` / `wkIcon(w)`.
struct PlanWorkoutStyle {
    var bg: Color
    var tint: Color
    /// Border accent colour (the `pill` gradient mid-tone, used at low opacity).
    var border: Color
}

func planWkStyle(_ name: String?) -> PlanWorkoutStyle {
    let n = (name ?? "").lowercased()
    if n.contains("push") { return PlanWorkoutStyle(bg: .aura.accentSoft, tint: .aura.accent, border: .aura.accent) }
    if n.contains("pull") { return PlanWorkoutStyle(bg: .aura.blue.opacity(0.14), tint: .aura.blue, border: .aura.blue) }
    if n.contains("leg")  { return PlanWorkoutStyle(bg: .aura.green.opacity(0.14), tint: .aura.green, border: .aura.green) }
    if n.contains("upper"){ return PlanWorkoutStyle(bg: .aura.purple.opacity(0.14), tint: .aura.purple, border: .aura.purple) }
    return PlanWorkoutStyle(bg: .aura.accentSoft, tint: .aura.accent, border: .aura.accent)
}

func planWkIcon(_ name: String?) -> String {
    let n = (name ?? "").lowercased()
    if n.contains("push")  { return "flame.fill" }
    if n.contains("pull")  { return "bolt.fill" }
    if n.contains("leg")   { return "trophy.fill" }
    if n.contains("upper") { return "arrow.up" }
    return "dumbbell.fill"
}

// MARK: - Muscle thumbnail / chip palette (catalog grids + filter chips)

enum PlanMusclePalette {
    /// 2-up catalog thumbnail gradient + text colour, keyed by muscle.
    static func thumb(_ muscle: String) -> (bg: LinearGradient, tx: Color) {
        func grad(_ a: String, _ b: String) -> LinearGradient {
            LinearGradient(colors: [Color(hex: a), Color(hex: b)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        switch muscle {
        case "Chest":     return (grad("#F3D9B8", "#EBC089"), Color(hex: "#9C5A12"))
        case "Back":      return (grad("#CFD9EE", "#B0C2E6"), Color(hex: "#2C4C8E"))
        case "Shoulders": return (grad("#DAD3EE", "#C6BBE6"), Color(hex: "#4C3A8E"))
        case "Biceps", "Triceps":
                          return (grad("#C9E9D2", "#A8DDB8"), Color(hex: "#1F6E3A"))
        case "Legs":      return (grad("#F3CFC2", "#EBB0A0"), Color(hex: "#8E3A27"))
        case "Core":      return (grad("#F3C9C5", "#EBA8A2"), Color(hex: "#8E2C26"))
        default:          return (grad("#EDEAE6", "#E0DDDA"), .aura.text3)
        }
    }

    /// Colour-coded muscle filter chip (Exercises library).
    static func chip(_ muscle: String) -> (soft: Color, tx: Color, active: Color)? {
        switch muscle {
        case "Chest":     return (Color(hex: "#F6E6CE"), Color(hex: "#9C5A12"), Color(hex: "#C77A1E"))
        case "Back":      return (Color(hex: "#DEE6F4"), Color(hex: "#2C4C8E"), Color(hex: "#3A5FA8"))
        case "Shoulders": return (Color(hex: "#E5DFF4"), Color(hex: "#4C3A8E"), Color(hex: "#5F4CA8"))
        case "Arms":      return (Color(hex: "#D8F0DF"), Color(hex: "#1F6E3A"), Color(hex: "#2E8049"))
        case "Legs":      return (Color(hex: "#F6DDD2"), Color(hex: "#8E3A27"), Color(hex: "#A84C2E"))
        case "Core":      return (Color(hex: "#F6D5D1"), Color(hex: "#8E2C26"), Color(hex: "#A8342E"))
        default:          return nil
        }
    }

    /// "Arms" surfaces Biceps + Triceps; everything else displays as-is.
    static func displayLabel(_ muscle: String) -> String {
        (muscle == "Biceps" || muscle == "Triceps") ? "Arms" : muscle
    }
}
