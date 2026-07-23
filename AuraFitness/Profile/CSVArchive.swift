import Foundation

/// Builds the 5 CSV files that back the "Export as CSV" option, alongside
/// (not replacing) the JSON `DataArchiveBuilder` full backup. CSV is the
/// human-readable, per-category export — it deliberately does NOT carry
/// progress-photo blobs or preferences (see `DataArchive.swift`'s JSON path
/// for the lossless full backup).
///
/// **Unit note:** weights/lengths are stored raw in the user's current units
/// (kg/cm or lb/in per `RemotePrefs.weightUnit`/`lengthUnit`). CSV does NOT
/// convert units — importing under a different unit preference will not
/// auto-convert values (matches the JSON archive's existing behavior).
enum CSVArchiveBuilder {

    // MARK: - Shared formatting helpers

    /// Single shared ISO-8601 formatter so JSON (`DataArchiveBuilder`'s
    /// `.iso8601` strategy) and CSV agree on date formatting.
    static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// RFC-4180 escaping: any field containing `,` `"` or a newline is
    /// wrapped in double quotes, with internal `"` doubled.
    static func csvField(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    private static func field(_ d: Double?) -> String {
        guard let d else { return "" }
        return String(d)
    }
    private static func field(_ i: Int?) -> String {
        guard let i else { return "" }
        return String(i)
    }
    private static func field(_ b: Bool) -> String { b ? "true" : "false" }
    private static func field(_ date: Date) -> String { iso8601Formatter.string(from: date) }
    private static func field(_ arr: [String]) -> String { arr.joined(separator: "|") }

    private static func row(_ fields: [String]) -> String {
        fields.map(csvField).joined(separator: ",")
    }

    // MARK: - Category serializers (pure, testable, no I/O)

    /// Row-per-set. Header matches the spec's `workout_history.csv` schema exactly.
    static func workoutHistoryCSV(_ logs: [WorkoutLog]) -> String {
        var lines = [row([
            "workout_log_id", "log_date", "workout_name", "duration_seconds", "session_notes",
            "exercise_name", "primary_muscle", "equipment", "set_index", "set_type",
            "weight", "reps", "done", "set_note",
        ])]

        for log in logs {
            for exercise in log.exercises {
                for (idx, set) in exercise.sets.enumerated() {
                    lines.append(row([
                        log.id.uuidString,
                        field(log.date),
                        log.workoutName,
                        String(log.durationSeconds),
                        log.sessionNotes,
                        exercise.name,
                        exercise.primaryMuscle,
                        exercise.equipment,
                        String(idx),
                        set.type.rawValue,
                        field(set.weight),
                        field(set.reps),
                        field(set.done),
                        set.note,
                    ]))
                }
            }
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Row-per-exercise within a workout within a program. Custom
    /// (`isPredefined == false`) programs only.
    static func programsCSV(_ programs: [Program]) -> String {
        var lines = [row([
            "program_id", "program_name", "days_per_week", "level", "style", "program_description",
            "workout_id", "workout_name", "workout_order", "estimated_minutes",
            "rest_between_sets", "rest_between_exercises",
            "exercise_id", "exercise_name", "primary_muscle", "equipment", "rep_range",
            "planned_sets", "exercise_order",
        ])]

        for program in programs where !program.isPredefined {
            for (workoutOrder, workout) in program.workouts.enumerated() {
                for (exerciseOrder, exercise) in workout.exercises.enumerated() {
                    lines.append(row([
                        program.id.uuidString,
                        program.name,
                        String(program.daysPerWeek),
                        program.level,
                        program.style,
                        program.description,
                        workout.id.uuidString,
                        workout.name,
                        String(workoutOrder),
                        String(workout.estimatedMinutes),
                        String(workout.restBetweenSets),
                        String(workout.restBetweenExercises),
                        exercise.id.uuidString,
                        exercise.name,
                        exercise.primaryMuscle,
                        exercise.equipment,
                        exercise.repRange,
                        String(exercise.plannedSets),
                        String(exerciseOrder),
                    ]))
                }
            }
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Row-per-exercise for custom workouts living inside `UserPlan.customWorkouts`.
    static func customWorkoutsCSV(_ plans: [UserPlan]) -> String {
        var lines = [row([
            "plan_id", "plan_name", "custom_workout_id", "workout_name",
            "estimated_minutes", "rest_between_sets", "rest_between_exercises",
            "exercise_id", "exercise_name", "primary_muscle", "equipment", "rep_range",
            "planned_sets", "exercise_order",
        ])]

        for plan in plans {
            for workout in plan.customWorkouts {
                for (exerciseOrder, exercise) in workout.exercises.enumerated() {
                    lines.append(row([
                        plan.id.uuidString,
                        plan.name,
                        workout.id.uuidString,
                        workout.name,
                        String(workout.estimatedMinutes),
                        String(workout.restBetweenSets),
                        String(workout.restBetweenExercises),
                        exercise.id.uuidString,
                        exercise.name,
                        exercise.primaryMuscle,
                        exercise.equipment,
                        exercise.repRange,
                        String(exercise.plannedSets),
                        String(exerciseOrder),
                    ]))
                }
            }
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Row-per-exercise, `isCustom == true` only. `musclesTargeted`/`proTips`
    /// are pipe-joined single cells.
    static func customExercisesCSV(_ entries: [ExerciseEntry]) -> String {
        var lines = [row([
            "exercise_id", "name", "category", "equipment", "muscles_targeted", "type",
            "difficulty", "rep_range", "youtube_url", "image_url", "pro_tips",
            "is_cable", "pulley", "planned_sets", "notes", "is_favorite",
        ])]

        for entry in entries where entry.isCustom {
            lines.append(row([
                entry.id.uuidString,
                entry.name,
                entry.category,
                entry.equipment,
                field(entry.musclesTargeted),
                entry.type,
                entry.difficulty,
                entry.repRange,
                entry.youtubeURL,
                entry.imageURL,
                field(entry.proTips),
                field(entry.isCable),
                entry.pulley,
                String(entry.plannedSets),
                entry.notes,
                field(entry.isFavorite),
            ]))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Row-per-measurement.
    static func measurementsCSV(_ measurements: [Measurement]) -> String {
        var lines = [row([
            "measurement_id", "date", "weight", "body_fat_pct", "neck", "chest", "waist",
            "hips", "arms", "thighs", "shoulders",
        ])]

        for m in measurements {
            lines.append(row([
                m.id.uuidString,
                field(m.date),
                field(m.weight),
                field(m.bodyFatPct),
                field(m.neck),
                field(m.chest),
                field(m.waist),
                field(m.hips),
                field(m.arms),
                field(m.thighs),
                field(m.shoulders),
            ]))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Zip + temp-file writing (off-main-thread, mirrors DataArchiveBuilder)

    /// Writes 5 CSV files into a temp folder, zips them, returns the zip URL.
    /// Returns nil on failure so the caller degrades gracefully.
    @MainActor
    static func writeTempZip(_ appState: AppState) async -> URL? {
        let workoutHistory = workoutHistoryCSV(appState.workoutLogs)
        let programs = programsCSV(ProgramDatabase.shared.programs)
        let customWorkouts = customWorkoutsCSV(UserPlanDatabase.shared.plans)
        let customExercises = customExercisesCSV(ExerciseDatabase.shared.entries)
        let measurements = measurementsCSV(appState.measurements)

        return await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            let epoch = Int(Date().timeIntervalSince1970)
            let folderURL = fm.temporaryDirectory.appendingPathComponent("AuraFitness-CSV-Export-\(epoch)", isDirectory: true)

            do {
                try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)

                let files: [(String, String)] = [
                    ("workout_history.csv", workoutHistory),
                    ("programs.csv", programs),
                    ("custom_workouts.csv", customWorkouts),
                    ("custom_exercises.csv", customExercises),
                    ("body_measurements.csv", measurements),
                ]
                for (name, contents) in files {
                    let fileURL = folderURL.appendingPathComponent(name)
                    try contents.data(using: .utf8)?.write(to: fileURL, options: .atomic)
                }
            } catch {
                return nil
            }

            // Stdlib-only zip: NSFileCoordinator's `.forUploading` option
            // transparently produces a single `.zip` of the directory when
            // coordinating a read of it — no third-party dependency needed.
            let zipURL = fm.temporaryDirectory.appendingPathComponent("AuraFitness-CSV-Export-\(epoch).zip")
            var coordinatorError: NSError?
            var resultURL: URL?

            let coordinator = NSFileCoordinator(filePresenter: nil)
            coordinator.coordinate(readingItemAt: folderURL, options: [.forUploading], error: &coordinatorError) { zippedURL in
                do {
                    // `zippedURL` is a short-lived temp file owned by the
                    // coordinator — it must be copied out before the closure
                    // returns, or it will be deleted.
                    if fm.fileExists(atPath: zipURL.path) {
                        try? fm.removeItem(at: zipURL)
                    }
                    try fm.copyItem(at: zippedURL, to: zipURL)
                    resultURL = zipURL
                } catch {
                    resultURL = nil
                }
            }

            try? fm.removeItem(at: folderURL)

            if coordinatorError != nil { return nil }
            return resultURL
        }.value
    }
}
