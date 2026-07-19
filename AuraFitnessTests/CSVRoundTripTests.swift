import XCTest
@testable import AuraFitness

/// Proves round-trip: build CSV from a fixture, parse it back, assert
/// equality on the columns CSV is responsible for (per the spec's fidelity
/// limit — nested `Exercise` fields not present as CSV columns are NOT
/// round-tripped through CSV; only the JSON archive is byte-exact).
/// Mirrors `AuraFitnessTests/PersistenceRoundTripTests.swift` style.
@MainActor
final class CSVRoundTripTests: XCTestCase {

    // MARK: - Measurements (nil vs 0 distinction)

    func test_measurementsCSV_roundTrip_distinguishesNilFromZero() throws {
        let withNils = Measurement(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            weight: 78.4, bodyFatPct: 14.2, neck: 38.0, chest: 104.0,
            waist: 82.0, hips: nil, arms: 40.5, thighs: 60.0, shoulders: nil
        )
        let withZero = Measurement(
            date: Date(timeIntervalSince1970: 1_700_100_000),
            weight: 0, bodyFatPct: nil, neck: nil, chest: nil,
            waist: nil, hips: 0, arms: nil, thighs: nil, shoulders: 0
        )

        let csv = CSVArchiveBuilder.measurementsCSV([withNils, withZero])
        let rows = try CSVParser.parse(csv)

        XCTAssertEqual(rows.count, 3) // header + 2 rows
        XCTAssertEqual(rows[0], [
            "measurement_id", "date", "weight", "body_fat_pct", "neck", "chest", "waist",
            "hips", "arms", "thighs", "shoulders",
        ])

        // Row 1: hips/shoulders are nil -> empty cells.
        let row1 = rows[1]
        XCTAssertEqual(row1[0], withNils.id.uuidString)
        XCTAssertEqual(row1[2], "78.4")
        XCTAssertEqual(row1[7], "") // hips nil -> empty
        XCTAssertEqual(row1[10], "") // shoulders nil -> empty

        // Row 2: weight/hips/shoulders are literal 0 -> "0.0", NOT empty.
        let row2 = rows[2]
        XCTAssertEqual(row2[2], "0.0") // weight = 0, not nil
        XCTAssertEqual(row2[7], "0.0") // hips = 0, not nil
        XCTAssertEqual(row2[10], "0.0") // shoulders = 0, not nil
        XCTAssertEqual(row2[3], "") // bodyFatPct nil -> empty

        // Round-trip via importMeasurements into a fresh AppState.
        let appState = try makeIsolatedAppState()
        let imported = DataImportService.importMeasurements(Array(rows.dropFirst()), appState: appState)
        XCTAssertEqual(imported, 2)
        XCTAssertEqual(appState.measurements.count, 2)

        let decoded1 = appState.measurements.first { $0.id == withNils.id }
        XCTAssertEqual(decoded1?.weight, 78.4)
        XCTAssertNil(decoded1?.hips)
        XCTAssertNil(decoded1?.shoulders)

        let decoded2 = appState.measurements.first { $0.id == withZero.id }
        XCTAssertEqual(decoded2?.weight, 0)
        XCTAssertEqual(decoded2?.hips, 0)
        XCTAssertEqual(decoded2?.shoulders, 0)
        XCTAssertNil(decoded2?.bodyFatPct)
    }

    // MARK: - Custom exercise

    func test_customExerciseCSV_roundTrip_pipeJoinedArraysAndFlags() throws {
        let entry = ExerciseEntry(
            name: "My Cable Row",
            category: "Back",
            equipment: "Cable",
            musclesTargeted: ["Latissimus Dorsi", "Biceps Brachii"],
            type: "Machine",
            difficulty: "Intermediate",
            repRange: "10–12",
            youtubeURL: "",
            imageURL: "",
            proTips: ["Keep chest up", "Squeeze at the back"],
            warmupProtocol: ExerciseWarmupProtocol(type: "No Warmup Required", steps: []),
            isCable: true,
            pulley: "double",
            isCustom: true,
            notes: "From my coach",
            isFavorite: false,
            plannedSets: 3
        )

        let csv = CSVArchiveBuilder.customExercisesCSV([entry])
        let rows = try CSVParser.parse(csv)
        XCTAssertEqual(rows.count, 2) // header + 1 row

        let row = rows[1]
        XCTAssertEqual(row[0], entry.id.uuidString)
        XCTAssertEqual(row[4], "Latissimus Dorsi|Biceps Brachii")
        XCTAssertEqual(row[10], "Keep chest up|Squeeze at the back")
        XCTAssertEqual(row[11], "true")
        XCTAssertEqual(row[12], "double")
        XCTAssertEqual(row[15], "false")

        let imported = DataImportService.importCustomExercises(Array(rows.dropFirst()))
        XCTAssertEqual(imported, 1)

        let decoded = ExerciseDatabase.shared.entry(id: entry.id)
        addTeardownBlock { ExerciseDatabase.shared.delete(id: entry.id) }

        XCTAssertEqual(decoded?.name, "My Cable Row")
        XCTAssertEqual(decoded?.musclesTargeted, ["Latissimus Dorsi", "Biceps Brachii"])
        XCTAssertEqual(decoded?.proTips, ["Keep chest up", "Squeeze at the back"])
        XCTAssertEqual(decoded?.isCable, true)
        XCTAssertEqual(decoded?.pulley, "double")
        XCTAssertEqual(decoded?.isFavorite, false)
        XCTAssertEqual(decoded?.isCustom, true)
    }

    // MARK: - Custom program: one workout, two exercises

    func test_programCSV_roundTrip_oneWorkoutTwoExercises() throws {
        let exerciseA = Exercise(
            name: "Barbell Bench Press", primaryMuscle: "Chest", muscleGroups: ["Chest"],
            equipment: "Barbell", difficulty: "Intermediate", isCable: false,
            repRange: "6–8", plannedSets: 4
        )
        let exerciseB = Exercise(
            name: "Incline Dumbbell Press", primaryMuscle: "Chest", muscleGroups: ["Chest"],
            equipment: "Dumbbell", difficulty: "Intermediate", isCable: false,
            repRange: "8–12", plannedSets: 3
        )
        let workout = Workout(
            name: "Push A", primaryMuscles: "Chest", estimatedMinutes: 58,
            exercises: [exerciseA, exerciseB], restBetweenSets: 60, restBetweenExercises: 90
        )
        let program = Program(
            name: "My PPL", daysPerWeek: 6, level: "Intermediate", style: "Hypertrophy",
            description: "Custom split", workouts: [workout], isPredefined: false
        )

        let csv = CSVArchiveBuilder.programsCSV([program])
        let rows = try CSVParser.parse(csv)
        XCTAssertEqual(rows.count, 3) // header + 2 exercise rows

        XCTAssertEqual(rows[1][0], program.id.uuidString)
        XCTAssertEqual(rows[1][1], "My PPL")
        XCTAssertEqual(rows[1][6], workout.id.uuidString)
        XCTAssertEqual(rows[1][13], "Barbell Bench Press")
        XCTAssertEqual(rows[2][13], "Incline Dumbbell Press")
        XCTAssertEqual(rows[1][18], "0") // exercise_order
        XCTAssertEqual(rows[2][18], "1")

        let imported = DataImportService.importPrograms(Array(rows.dropFirst()))
        XCTAssertEqual(imported, 1)
        addTeardownBlock { _ = ProgramDatabase.shared.deleteProgram(id: program.id) }

        let decoded = ProgramDatabase.shared.program(id: program.id)
        XCTAssertEqual(decoded?.name, "My PPL")
        XCTAssertEqual(decoded?.isPredefined, false)
        XCTAssertEqual(decoded?.workouts.count, 1)
        XCTAssertEqual(decoded?.workouts.first?.exercises.count, 2)
        XCTAssertEqual(decoded?.workouts.first?.exercises.first?.name, "Barbell Bench Press")
        XCTAssertEqual(decoded?.workouts.first?.exercises.last?.name, "Incline Dumbbell Press")
    }

    // MARK: - Workout history: 2 exercises x 2 sets

    func test_workoutHistoryCSV_roundTrip_twoExercisesTwoSetsEach() throws {
        var exerciseA = Exercise(
            name: "Barbell Squat", primaryMuscle: "Legs", muscleGroups: ["Legs"],
            equipment: "Barbell", difficulty: "Advanced", isCable: false
        )
        exerciseA.sets = [
            WorkoutSet(weight: 100, reps: 5, done: true, type: .normal, note: ""),
            WorkoutSet(weight: 100, reps: 5, done: true, type: .drop, note: "felt heavy"),
        ]
        var exerciseB = Exercise(
            name: "Leg Press", primaryMuscle: "Legs", muscleGroups: ["Legs"],
            equipment: "Machine", difficulty: "Beginner", isCable: false
        )
        exerciseB.sets = [
            WorkoutSet(weight: nil, reps: nil, done: false, type: .normal, note: ""),
            WorkoutSet(weight: 200, reps: 10, done: true, type: .failure, note: ""),
        ]

        let log = WorkoutLog(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            workoutName: "Leg Day A",
            exercises: [exerciseA, exerciseB],
            durationSeconds: 3480,
            sessionNotes: "Felt strong"
        )

        let csv = CSVArchiveBuilder.workoutHistoryCSV([log])
        let rows = try CSVParser.parse(csv)
        XCTAssertEqual(rows.count, 5) // header + 4 set rows

        // Row for exerciseB's first (unset) set: weight/reps empty, not "0".
        let unsetRow = rows[3]
        XCTAssertEqual(unsetRow[5], "Leg Press")
        XCTAssertEqual(unsetRow[10], "") // weight nil
        XCTAssertEqual(unsetRow[11], "") // reps nil
        XCTAssertEqual(unsetRow[12], "false")

        let appState = try makeIsolatedAppState()
        let imported = DataImportService.importWorkoutHistory(Array(rows.dropFirst()), appState: appState)
        XCTAssertEqual(imported, 1)
        XCTAssertEqual(appState.workoutLogs.count, 1)

        let decoded = appState.workoutLogs.first
        XCTAssertEqual(decoded?.workoutName, "Leg Day A")
        XCTAssertEqual(decoded?.durationSeconds, 3480)
        XCTAssertEqual(decoded?.exercises.count, 2)
        XCTAssertEqual(decoded?.exercises.first?.sets.count, 2)
        XCTAssertEqual(decoded?.exercises.last?.sets.count, 2)
        XCTAssertEqual(decoded?.exercises.first?.sets.first?.weight, 100)
        XCTAssertEqual(decoded?.exercises.first?.sets.last?.type, .drop)
        XCTAssertEqual(decoded?.exercises.last?.sets.first?.weight, nil)

        // Re-import is idempotent (dedupe by workout_log_id).
        let reimported = DataImportService.importWorkoutHistory(Array(rows.dropFirst()), appState: appState)
        XCTAssertEqual(reimported, 0)
        XCTAssertEqual(appState.workoutLogs.count, 1)
    }

    // MARK: - CSV escaping: comma + quote in a name

    func test_csvField_escapesCommaAndQuote_roundTrips() throws {
        let entry = ExerciseEntry(
            name: "Bob's \"Special\", Curl",
            category: "Arms",
            equipment: "Dumbbell",
            musclesTargeted: ["Biceps"],
            type: "Isolation",
            difficulty: "Beginner",
            repRange: "10–12",
            youtubeURL: "",
            imageURL: "",
            proTips: [],
            warmupProtocol: ExerciseWarmupProtocol(type: "No Warmup Required", steps: []),
            isCustom: true
        )

        let csv = CSVArchiveBuilder.customExercisesCSV([entry])
        // The raw serialized field must be quoted with doubled internal quotes.
        XCTAssertTrue(csv.contains("\"Bob's \"\"Special\"\", Curl\""))

        let rows = try CSVParser.parse(csv)
        XCTAssertEqual(rows[1][1], "Bob's \"Special\", Curl")

        let imported = DataImportService.importCustomExercises(Array(rows.dropFirst()))
        XCTAssertEqual(imported, 1)
        addTeardownBlock { ExerciseDatabase.shared.delete(id: entry.id) }

        XCTAssertEqual(ExerciseDatabase.shared.entry(id: entry.id)?.name, "Bob's \"Special\", Curl")
    }

    // MARK: - CSVParser: embedded newline inside a quoted field

    func test_csvParser_handlesEmbeddedNewlineInQuotedField() throws {
        let csv = "a,b\r\n\"line1\nline2\",value\r\n"
        let rows = try CSVParser.parse(csv)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1], ["line1\nline2", "value"])
    }

    // MARK: - Helpers

    /// A throwaway `AppState` isolated via UserDefaults key removal before
    /// construction, mirroring `PersistenceRoundTripTests`'s approach (no
    /// custom `UserDefaults` suite plumbing exists on `AppState` itself).
    @MainActor
    private func makeIsolatedAppState() throws -> AppState {
        let keys = ["aura_workout_logs_v1", "aura_measurements_v1"]
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }
        addTeardownBlock {
            for key in keys { UserDefaults.standard.removeObject(forKey: key) }
        }
        return AppState()
    }
}
