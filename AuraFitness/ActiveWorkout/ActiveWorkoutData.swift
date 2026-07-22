import SwiftUI

// MARK: - Active Workout option data (mirrors workout/data.jsx + app.jsx)

/// A quick-pick exercise option used by the add/substitute/empty-overview flows.
struct WorkoutExerciseOption: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let muscle: String
    let equipment: String
}

/// A muscle group for the empty-overview quick-add (mirrors `MG`).
struct MuscleGroupOption: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let color: Color
    /// (exercise name, equipment) pairs.
    let exercises: [WorkoutExerciseOption]
}

enum ActiveWorkoutData {
    // Substitute options (SUB_OPTIONS)
    static let substituteOptions: [WorkoutExerciseOption] = [
        .init(name: "Dumbbell Bench Press", muscle: "Chest", equipment: "Dumbbell"),
        .init(name: "Machine Chest Press",  muscle: "Chest", equipment: "Machine"),
        .init(name: "Smith Machine Bench",  muscle: "Chest", equipment: "Smith Machine"),
        .init(name: "Push-Up (Weighted)",   muscle: "Chest", equipment: "Bodyweight"),
    ]

    // Add-exercise suggestions (ADD_OPTIONS)
    static let addOptions: [WorkoutExerciseOption] = [
        .init(name: "Pec Deck",                   muscle: "Chest",          equipment: "Machine"),
        .init(name: "Dips",                       muscle: "Chest · Triceps", equipment: "Bodyweight"),
        .init(name: "Overhead Triceps Extension", muscle: "Triceps",        equipment: "Cable"),
        .init(name: "Front Raise",                muscle: "Front Delts",    equipment: "Dumbbell"),
        .init(name: "Face Pull",                  muscle: "Rear Delts",     equipment: "Cable"),
    ]

    // Equipment filter chips for the empty overview (EQUIPS)
    //
    // Must cover every `equipment` value the library actually carries, or those
    // exercises are reachable only by search — the chips filter on an exact
    // string match. Ordered by how many exercises use each, so the common
    // apparatus sits nearest the leading edge of the scroll.
    //
    // KEEP IN SYNC with AuraFitness/Resources/gym_exercise_library.json, whose
    // vocabulary is set by `EQUIPMENT_MAP` in supabase/seed/import_dataset.py.
    // Re-derive after a catalog change with:
    //   python -c "import json, collections; print(collections.Counter(x['equipment'] for x in json.load(open('AuraFitness/Resources/gym_exercise_library.json', encoding='utf-8'))).most_common())"
    static let equipmentFilters = [
        "All", "Bodyweight", "Dumbbell", "Barbell", "Cable", "Machine", "Band",
        "Smith Machine", "Kettlebell", "Stability Ball", "Assisted",
        "Medicine Ball", "Rope", "Roller", "Cardio Machine", "Bosu Ball", "Other"
    ]

    // Quick-add by muscle (MG)
    static let muscleGroups: [MuscleGroupOption] = [
        .init(label: "Chest", color: .aura.accent, exercises: [
            .init(name: "Barbell Bench Press", muscle: "Chest", equipment: "Barbell"),
            .init(name: "Incline DB Press",    muscle: "Chest", equipment: "Dumbbell"),
            .init(name: "Cable Fly",           muscle: "Chest", equipment: "Cable"),
            .init(name: "Push-Up",             muscle: "Chest", equipment: "Bodyweight"),
        ]),
        .init(label: "Back", color: .aura.blue, exercises: [
            .init(name: "Barbell Row",   muscle: "Back", equipment: "Barbell"),
            .init(name: "Pull-Up",       muscle: "Back", equipment: "Bodyweight"),
            .init(name: "Lat Pulldown",  muscle: "Back", equipment: "Cable"),
            .init(name: "Seated Row",    muscle: "Back", equipment: "Cable"),
        ]),
        .init(label: "Legs", color: .aura.red, exercises: [
            .init(name: "Barbell Squat",     muscle: "Legs", equipment: "Barbell"),
            .init(name: "Romanian Deadlift", muscle: "Legs", equipment: "Barbell"),
            .init(name: "Leg Press",         muscle: "Legs", equipment: "Machine"),
            .init(name: "Leg Curl",          muscle: "Legs", equipment: "Machine"),
        ]),
        .init(label: "Shoulders", color: .aura.purple, exercises: [
            .init(name: "Overhead Press", muscle: "Shoulders", equipment: "Barbell"),
            .init(name: "Lateral Raise",  muscle: "Shoulders", equipment: "Dumbbell"),
            .init(name: "Face Pulls",     muscle: "Shoulders", equipment: "Cable"),
            .init(name: "Arnold Press",   muscle: "Shoulders", equipment: "Dumbbell"),
        ]),
        .init(label: "Arms", color: .aura.green, exercises: [
            .init(name: "Barbell Curl",     muscle: "Arms", equipment: "Barbell"),
            .init(name: "Tricep Pushdown",  muscle: "Arms", equipment: "Cable"),
            .init(name: "Hammer Curl",      muscle: "Arms", equipment: "Dumbbell"),
            .init(name: "Skull Crushers",   muscle: "Arms", equipment: "Barbell"),
        ]),
        .init(label: "Core", color: Color(hex: "#A8853F"), exercises: [
            .init(name: "Plank",             muscle: "Core", equipment: "Bodyweight"),
            .init(name: "Cable Crunch",      muscle: "Core", equipment: "Cable"),
            .init(name: "Ab Wheel",          muscle: "Core", equipment: "Bodyweight"),
            .init(name: "Hanging Leg Raise", muscle: "Core", equipment: "Bodyweight"),
        ]),
    ]

    // Suggested catalog when no muscle is selected (suggestions)
    static let suggestions: [WorkoutExerciseOption] = [
        .init(name: "Barbell Squat",  muscle: "Legs",      equipment: "Barbell"),
        .init(name: "Overhead Press", muscle: "Shoulders", equipment: "Barbell"),
        .init(name: "Barbell Row",    muscle: "Back",      equipment: "Barbell"),
        .init(name: "Dumbbell Curl",  muscle: "Arms",      equipment: "Dumbbell"),
        .init(name: "Bench Press",    muscle: "Chest",     equipment: "Barbell"),
        .init(name: "Cable Crunch",   muscle: "Core",      equipment: "Cable"),
    ]

    /// Color for a muscle name (mirrors muscleColor()).
    static func muscleColor(_ m: String) -> Color {
        let ml = m.lowercased()
        if ml.contains("chest") { return .aura.accent }
        if ml.contains("back") || ml.contains("bicep") || ml.contains("pull") { return .aura.blue }
        if ml.contains("delt") || ml.contains("shoulder") { return .aura.purple }
        if ml.contains("tricep") { return .aura.green }
        if ml.contains("leg") || ml.contains("glute") || ml.contains("hamstring") { return .aura.red }
        return .aura.text2
    }

    /// Two-letter initials for a muscle name (mirrors muscleInitial()).
    static func muscleInitial(_ m: String) -> String {
        let parts = m.split(separator: " ").compactMap { $0.first }
        return String(parts.prefix(2)).uppercased()
    }
}

extension WorkoutExerciseOption {
    /// Build a fresh Exercise (3 empty sets) from a quick-pick option.
    func makeExercise() -> Exercise {
        var e = Exercise(
            name: name,
            primaryMuscle: muscle,
            muscleGroups: [muscle],
            equipment: equipment,
            difficulty: "Beginner",
            isCable: equipment == "Cable",
            repRange: "8–12",
            plannedSets: 3,
            target: TargetRecord(weight: 0, reps: 10, note: "First time"),
            hint: "Focus on controlled form."
        )
        e.sets = (0..<3).map { _ in WorkoutSet() }
        return e
    }
}
