import Foundation
import UniformTypeIdentifiers
import Compression

/// Single entry point for importing either a JSON archive (`DataArchive`) or
/// a CSV file/zip (the 5 `CSVArchiveBuilder` categories) picked via
/// `.fileImporter`. Maps parsed rows back into the real stores using their
/// existing CRUD so write-through sync + persistence run automatically for
/// signed-in users, and local persistence runs for guests.
///
/// **Unit note:** CSV/JSON import does NOT convert units — importing under a
/// different unit preference than at export time will not auto-convert
/// weight/length values (matches JSON archive behavior).
@MainActor
enum DataImportService {

    struct ImportSummary {
        var workouts = 0
        var programs = 0
        var customWorkouts = 0
        var customExercises = 0
        var measurements = 0
        var skipped = 0

        var message: String {
            var parts: [String] = []
            if workouts > 0 { parts.append("\(workouts) workout\(workouts == 1 ? "" : "s")") }
            if programs > 0 { parts.append("\(programs) program\(programs == 1 ? "" : "s")") }
            if customWorkouts > 0 { parts.append("\(customWorkouts) custom workout\(customWorkouts == 1 ? "" : "s")") }
            if customExercises > 0 { parts.append("\(customExercises) custom exercise\(customExercises == 1 ? "" : "s")") }
            if measurements > 0 { parts.append("\(measurements) measurement\(measurements == 1 ? "" : "s")") }
            if parts.isEmpty {
                return skipped > 0 ? "Nothing new to import (\(skipped) skipped)" : "Nothing to import"
            }
            var msg = "Imported " + parts.joined(separator: ", ")
            if skipped > 0 { msg += " (\(skipped) skipped)" }
            return msg
        }
    }

    // MARK: - Entry point

    /// Detects file type by extension/UTType, routes to the right importer,
    /// returns a human summary string for the toast. Never throws into UI —
    /// returns a summary with a failure note on error.
    static func importFile(at url: URL, appState: AppState) async -> String {
        // Security-scoped resource: MANDATORY around every read of a file
        // handed back by `.fileImporter`, or the read silently returns empty
        // on-device.
        let ok = url.startAccessingSecurityScopedResource()
        defer { if ok { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.lowercased()

        do {
            switch ext {
            case "json":
                let data = try Data(contentsOf: url)
                let summary = importJSONArchive(data, appState: appState)
                return summary.message

            case "zip":
                let data = try Data(contentsOf: url)
                let summary = try await importZip(data, appState: appState)
                return summary.message

            case "csv":
                let data = try Data(contentsOf: url)
                guard let text = String(data: data, encoding: .utf8) else {
                    return "Couldn't read that file"
                }
                let summary = try importSingleCSV(named: url.lastPathComponent, text: text, appState: appState)
                return summary.message

            default:
                return "Unsupported file type"
            }
        } catch {
            return "Couldn't read that file"
        }
    }

    // MARK: - JSON archive

    static func importJSONArchive(_ data: Data, appState: AppState) -> ImportSummary {
        var summary = ImportSummary()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let archive = try? decoder.decode(DataArchive.self, from: data) else {
            summary.skipped += 1
            return summary
        }

        for program in archive.programs {
            if ProgramDatabase.shared.program(id: program.id) != nil {
                ProgramDatabase.shared.updateProgram(program)
            } else {
                ProgramDatabase.shared.addProgram(program)
            }
            summary.programs += 1
        }
        for plan in archive.plans {
            if UserPlanDatabase.shared.plans.contains(where: { $0.id == plan.id }) {
                UserPlanDatabase.shared.updatePlan(plan)
            } else {
                _ = UserPlanDatabase.shared.addPlan(plan)
            }
        }
        for entry in archive.exercises {
            if ExerciseDatabase.shared.entry(id: entry.id) != nil {
                ExerciseDatabase.shared.update(entry)
            } else {
                ExerciseDatabase.shared.add(entry)
            }
            if entry.isCustom { summary.customExercises += 1 }
        }
        for log in archive.workoutLogs where !appState.workoutLogs.contains(where: { $0.id == log.id }) {
            appState.workoutLogs.append(log)
            summary.workouts += 1
        }
        for measurement in archive.measurements where !appState.measurements.contains(where: { $0.id == measurement.id }) {
            appState.measurements.append(measurement)
            summary.measurements += 1
        }
        return summary
    }

    // MARK: - Zip (CSV bundle)

    private static let expectedInnerFiles: Set<String> = [
        "workout_history.csv", "programs.csv", "custom_workouts.csv",
        "custom_exercises.csv", "body_measurements.csv",
    ]

    /// Unzips a `.zip` blob in memory using a minimal, dependency-free ZIP
    /// central-directory reader (`MinimalZipReader` below, backed by the
    /// system `Compression` framework for `deflate` — no third-party
    /// dependency), then imports each recognized inner CSV by filename ->
    /// category. Unknown inner files are skipped (counted into `skipped`).
    private static func importZip(_ data: Data, appState: AppState) async throws -> ImportSummary {
        let entries = try MinimalZipReader.entries(from: data)

        var summary = ImportSummary()
        for (name, entryData) in entries {
            guard expectedInnerFiles.contains(name) else {
                summary.skipped += 1
                continue
            }
            guard let text = String(data: entryData, encoding: .utf8) else {
                summary.skipped += 1
                continue
            }
            let inner = try importSingleCSV(named: name, text: text, appState: appState)
            summary.workouts += inner.workouts
            summary.programs += inner.programs
            summary.customWorkouts += inner.customWorkouts
            summary.customExercises += inner.customExercises
            summary.measurements += inner.measurements
            summary.skipped += inner.skipped
        }
        return summary
    }

    private static func importSingleCSV(named name: String, text: String, appState: AppState) throws -> ImportSummary {
        var summary = ImportSummary()
        let rows = try CSVParser.parse(text)
        guard rows.count > 1 else { return summary } // header only / empty

        let body = Array(rows.dropFirst())
        switch name {
        case "workout_history.csv":
            summary.workouts = importWorkoutHistory(body, appState: appState)
        case "programs.csv":
            summary.programs = importPrograms(body)
        case "custom_workouts.csv":
            summary.customWorkouts = importCustomWorkouts(body)
        case "custom_exercises.csv":
            summary.customExercises = importCustomExercises(body)
        case "body_measurements.csv":
            summary.measurements = importMeasurements(body, appState: appState)
        default:
            summary.skipped += 1
        }
        return summary
    }

    // MARK: - Row -> store mapping helpers

    /// Blank or invalid UUID -> fresh `UUID()` so the row imports as new
    /// rather than crashing on bad ids.
    private static func uuid(_ s: String) -> UUID {
        UUID(uuidString: s) ?? UUID()
    }
    private static func optDouble(_ s: String) -> Double? { s.isEmpty ? nil : Double(s) }
    private static func optInt(_ s: String) -> Int? { s.isEmpty ? nil : Int(s) }
    private static func int(_ s: String, default def: Int = 0) -> Int { Int(s) ?? def }
    private static func bool(_ s: String) -> Bool { s == "true" }
    private static func pipeList(_ s: String) -> [String] {
        s.isEmpty ? [] : s.components(separatedBy: "|")
    }
    private static func date(_ s: String) -> Date {
        CSVArchiveBuilder.iso8601Formatter.date(from: s) ?? Date()
    }

    // Column index constants — see spec "CSV SCHEMAS" for the literal order.
    private enum Col {
        // workout_history.csv
        static let logID = 0, logDate = 1, workoutName = 2, durationSeconds = 3, sessionNotes = 4
        static let exerciseName = 5, primaryMuscle = 6, equipment = 7, setIndex = 8, setType = 9
        static let weight = 10, reps = 11, done = 12, setNote = 13

        // programs.csv
        static let programID = 0, programName = 1, daysPerWeek = 2, level = 3, style = 4, programDescription = 5
        static let pWorkoutID = 6, pWorkoutName = 7, pWorkoutOrder = 8, pEstimatedMinutes = 9
        static let pRestSets = 10, pRestExercises = 11
        static let pExerciseID = 12, pExerciseName = 13, pPrimaryMuscle = 14, pEquipment = 15
        static let pRepRange = 16, pPlannedSets = 17, pExerciseOrder = 18

        // custom_workouts.csv
        static let planID = 0, planName = 1, cwID = 2, cwName = 3
        static let cwEstimatedMinutes = 4, cwRestSets = 5, cwRestExercises = 6
        static let cwExerciseID = 7, cwExerciseName = 8, cwPrimaryMuscle = 9, cwEquipment = 10
        static let cwRepRange = 11, cwPlannedSets = 12, cwExerciseOrder = 13

        // custom_exercises.csv
        static let ceID = 0, ceName = 1, ceCategory = 2, ceEquipment = 3, ceMuscles = 4, ceType = 5
        static let ceDifficulty = 6, ceRepRange = 7, ceYoutube = 8, ceImage = 9, ceProTips = 10
        static let ceIsCable = 11, cePulley = 12, cePlannedSets = 13, ceNotes = 14, ceIsFavorite = 15

        // body_measurements.csv
        static let mID = 0, mDate = 1, mWeight = 2, mBodyFat = 3, mNeck = 4, mChest = 5
        static let mWaist = 6, mHips = 7, mArms = 8, mThighs = 9, mShoulders = 10
    }

    /// Groups by `workout_log_id`; reconstructs a `WorkoutLog` per group with
    /// an `Exercise` per distinct `exercise_name` within the group and a
    /// `WorkoutSet` per row. Appended only if a log with that id does not
    /// already exist (dedupe by id) — makes re-import idempotent.
    static func importWorkoutHistory(_ rows: [[String]], appState: AppState) -> Int {
        var count = 0
        let grouped = Dictionary(grouping: rows) { row -> UUID in
            row.count > Col.logID ? uuid(row[Col.logID]) : UUID()
        }

        for (logID, groupRows) in grouped {
            guard !appState.workoutLogs.contains(where: { $0.id == logID }) else { continue }
            guard let first = groupRows.first else { continue }

            var exercisesByName: [String: Exercise] = [:]
            var order: [String] = []

            for row in groupRows {
                guard row.count > Col.setNote else { continue }
                let name = row[Col.exerciseName]
                if exercisesByName[name] == nil {
                    exercisesByName[name] = Exercise(
                        name: name,
                        primaryMuscle: row[Col.primaryMuscle],
                        muscleGroups: [row[Col.primaryMuscle]],
                        equipment: row[Col.equipment],
                        difficulty: "Intermediate",
                        isCable: false
                    )
                    order.append(name)
                }
                let setType = SetType(rawValue: row[Col.setType]) ?? .normal
                let set = WorkoutSet(
                    weight: optDouble(row[Col.weight]),
                    reps: optInt(row[Col.reps]),
                    done: bool(row[Col.done]),
                    type: setType,
                    note: row[Col.setNote]
                )
                exercisesByName[name]?.sets.append(set)
            }

            let log = WorkoutLog(
                id: logID,
                date: date(first[Col.logDate]),
                workoutName: first[Col.workoutName],
                exercises: order.compactMap { exercisesByName[$0] },
                durationSeconds: int(first[Col.durationSeconds]),
                sessionNotes: first[Col.sessionNotes]
            )
            appState.workoutLogs.append(log)
            count += 1
        }
        return count
    }

    /// Groups by `program_id`; builds `Program(isPredefined: false)` with
    /// `Workout`s and `Exercise`s; adds if id absent, else updates.
    static func importPrograms(_ rows: [[String]]) -> Int {
        var count = 0
        let byProgram = Dictionary(grouping: rows) { row -> UUID in
            row.count > Col.programID ? uuid(row[Col.programID]) : UUID()
        }

        for (programID, programRows) in byProgram {
            guard let first = programRows.first else { continue }

            let byWorkout = Dictionary(grouping: programRows) { row -> UUID in
                row.count > Col.pWorkoutID ? uuid(row[Col.pWorkoutID]) : UUID()
            }
            let workouts: [Workout] = byWorkout.values.compactMap { workoutRows -> Workout? in
                guard let wFirst = workoutRows.first else { return nil }
                let sortedRows = workoutRows.sorted { int($0[Col.pExerciseOrder]) < int($1[Col.pExerciseOrder]) }
                let exercises: [Exercise] = sortedRows.map { row in
                    Exercise(
                        id: uuid(row[Col.pExerciseID]),
                        name: row[Col.pExerciseName],
                        primaryMuscle: row[Col.pPrimaryMuscle],
                        muscleGroups: [row[Col.pPrimaryMuscle]],
                        equipment: row[Col.pEquipment],
                        difficulty: "Intermediate",
                        isCable: false,
                        repRange: row[Col.pRepRange],
                        plannedSets: int(row[Col.pPlannedSets], default: 3)
                    )
                }
                return Workout(
                    id: uuid(wFirst[Col.pWorkoutID]),
                    name: wFirst[Col.pWorkoutName],
                    primaryMuscles: "",
                    estimatedMinutes: int(wFirst[Col.pEstimatedMinutes]),
                    exercises: exercises,
                    restBetweenSets: int(wFirst[Col.pRestSets], default: 60),
                    restBetweenExercises: int(wFirst[Col.pRestExercises], default: 90)
                )
            }
            let orderedWorkouts = workouts.sorted { a, b in
                let aOrder = programRows.first(where: { uuid($0[Col.pWorkoutID]) == a.id }).map { int($0[Col.pWorkoutOrder]) } ?? 0
                let bOrder = programRows.first(where: { uuid($0[Col.pWorkoutID]) == b.id }).map { int($0[Col.pWorkoutOrder]) } ?? 0
                return aOrder < bOrder
            }

            let program = Program(
                id: programID,
                name: first[Col.programName],
                daysPerWeek: int(first[Col.daysPerWeek]),
                level: first[Col.level],
                style: first[Col.style],
                description: first[Col.programDescription],
                workouts: orderedWorkouts,
                isPredefined: false
            )

            if ProgramDatabase.shared.program(id: programID) != nil {
                ProgramDatabase.shared.updateProgram(program)
            } else {
                ProgramDatabase.shared.addProgram(program)
            }
            count += 1
        }
        return count
    }

    /// Groups by `custom_workout_id`; each row is one exercise. Attached to
    /// the plan identified by `plan_id`; if the plan id is unknown locally,
    /// the group is skipped (never fabricates a plan).
    static func importCustomWorkouts(_ rows: [[String]]) -> Int {
        var count = 0
        let byWorkout = Dictionary(grouping: rows) { row -> UUID in
            row.count > Col.cwID ? uuid(row[Col.cwID]) : UUID()
        }

        for (workoutID, workoutRows) in byWorkout {
            guard let first = workoutRows.first else { continue }
            let planID = uuid(first[Col.planID])
            guard UserPlanDatabase.shared.plans.contains(where: { $0.id == planID }) else {
                continue // unknown plan id locally — skip, don't fabricate
            }

            let sortedRows = workoutRows.sorted { int($0[Col.cwExerciseOrder]) < int($1[Col.cwExerciseOrder]) }
            let exercises: [Exercise] = sortedRows.map { row in
                Exercise(
                    id: uuid(row[Col.cwExerciseID]),
                    name: row[Col.cwExerciseName],
                    primaryMuscle: row[Col.cwPrimaryMuscle],
                    muscleGroups: [row[Col.cwPrimaryMuscle]],
                    equipment: row[Col.cwEquipment],
                    difficulty: "Intermediate",
                    isCable: false,
                    repRange: row[Col.cwRepRange],
                    plannedSets: int(row[Col.cwPlannedSets], default: 3)
                )
            }
            let workout = Workout(
                id: workoutID,
                name: first[Col.cwName],
                primaryMuscles: "",
                estimatedMinutes: int(first[Col.cwEstimatedMinutes]),
                exercises: exercises,
                restBetweenSets: int(first[Col.cwRestSets], default: 60),
                restBetweenExercises: int(first[Col.cwRestExercises], default: 90)
            )

            if UserPlanDatabase.shared.plans.first(where: { $0.id == planID })?.customWorkouts.contains(where: { $0.id == workoutID }) == true {
                UserPlanDatabase.shared.updateCustomWorkout(workout, in: planID)
            } else {
                UserPlanDatabase.shared.addCustomWorkout(workout, to: planID)
            }
            count += 1
        }
        return count
    }

    /// Builds `ExerciseEntry(isCustom: true)`; adds if id absent, else updates.
    static func importCustomExercises(_ rows: [[String]]) -> Int {
        var count = 0
        for row in rows {
            guard row.count > Col.ceIsFavorite else { continue }
            let id = uuid(row[Col.ceID])
            let entry = ExerciseEntry(
                id: id,
                name: row[Col.ceName],
                category: row[Col.ceCategory],
                equipment: row[Col.ceEquipment],
                musclesTargeted: pipeList(row[Col.ceMuscles]),
                type: row[Col.ceType],
                difficulty: row[Col.ceDifficulty],
                repRange: row[Col.ceRepRange],
                youtubeURL: row[Col.ceYoutube],
                imageURL: row[Col.ceImage],
                proTips: pipeList(row[Col.ceProTips]),
                warmupProtocol: ExerciseWarmupProtocol(type: "No Warmup Required", steps: []),
                isCable: bool(row[Col.ceIsCable]),
                pulley: row[Col.cePulley].isEmpty ? "single" : row[Col.cePulley],
                isCustom: true,
                notes: row[Col.ceNotes],
                isFavorite: bool(row[Col.ceIsFavorite]),
                plannedSets: int(row[Col.cePlannedSets], default: 3)
            )

            if ExerciseDatabase.shared.entry(id: id) != nil {
                ExerciseDatabase.shared.update(entry)
            } else {
                ExerciseDatabase.shared.add(entry)
            }
            count += 1
        }
        return count
    }

    /// Builds `Measurement`; appends to `appState.measurements` if id absent
    /// (dedupe by id keeps re-import idempotent).
    static func importMeasurements(_ rows: [[String]], appState: AppState) -> Int {
        var count = 0
        for row in rows {
            guard row.count > Col.mShoulders else { continue }
            let id = uuid(row[Col.mID])
            guard !appState.measurements.contains(where: { $0.id == id }) else { continue }

            let measurement = Measurement(
                id: id,
                date: date(row[Col.mDate]),
                weight: optDouble(row[Col.mWeight]),
                bodyFatPct: optDouble(row[Col.mBodyFat]),
                neck: optDouble(row[Col.mNeck]),
                chest: optDouble(row[Col.mChest]),
                waist: optDouble(row[Col.mWaist]),
                hips: optDouble(row[Col.mHips]),
                arms: optDouble(row[Col.mArms]),
                thighs: optDouble(row[Col.mThighs]),
                shoulders: optDouble(row[Col.mShoulders])
            )
            appState.measurements.append(measurement)
            count += 1
        }
        return count
    }
}

// MARK: - MinimalZipReader

/// A minimal, dependency-free ZIP reader: parses the End-Of-Central-Directory
/// record + Central Directory to enumerate entries, then reads each Local
/// File Header to extract entry bytes. Supports the two compression methods
/// any zip produced by `NSFileCoordinator`'s `.forUploading` "zip a folder"
/// trick can use — 0 (stored) and 8 (deflate, inflated via the system
/// `Compression` framework, NOT a third-party dependency).
///
/// This is intentionally minimal (no encryption, no Zip64, no multi-disk
/// support) — sufficient for round-tripping Aura's own CSV export zips.
enum MinimalZipReader {
    enum ZipError: Error { case malformed, unsupportedCompression(UInt16) }

    static func entries(from data: Data) throws -> [(name: String, data: Data)] {
        let bytes = [UInt8](data)
        guard let eocdOffset = findEOCD(bytes) else { throw ZipError.malformed }

        // End Of Central Directory record (fixed 22-byte layout, ignoring
        // Zip64 / multi-disk archives which Aura's own exporter never produces).
        func u16(_ off: Int) -> UInt16 { UInt16(bytes[off]) | (UInt16(bytes[off + 1]) << 8) }
        func u32(_ off: Int) -> UInt32 {
            UInt32(bytes[off]) | (UInt32(bytes[off + 1]) << 8) | (UInt32(bytes[off + 2]) << 16) | (UInt32(bytes[off + 3]) << 24)
        }

        let entryCount = Int(u16(eocdOffset + 10))
        let centralDirOffset = Int(u32(eocdOffset + 16))

        var results: [(String, Data)] = []
        var cursor = centralDirOffset

        for _ in 0..<entryCount {
            guard cursor + 46 <= bytes.count, u32(cursor) == 0x02014b50 else { throw ZipError.malformed }

            let compressionMethod = u16(cursor + 10)
            let compressedSize = Int(u32(cursor + 20))
            let nameLength = Int(u16(cursor + 28))
            let extraLength = Int(u16(cursor + 30))
            let commentLength = Int(u16(cursor + 32))
            let localHeaderOffset = Int(u32(cursor + 42))

            guard cursor + 46 + nameLength <= bytes.count else { throw ZipError.malformed }
            let nameBytes = Array(bytes[(cursor + 46)..<(cursor + 46 + nameLength)])
            let name = String(bytes: nameBytes, encoding: .utf8) ?? ""

            let entryData = try readLocalEntry(
                bytes, at: localHeaderOffset,
                compressionMethod: compressionMethod,
                compressedSize: compressedSize
            )
            if !name.isEmpty, !name.hasSuffix("/") {
                // Directory entries (trailing "/") carry no file content.
                results.append((name, entryData))
            }

            cursor += 46 + nameLength + extraLength + commentLength
        }

        return results
    }

    private static func readLocalEntry(_ bytes: [UInt8], at offset: Int, compressionMethod: UInt16, compressedSize: Int) throws -> Data {
        func u16(_ off: Int) -> UInt16 { UInt16(bytes[off]) | (UInt16(bytes[off + 1]) << 8) }
        func u32(_ off: Int) -> UInt32 {
            UInt32(bytes[off]) | (UInt32(bytes[off + 1]) << 8) | (UInt32(bytes[off + 2]) << 16) | (UInt32(bytes[off + 3]) << 24)
        }
        guard offset + 30 <= bytes.count, u32(offset) == 0x04034b50 else { throw ZipError.malformed }

        let nameLength = Int(u16(offset + 26))
        let extraLength = Int(u16(offset + 28))
        let dataStart = offset + 30 + nameLength + extraLength
        guard dataStart + compressedSize <= bytes.count else { throw ZipError.malformed }

        let compressed = Data(bytes[dataStart..<(dataStart + compressedSize)])

        switch compressionMethod {
        case 0: // stored (no compression)
            return compressed
        case 8: // deflate
            return try inflate(compressed)
        default:
            throw ZipError.unsupportedCompression(compressionMethod)
        }
    }

    /// Raw DEFLATE inflate via the system `Compression` framework (zlib-
    /// compatible `COMPRESSION_ZLIB` algorithm operating on raw deflate
    /// streams, as ZIP's method-8 entries are headerless raw deflate).
    private static func inflate(_ compressed: Data) throws -> Data {
        var output = Data()
        let bufferSize = 64 * 1024
        var outputBuffer = [UInt8](repeating: 0, count: bufferSize)

        let result: Int? = compressed.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int? in
            guard let srcBase = srcPtr.bindMemory(to: UInt8.self).baseAddress else { return nil }

            var stream = compression_stream(
                dst_ptr: UnsafeMutablePointer<UInt8>(mutating: srcBase),
                dst_size: 0,
                src_ptr: srcBase,
                src_size: 0,
                state: nil
            )
            let status = compression_stream_init(&stream, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            guard status == COMPRESSION_STATUS_OK else { return nil }
            defer { compression_stream_destroy(&stream) }

            stream.src_ptr = srcBase
            stream.src_size = compressed.count

            var totalOut = 0
            var reachedEnd = false
            while !reachedEnd {
                let flush = outputBuffer.withUnsafeMutableBufferPointer { destPtr -> Int32 in
                    stream.dst_ptr = destPtr.baseAddress!
                    stream.dst_size = bufferSize
                    let flags: Int32 = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
                    let flushStatus = compression_stream_process(&stream, flags)
                    let produced = bufferSize - stream.dst_size
                    if produced > 0 {
                        output.append(contentsOf: destPtr.prefix(produced))
                        totalOut += produced
                    }
                    return flushStatus.rawValue
                }
                if flush == COMPRESSION_STATUS_ERROR.rawValue { return nil }
                if flush == COMPRESSION_STATUS_END.rawValue { reachedEnd = true }
                // COMPRESSION_STATUS_OK with nothing left to consume and
                // nothing produced would otherwise spin forever — bail out
                // defensively rather than hang.
                if flush == COMPRESSION_STATUS_OK.rawValue, stream.src_size == 0 { reachedEnd = true }
            }

            return totalOut
        }

        guard result != nil else { throw ZipError.malformed }
        return output
    }

    /// Scans backward for the End-Of-Central-Directory signature
    /// (`0x06054b50`). The EOCD is a fixed 22-byte record optionally followed
    /// by a variable-length comment, so scan the trailing ~64KB (max comment
    /// length) rather than assuming a fixed offset.
    private static func findEOCD(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 22 else { return nil }
        let searchStart = max(0, bytes.count - 22 - 65536)
        var i = bytes.count - 22
        while i >= searchStart {
            if bytes[i] == 0x50, bytes[i + 1] == 0x4b, bytes[i + 2] == 0x05, bytes[i + 3] == 0x06 {
                return i
            }
            i -= 1
        }
        return nil
    }
}
