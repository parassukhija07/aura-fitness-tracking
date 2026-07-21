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
    /// Written by `ProgressPhotoStorage` whenever a photo is stored with its
    /// bytes still inline — which Test 5 does — so it needs clearing too.
    let photoUploadPendingKey = "aura_photo_upload_pending_v1"

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
        d.removeObject(forKey: photoUploadPendingKey)
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
        XCTAssertEqual(decoded?.imageData?.count, 256)
        XCTAssertEqual(decoded?.note, "front")
        XCTAssertEqual(decoded?.weight, 78.4)
        XCTAssertEqual(decoded?.id, original.id)
        // A pre-phase3-01 photo has no path — the bytes are still inline.
        XCTAssertNil(decoded?.storagePath)

        // Optional hardening: verify base64 encoding of the raw bytes appears in the JSON.
        let singleData = try JSONEncoder().encode(original)
        let jsonString = String(data: singleData, encoding: .utf8) ?? ""
        let expectedBase64 = bytes.base64EncodedString()
        XCTAssertTrue(jsonString.contains(expectedBase64))
    }

    /// The post-migration shape (phase3-01): bytes live in the
    /// `progress-photos` bucket, so the row carries a path and NO base64. The
    /// encoded payload must actually omit `imageData` — that omission is the
    /// entire point of moving photos to Storage, and a row that still shipped
    /// a null/empty blob would keep the payload large for no reason.
    func test_progressPhoto_storagePathRow_roundTripsWithoutInlineBytes() throws {
        let original = ProgressPhoto(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            imageData: nil,
            weight: 78.4,
            note: "front",
            storagePath: "11111111-1111-1111-1111-111111111111/22222222-2222-2222-2222-222222222222.jpg"
        )

        let decoded = try roundTrip([original], as: [ProgressPhoto].self).first

        XCTAssertNil(decoded?.imageData)
        XCTAssertEqual(decoded?.storagePath, original.storagePath)
        XCTAssertEqual(decoded?.id, original.id)

        let jsonString = String(data: try JSONEncoder().encode(original), encoding: .utf8) ?? ""
        XCTAssertFalse(jsonString.contains("imageData"))
    }

    /// Rows written before `storagePath` existed must keep decoding — the lazy
    /// migration reads them, uploads their bytes, and only then rewrites them.
    /// A decode failure here would strand those photos permanently.
    func test_progressPhoto_legacyJSONWithoutStoragePath_decodes() throws {
        let bytes = Data([9, 8, 7, 6])
        let legacyJSON = """
        [{"id":"33333333-3333-3333-3333-333333333333",\
        "date":723427200,\
        "imageData":"\(bytes.base64EncodedString())",\
        "weight":78.4,\
        "note":"legacy"}]
        """

        let decoded = try JSONDecoder().decode([ProgressPhoto].self, from: Data(legacyJSON.utf8)).first

        XCTAssertEqual(decoded?.imageData, bytes)
        XCTAssertNil(decoded?.storagePath)
        XCTAssertEqual(decoded?.note, "legacy")
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
