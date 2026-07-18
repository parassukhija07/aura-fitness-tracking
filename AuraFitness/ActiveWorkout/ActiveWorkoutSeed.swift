import Foundation

/// The seeded "Push Day A" mid-session workout, mirroring `workout/data.jsx`
/// exactly (6 exercises, pre-logged sets, PRs/targets/history/warm-ups, and the
/// `ohp` exercise pre-flagged as a superset leader).
///
/// `version` gates schema-compatible restore (see `WorkoutPersistence`). Bump it
/// whenever the persisted shape changes so stale blobs are cleared, not crashed.
enum ActiveWorkoutSeed {
    /// Bumped when the persisted workout shape changes (data.jsx `WORKOUT.version`).
    /// v6: `SavedWorkout.workoutKey` added (WorkoutPersistence) — forces stale
    /// pre-v6 blobs to clear rather than crash on decode.
    static let version = 6

    #if DEBUG
    /// Seed elapsed seconds (24:47) for the demo mid-session (data.jsx default).
    static let seedElapsed = 1487

    /// Demo-only: `pushDayA()` is invoked exclusively by
    /// `AppState.debugStartPushDayDemo()`, never by the real `startWorkout` path.
    static func pushDayA() -> Workout {
        var w = Workout(
            id: UUID(),
            name: "Push Day A",
            primaryMuscles: "Chest · Shoulders · Triceps",
            estimatedMinutes: 60,
            exercises: [],
            program: "Push · Pull · Legs"
        )
        var ohpEx = ohp()
        var lateralEx = lateral()
        let seedSupersetID = UUID()
        ohpEx.supersetGroupID = seedSupersetID   // leader of the seeded superset pair
        lateralEx.supersetGroupID = seedSupersetID   // partner
        w.exercises = [bench(), incline(), fly(), ohpEx, lateralEx, pushdown()]
        return w
    }

    // MARK: - Per-exercise seeds (1:1 with data.jsx)

    private static func bench() -> Exercise {
        var e = Exercise(
            name: "Barbell Bench Press", primaryMuscle: "Chest",
            muscleGroups: ["Chest", "Front Delts", "Triceps"],
            equipment: "Barbell", difficulty: "Intermediate", isCable: false,
            repRange: "6–8", plannedSets: 4,
            lastPR: PRRecord(weight: 80, reps: 6, date: "May 28"),
            target: TargetRecord(weight: 82.5, reps: 6, note: "+2.5 kg vs last session"),
            history: [
                SetHistory(weight: "80", reps: "6"),
                SetHistory(weight: "80", reps: "5"),
                SetHistory(weight: "77.5", reps: "6"),
            ],
            warmup: [
                WarmupSet(reps: 12, label: "Empty bar"),
                WarmupSet(reps: 8, label: "40%"),
                WarmupSet(reps: 5, label: "60%"),
                WarmupSet(reps: 3, label: "80%"),
            ],
            hint: "Drive your feet into the floor and keep your shoulder blades pinned back and down. Lower the bar to your lower chest, not your neck."
        )
        e.sets = [
            WorkoutSet(weight: 82.5, reps: 6, done: true),
            WorkoutSet(weight: 82.5, reps: 6, done: true),
            WorkoutSet(weight: 80, reps: 5, done: false),
            WorkoutSet(),
        ]
        return e
    }

    private static func incline() -> Exercise {
        var e = Exercise(
            name: "Incline Dumbbell Press", primaryMuscle: "Upper Chest",
            muscleGroups: ["Upper Chest", "Front Delts"],
            equipment: "Dumbbell", difficulty: "Intermediate", isCable: false,
            repRange: "8–10", plannedSets: 3,
            lastPR: PRRecord(weight: 32, reps: 9, date: "May 28"),
            target: TargetRecord(weight: 32, reps: 9, note: "Match last, add a rep"),
            history: [
                SetHistory(weight: "30", reps: "10"),
                SetHistory(weight: "30", reps: "9"),
                SetHistory(weight: "28", reps: "10"),
                SetHistory(weight: "28", reps: "8"),
            ],
            warmup: [
                WarmupSet(reps: 10, label: "50%"),
                WarmupSet(reps: 6, label: "75%"),
            ],
            hint: "Set the bench to ~30°. Don’t let the dumbbells drift forward — keep them stacked over your elbows."
        )
        e.sets = [WorkoutSet(), WorkoutSet(), WorkoutSet()]
        return e
    }

    private static func fly() -> Exercise {
        var e = Exercise(
            name: "Cable Fly", primaryMuscle: "Chest",
            muscleGroups: ["Chest"],
            equipment: "Cable", difficulty: "Intermediate", isCable: true,
            pulley: "double", repRange: "12–15", plannedSets: 3,
            lastPR: PRRecord(weight: 15, reps: 14, date: "May 28"),
            target: TargetRecord(weight: 15, reps: 14, note: "Focus on the stretch"),
            history: [
                SetHistory(weight: "14", reps: "14"),
                SetHistory(weight: "14", reps: "13"),
                SetHistory(weight: "12.5", reps: "15"),
            ],
            warmup: [],
            hint: "Lead with your pinkies and squeeze at the midline. Keep a soft bend in the elbows throughout."
        )
        e.sets = [WorkoutSet(), WorkoutSet(), WorkoutSet()]
        return e
    }

    private static func ohp() -> Exercise {
        var e = Exercise(
            name: "Seated Shoulder Press", primaryMuscle: "Shoulders",
            muscleGroups: ["Front Delts", "Side Delts"],
            equipment: "Machine", difficulty: "Intermediate", isCable: false,
            repRange: "8–12", plannedSets: 3,
            lastPR: PRRecord(weight: 45, reps: 10, date: "May 28"),
            target: TargetRecord(weight: 47.5, reps: 9, note: "+2.5 kg vs last session"),
            history: [
                SetHistory(weight: "45", reps: "10"),
                SetHistory(weight: "45", reps: "9"),
                SetHistory(weight: "42.5", reps: "10"),
            ],
            warmup: [],
            hint: "Keep your core braced and avoid arching your lower back as you press overhead."
        )
        e.sets = [
            WorkoutSet(weight: 45, reps: 10, done: true),
            WorkoutSet(weight: 45, reps: 9, done: true),
            WorkoutSet(),
        ]
        return e
    }

    private static func lateral() -> Exercise {
        var e = Exercise(
            name: "Cable Lateral Raise", primaryMuscle: "Side Delts",
            muscleGroups: ["Side Delts"],
            equipment: "Cable", difficulty: "Intermediate", isCable: true,
            pulley: "single", repRange: "12–15", plannedSets: 3,
            lastPR: PRRecord(weight: 10, reps: 13, date: "May 28"),
            target: TargetRecord(weight: 10, reps: 13, note: "Slow eccentric"),
            history: [
                SetHistory(weight: "10", reps: "13"),
                SetHistory(weight: "10", reps: "12"),
                SetHistory(weight: "10", reps: "11"),
            ],
            warmup: [],
            hint: "Lead with your elbow, not your hand. Imagine pouring water from a jug at the top."
        )
        e.sets = [
            WorkoutSet(weight: 10, reps: 13, done: true),
            WorkoutSet(weight: 10, reps: 12, done: true),
            WorkoutSet(),
        ]
        return e
    }

    private static func pushdown() -> Exercise {
        var e = Exercise(
            name: "Triceps Rope Pushdown", primaryMuscle: "Triceps",
            muscleGroups: ["Triceps"],
            equipment: "Cable", difficulty: "Intermediate", isCable: true,
            pulley: "single", repRange: "10–12", plannedSets: 3,
            lastPR: PRRecord(weight: 25, reps: 12, date: "May 28"),
            target: TargetRecord(weight: 27.5, reps: 10, note: "+2.5 kg vs last session"),
            history: [
                SetHistory(weight: "25", reps: "12"),
                SetHistory(weight: "25", reps: "11"),
                SetHistory(weight: "22.5", reps: "12"),
            ],
            warmup: [],
            hint: "Keep your elbows pinned to your sides and spread the rope apart at the bottom of each rep."
        )
        e.sets = [WorkoutSet(), WorkoutSet(), WorkoutSet()]
        return e
    }
    #endif
}
