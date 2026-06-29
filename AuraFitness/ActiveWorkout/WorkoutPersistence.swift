import Foundation
import CoreGraphics

/// Mirrors app.jsx localStorage persistence: `aura_wk` (the live workout),
/// `aura_elapsed` (workout seconds), `aura_pill` (rest-pill position) — plus the
/// schema-gated restore that clears stale blobs on a `version` mismatch.
enum WorkoutPersistence {
    private enum Keys {
        static let workout = "aura_wk"
        static let elapsed = "aura_elapsed"
        static let pill    = "aura_pill"
        static let version = "aura_wk_version"
    }

    // MARK: - Restore

    /// Per-exercise slice we persist & restore (matches the JSX restore: sets,
    /// completed, note, pulley — matched by exercise `name` at the same index).
    private struct SavedExercise: Codable {
        var name: String
        var sets: [WorkoutSet]
        var completed: Bool
        var note: String
        var pulley: String
    }
    private struct SavedWorkout: Codable {
        var version: Int
        var exercises: [SavedExercise]
    }

    /// Apply a schema-compatible saved blob onto a fresh seed (in place). On a
    /// version mismatch the key is cleared and the seed is left untouched.
    static func restore(into workout: inout Workout) {
        let d = UserDefaults.standard
        guard let data = d.data(forKey: Keys.workout),
              let saved = try? JSONDecoder().decode(SavedWorkout.self, from: data)
        else { return }

        guard saved.version == ActiveWorkoutSeed.version else {
            clearWorkout()
            return
        }

        for i in workout.exercises.indices {
            guard i < saved.exercises.count,
                  saved.exercises[i].name == workout.exercises[i].name else { continue }
            let sv = saved.exercises[i]
            workout.exercises[i].sets = sv.sets
            workout.exercises[i].completed = sv.completed
            workout.exercises[i].note = sv.note
            workout.exercises[i].pulley = sv.pulley
        }
    }

    static func restoredElapsed(default fallback: Int) -> Int {
        let d = UserDefaults.standard
        guard d.object(forKey: Keys.elapsed) != nil else { return fallback }
        return d.integer(forKey: Keys.elapsed)
    }

    static func restoredPill(default fallback: CGPoint) -> CGPoint {
        let d = UserDefaults.standard
        guard let arr = d.array(forKey: Keys.pill) as? [Double], arr.count == 2 else { return fallback }
        return CGPoint(x: arr[0], y: arr[1])
    }

    // MARK: - Persist

    static func saveWorkout(_ workout: Workout) {
        let saved = SavedWorkout(
            version: ActiveWorkoutSeed.version,
            exercises: workout.exercises.map {
                SavedExercise(name: $0.name, sets: $0.sets,
                              completed: $0.completed, note: $0.note, pulley: $0.pulley)
            }
        )
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Keys.workout)
        }
    }

    static func saveElapsed(_ seconds: Int) {
        UserDefaults.standard.set(seconds, forKey: Keys.elapsed)
    }

    static func savePill(_ p: CGPoint) {
        UserDefaults.standard.set([Double(p.x), Double(p.y)], forKey: Keys.pill)
    }

    // MARK: - Reset (resetAll: clears aura_wk + aura_elapsed)

    static func clearWorkout() {
        let d = UserDefaults.standard
        d.removeObject(forKey: Keys.workout)
        d.removeObject(forKey: Keys.elapsed)
    }
}
