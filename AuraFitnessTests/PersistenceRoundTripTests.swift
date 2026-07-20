import XCTest
@testable import AuraFitness

final class PersistenceRoundTripTests: XCTestCase {

    // MARK: - Key strings (copied verbatim from AppState.Keys)

    let dayOverridesKey    = "aura_day_overrides_v1"
    let quickLogsKey       = "aura_quick_logs_v1"
    let progressPhotosKey = "aura_progress_photos_v1"

    // Additional keys AppState() reads on init — cleared to avoid cross-test bleed.
    let workoutLogsKey      = "aura_workout_logs_v1"
    let measurementsKey     = "aura_measurements_v1"
    let bodyStatsKey        = "aura_body_stats_v1"
    let personalRecordsKey  = "aura_personal_records_v1"
    let userProfileKey      = "aura_user_profile_v1"
    let workoutPrefsKey     = "aura_workout_prefs_v1"
    let darkKey             = "aura_dark"
    let calStartKey         = "aura_calstart"
    let logStatKey          = "aura_logstat"

    // MARK: - setUp / tearDown

    override func setUp() {
        super.setUp()
        clearStandardDefaultsKeys()
    }

    override func tearDown() {
        clearStandardDefaultsKeys()
        super.tearDown()
    }

    private func clearStandardDefaultsKeys() {
        let d = UserDefaults.standard
        d.removeObject(forKey: dayOverridesKey)
        d.removeObject(forKey: quickLogsKey)
        d.removeObject(forKey: progressPhotosKey)
        d.removeObject(forKey: workoutLogsKey)
        d.removeObject(forKey: measurementsKey)
        d.removeObject(forKey: bodyStatsKey)
        d.removeObject(forKey: personalRecordsKey)
        d.removeObject(forKey: userProfileKey)
        d.removeObject(forKey: workoutPrefsKey)
        d.removeObject(forKey: darkKey)
        d.removeObject(forKey: calStartKey)
        d.removeObject(forKey: logStatKey)
    }

    // MARK: - Shared helpers

    /// Mirrors `persistCodable`/`loadCodable` exactly (no custom strategies).
    private func roundTrip<T: Codable>(_ value: T, as type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(type, from: data)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AuraFitnessTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private func makeExercise(name: String) -> Exercise {
        Exercise(
            name: name,
            primaryMuscle: "Chest",
            muscleGroups: ["Chest"],
            equipment: "Barbell",
            difficulty: "Intermediate",
            isCable: false,
            repRange: Exercise.fallbackRepRange,
            plannedSets: Exercise.fallbackSets
        )
    }

    // MARK: - Test 2: [String: DayOverride] round-trip

    func test_dayOverrides_dictionaryRoundTrip_keysAndValuesIntact() throws {
        var original: [String: DayOverride] = [:]
        original["2026-07-01"] = DayOverride(kind: .rest)
        original["2026-07-02"] = DayOverride(kind: .switched, workoutId: UUID())
        original["2026-07-03"] = DayOverride(kind: .edited, workoutId: nil, editedExercises: [makeExercise(name: "Bench Press")])

        let decoded = try roundTrip(original, as: [String: DayOverride].self)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(Set(decoded.keys), Set(original.keys))
        XCTAssertEqual(decoded["2026-07-02"]?.workoutId, original["2026-07-02"]?.workoutId)
        XCTAssertEqual(decoded["2026-07-03"]?.editedExercises?.first?.name, "Bench Press")
    }

    // MARK: - Test 3: [String: QuickLog] round-trip

    func test_quickLogs_dictionaryRoundTrip_keysAndValuesIntact() throws {
        var original: [String: QuickLog] = [:]
        original["2026-07-10"] = QuickLog(
            time: "08:30",
            exercises: [
                QuickLogExercise(
                    name: "Squat",
                    sets: [
                        QuickLogSet(weight: "100", reps: "5"),
                        QuickLogSet(weight: "100", reps: "5")
                    ]
                )
            ]
        )
        original["2026-07-11"] = QuickLog(time: "18:00", exercises: [])

        let decoded = try roundTrip(original, as: [String: QuickLog].self)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded["2026-07-10"]?.time, "08:30")
        XCTAssertEqual(decoded["2026-07-10"]?.exercises.first?.sets.count, 2)
        XCTAssertEqual(decoded["2026-07-10"]?.exercises.first?.sets.first?.weight, "100")
        XCTAssertEqual(decoded["2026-07-10"]?.exercises.first?.sets.first?.reps, "5")
    }

    // MARK: - Test 4: ProgressPhoto Data field round-trip

    func test_progressPhoto_dataFieldRoundTrip_bytesIdentical() throws {
        let bytes = Data((0..<256).map { UInt8($0) })
        let original = ProgressPhoto(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            imageData: bytes,
            weight: 78.4,
            note: "front"
        )

        let decoded = try roundTrip([original], as: [ProgressPhoto].self).first

        XCTAssertEqual(decoded?.imageData, bytes)
        XCTAssertEqual(decoded?.imageData.count, 256)
        XCTAssertEqual(decoded?.note, "front")
        XCTAssertEqual(decoded?.weight, 78.4)
        XCTAssertEqual(decoded?.id, original.id)

        // Optional hardening: verify base64 encoding of the raw bytes appears in the JSON.
        let singleData = try JSONEncoder().encode(original)
        let jsonString = String(data: singleData, encoding: .utf8) ?? ""
        let expectedBase64 = bytes.base64EncodedString()
        XCTAssertTrue(jsonString.contains(expectedBase64))
    }

    // MARK: - Test 5: Full persist -> relaunch simulation via real AppState

    @MainActor
    func test_fullPersistRelaunch_simulation_freshAppStatePicksUpMutatedCollections() throws {
        // Step A: mutate + persist through the real app path.
        let state = AppState()
        state.dayOverrides = ["2026-07-01": DayOverride(kind: .rest)]
        state.quickLogs = ["2026-07-10": QuickLog(time: "08:30", exercises: [])]
        state.progressPhotos = [
            ProgressPhoto(
                date: Date(timeIntervalSince1970: 1_700_000_000),
                imageData: Data([1, 2, 3, 4]),
                weight: 80,
                note: "x"
            )
        ]

        // Step B: relaunch — fresh AppState reads back from UserDefaults.standard.
        let relaunched = AppState()

        // Step C: assertions.
        XCTAssertEqual(relaunched.dayOverrides, state.dayOverrides)
        XCTAssertEqual(relaunched.quickLogs, state.quickLogs)
        XCTAssertEqual(relaunched.progressPhotos.first?.imageData, Data([1, 2, 3, 4]))
        XCTAssertEqual(relaunched.progressPhotos.count, 1)
    }
}
