import Foundation

/// Real `resetAll(workoutOnly:)` — clears the exact UserDefaults key set
/// enumerated in the H8 spec, reassigns in-memory singleton/`@Published`
/// state (clearing a key does NOT update memory), and optionally wipes the
/// matching remote Supabase tables. Delete Account does NOT use the
/// `alsoRemote` path — that relies on the Edge Function's `on delete cascade`.
enum DataResetService {

    @MainActor
    static func resetAll(workoutOnly: Bool, appState: AppState, alsoRemote: Bool) {
        // Tear down any live session first so no stale session re-persists
        // post-wipe (spec edge case: "Reset while a workout is live").
        appState.exitWorkout()
        WorkoutPersistence.clearWorkout()
        UserDefaults.standard.removeObject(forKey: "aura_pill")
        UserDefaults.standard.removeObject(forKey: "aura_wk_version")

        // MARK: Workout-data keys (both modes)
        UserDefaults.standard.removeObject(forKey: "aura_program_db_v1")
        UserDefaults.standard.removeObject(forKey: "aura_plans_db_v1")
        UserDefaults.standard.removeObject(forKey: "aura_workout_logs_v1")
        UserDefaults.standard.removeObject(forKey: "aura_day_overrides_v1")
        UserDefaults.standard.removeObject(forKey: "aura_quick_logs_v1")
        UserDefaults.standard.removeObject(forKey: "aura_personal_records_v1")
        UserDefaults.standard.removeObject(forKey: "aura_exercise_db_v1")

        // Reload the singleton stores from the now-cleared keys. Full reset
        // ("Reset everything" / Delete Account) drops ALL programs/exercises
        // including user-created customs — hardReset(); workout-data-only
        // reset preserves customs — resetToSeed(). (UserPlanDatabase has no
        // custom/predefined distinction of its own; its plans always derive
        // from programs, so resetToSeed() re-seeding the default plan is
        // correct for both modes.)
        if workoutOnly {
            ProgramDatabase.shared.resetToSeed()
            ExerciseDatabase.shared.resetToSeed()
        } else {
            ProgramDatabase.shared.hardReset()
            ExerciseDatabase.shared.hardReset()
        }
        UserPlanDatabase.shared.resetToSeed()

        // Actually REPLACE in-memory state (not the union-merge
        // `applyRemote*` pull-reconcile helpers — passing `[]`/`[:]` there
        // is a no-op since they merge over existing state).
        appState.clearWorkoutLogs()
        appState.clearDayOverrides()
        appState.clearQuickLogs()
        appState.clearPersonalRecords()

        var remoteTables: [SupabaseSyncService.Table] = [
            .programs, .plans, .exercises, .workoutLogs, .dayOverrides, .quickLogs, .personalRecords,
        ]

        if !workoutOnly {
            // MARK: Profile / measurement / settings keys (full reset only)
            UserDefaults.standard.removeObject(forKey: "aura_measurements_v1")
            UserDefaults.standard.removeObject(forKey: "aura_body_stats_v1")
            UserDefaults.standard.removeObject(forKey: "aura_user_profile_v1")
            UserDefaults.standard.removeObject(forKey: "aura_progress_photos_v1")
            UserDefaults.standard.removeObject(forKey: "aura_workout_prefs_v1")
            UserDefaults.standard.removeObject(forKey: "aura_dark")
            UserDefaults.standard.removeObject(forKey: "aura_calstart")
            UserDefaults.standard.removeObject(forKey: "aura_logstat")
            UserDefaults.standard.removeObject(forKey: "aura_seeded_missed_v1") // dead key, opportunistic cleanup

            appState.clearMeasurements()
            appState.resetBodyStats()
            appState.resetUserProfile()
            appState.clearProgressPhotos()
            appState.resetPrefs()

            remoteTables += [.measurements, .bodyStats, .userProfile, .progressPhotos, .preferences]

            // New sync-infra keys cleared on full reset only.
            UserDefaults.standard.removeObject(forKey: "aura_sync_queue_v1")
            UserDefaults.standard.removeObject(forKey: "aura_local_ts_v1")
            // Reset the delta-pull watermark too, so a post-reset sync re-pulls
            // from epoch rather than skipping rows behind a stale cursor.
            SupabaseSyncService.shared.resetSyncState()

            // Guest-mode flag — full reset also drops guest status so a
            // post-reset relaunch shows the login screen, not a silent guest
            // session. NOT removed in the workout-only branch.
            UserDefaults.standard.removeObject(forKey: "aura_guest_mode_v1")
        }

        if alsoRemote {
            SupabaseSyncService.shared.wipeRemote(tables: remoteTables)
        }
    }
}
