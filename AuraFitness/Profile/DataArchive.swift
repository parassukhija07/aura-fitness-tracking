import Foundation

/// Full local export snapshot — reads LOCAL stores (the source of truth for
/// all UI), so export needs no network. Aggregates every user model + a
/// preferences snapshot into one Codable archive for `ShareLink`.
struct DataArchive: Codable {
    var exportedAt: Date
    var programs: [Program]
    var plans: [UserPlan]
    var exercises: [ExerciseEntry]
    var workoutLogs: [WorkoutLog]
    var dayOverrides: [String: DayOverride]
    var quickLogs: [String: QuickLog]
    var measurements: [Measurement]
    var bodyStats: BodyStats
    var personalRecords: [PersonalRecord]
    var userProfile: UserProfile
    var progressPhotos: [ProgressPhoto]
    var preferences: AppState.RemotePrefs
}

enum DataArchiveBuilder {
    /// Builds the archive from current local stores + AppState and writes it
    /// to a temp JSON file for `ShareLink`. Runs the (potentially large,
    /// photo-heavy — see O2) encode off the main thread; returns nil on
    /// failure so the caller can degrade gracefully instead of crashing.
    @MainActor
    static func writeTempFile(_ appState: AppState) async -> URL? {
        let archive = DataArchive(
            exportedAt: Date(),
            programs: ProgramDatabase.shared.programs,
            plans: UserPlanDatabase.shared.plans,
            exercises: ExerciseDatabase.shared.entries,
            workoutLogs: appState.workoutLogs,
            dayOverrides: appState.dayOverrides,
            quickLogs: appState.quickLogs,
            measurements: appState.measurements,
            bodyStats: appState.bodyStats,
            personalRecords: appState.personalRecords,
            userProfile: appState.userProfile,
            progressPhotos: appState.progressPhotos,
            preferences: appState.currentPrefsBlob()
        )

        return await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted]
            guard let data = try? encoder.encode(archive) else { return nil }

            let filename = "AuraFitness-Export-\(Int(Date().timeIntervalSince1970)).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }.value
    }
}
