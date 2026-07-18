import Foundation
import Supabase

/// All table push/pull + the offline queue + first-login migration.
/// Fire-and-forget from the stores' perspective — never throws into the UI,
/// never blocks a mutation. Mirrors the `@MainActor final class ... :
/// ObservableObject` + `static let shared` shape used by `ProgramDatabase` /
/// `ExerciseDatabase`.
@MainActor
final class SupabaseSyncService: ObservableObject {
    static let shared = SupabaseSyncService()

    enum Table: String, CaseIterable {
        case workoutLogs      = "aura_workout_logs"
        case measurements     = "aura_measurements"
        case personalRecords  = "aura_personal_records"
        case progressPhotos   = "aura_progress_photos"
        case programs         = "aura_programs"
        case plans            = "aura_plans"
        case exercises        = "aura_exercises"
        case dayOverrides     = "aura_day_overrides"
        case quickLogs        = "aura_quick_logs"
        case bodyStats        = "aura_body_stats"
        case userProfile      = "aura_user_profile"
        case preferences      = "aura_preferences"

        /// Keyed-by-ISO-date tables use `day_iso` as their row key column
        /// instead of `id`, and have no uuid primary key of their own.
        var isDayKeyed: Bool { self == .dayOverrides || self == .quickLogs }
        /// Singleton tables use `user_id` itself as the primary key.
        var isSingleton: Bool { self == .bodyStats || self == .userProfile || self == .preferences }
    }

    @Published private(set) var syncing = false
    @Published private(set) var lastPullAt: Date? = nil

    private let client: SupabaseClient
    private var userID: String? { AuthService.shared.userID }

    // MARK: - Offline queue

    private enum QueueAction: String, Codable { case upsert, delete }
    private struct QueueOp: Codable {
        var table: String
        var rowID: String
        var action: QueueAction
        var payloadJSON: String?   // base64-of-JSON-string; nil for deletes
        var queuedAt: Date
    }
    private let queueKey = "aura_sync_queue_v1"
    private let localTsKey = "aura_local_ts_v1"

    private init() {
        client = AuthService.shared.client
    }

    // MARK: - Local mutation timestamps (drives LWW when reconciling)

    /// Stamp "this row changed locally at time X" so `pullAll` can compare
    /// against the remote `updated_at` even though most local models don't
    /// carry their own timestamp field.
    func stampLocalChange(table: Table, id: String, at date: Date = Date()) {
        var map = loadLocalTsMap()
        map["\(table.rawValue):\(id)"] = date
        saveLocalTsMap(map)
    }

    private func loadLocalTsMap() -> [String: Date] {
        guard let data = UserDefaults.standard.data(forKey: localTsKey),
              let decoded = try? JSONDecoder().decode([String: Date].self, from: data) else { return [:] }
        return decoded
    }
    private func saveLocalTsMap(_ map: [String: Date]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: localTsKey)
    }

    // MARK: - Push (write-through, fire-and-forget)

    /// Enqueue a write-through upsert of one encodable row. Never throws into
    /// the caller; failures/offline silently enqueue to the durable queue.
    func push<T: Encodable>(_ value: T, id: String, table: Table) {
        guard let uid = userID else { return }
        stampLocalChange(table: table, id: id)
        guard let payloadData = try? JSONEncoder().encode(value),
              let payloadJSON = String(data: payloadData, encoding: .utf8) else { return }

        Task {
            do {
                try await upsertRemote(table: table, uid: uid, rowID: id, payloadJSON: payloadJSON)
                await flushQueue()
            } catch {
                enqueue(QueueOp(table: table.rawValue, rowID: id, action: .upsert,
                                 payloadJSON: payloadJSON, queuedAt: Date()))
            }
        }
    }

    /// Enqueue a delete of one row by id.
    func delete(id: String, table: Table) {
        guard let uid = userID else { return }
        Task {
            do {
                try await deleteRemote(table: table, uid: uid, rowID: id)
                await flushQueue()
            } catch {
                enqueue(QueueOp(table: table.rawValue, rowID: id, action: .delete,
                                 payloadJSON: nil, queuedAt: Date()))
            }
        }
    }

    private func upsertRemote(table: Table, uid: String, rowID: String, payloadJSON: String) async throws {
        struct RowUpsert: Encodable {
            let id: String?
            let user_id: String
            let day_iso: String?
            let payload: AnyJSON
        }
        let payloadValue = try JSONDecoder().decode(AnyJSON.self, from: Data(payloadJSON.utf8))

        if table.isSingleton {
            let row = RowUpsert(id: nil, user_id: uid, day_iso: nil, payload: payloadValue)
            _ = try await client.from(table.rawValue).upsert(row, onConflict: "user_id").execute()
        } else if table.isDayKeyed {
            let row = RowUpsert(id: nil, user_id: uid, day_iso: rowID, payload: payloadValue)
            _ = try await client.from(table.rawValue).upsert(row, onConflict: "user_id,day_iso").execute()
        } else {
            let row = RowUpsert(id: rowID, user_id: uid, day_iso: nil, payload: payloadValue)
            _ = try await client.from(table.rawValue).upsert(row, onConflict: "id").execute()
        }
    }

    private func deleteRemote(table: Table, uid: String, rowID: String) async throws {
        if table.isSingleton {
            _ = try await client.from(table.rawValue).delete().eq("user_id", value: uid).execute()
        } else if table.isDayKeyed {
            _ = try await client.from(table.rawValue).delete()
                .eq("user_id", value: uid).eq("day_iso", value: rowID).execute()
        } else {
            _ = try await client.from(table.rawValue).delete()
                .eq("user_id", value: uid).eq("id", value: rowID).execute()
        }
    }

    // MARK: - Queue durability

    private func enqueue(_ op: QueueOp) {
        var queue = loadQueue()
        // Coalesce duplicate (table,id) upserts — keep latest.
        queue.removeAll { $0.table == op.table && $0.rowID == op.rowID && $0.action == op.action }
        queue.append(op)
        saveQueue(queue)
    }

    private func loadQueue() -> [QueueOp] {
        guard let data = UserDefaults.standard.data(forKey: queueKey),
              let decoded = try? JSONDecoder().decode([QueueOp].self, from: data) else { return [] }
        return decoded
    }
    private func saveQueue(_ queue: [QueueOp]) {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        UserDefaults.standard.set(data, forKey: queueKey)
    }

    /// Flush the durable offline queue. Called after any successful net op
    /// (login, foreground pull, successful push).
    func flushQueue() async {
        guard let uid = userID else { return }
        var queue = loadQueue()
        guard !queue.isEmpty else { return }

        var remaining: [QueueOp] = []
        for op in queue {
            guard let table = Table(rawValue: op.table) else { continue }
            do {
                switch op.action {
                case .upsert:
                    guard let payloadJSON = op.payloadJSON else { continue }
                    try await upsertRemote(table: table, uid: uid, rowID: op.rowID, payloadJSON: payloadJSON)
                case .delete:
                    try await deleteRemote(table: table, uid: uid, rowID: op.rowID)
                }
            } catch {
                remaining.append(op)
            }
        }
        queue = remaining
        saveQueue(queue)
    }

    // MARK: - First-login backfill vs pull (R4)

    /// Called by AuthService on first sign-in this session. Detects an empty
    /// remote (fresh account) -> backfills all local data up. Otherwise runs
    /// `pullAll()` reconcile (which still merges any local-only rows up via
    /// LWW), so pre-account local data survives either way.
    func onSignedIn(userID: String) async {
        syncing = true
        defer { syncing = false }

        let remoteIsEmpty = await isRemoteEmpty(uid: userID)
        let localIsNonEmpty = hasAnyLocalData()

        if remoteIsEmpty && localIsNonEmpty {
            await backfillLocalToRemote(uid: userID)
        } else {
            await pullAll()
        }
        await flushQueue()
    }

    private func isRemoteEmpty(uid: String) async -> Bool {
        for table in Table.allCases {
            do {
                let response = try await client.from(table.rawValue)
                    .select("user_id", head: false, count: .exact)
                    .eq("user_id", value: uid)
                    .limit(1)
                    .execute()
                if (response.count ?? 0) > 0 { return false }
            } catch {
                // If a table can't be reached, don't assume it's empty —
                // fall through to pull/reconcile rather than risk clobbering
                // real remote data with a backfill.
                return false
            }
        }
        return true
    }

    private func hasAnyLocalData() -> Bool {
        !ProgramDatabase.shared.custom.isEmpty ||
        !UserPlanDatabase.shared.plans.isEmpty ||
        !ExerciseDatabase.shared.customEntries.isEmpty ||
        AppStateBridge.hasAnyUserData()
    }

    /// Push every local row up, stamping `updated_at = now()` server-side
    /// (the `set_updated_at` trigger does this on every write).
    private func backfillLocalToRemote(uid: String) async {
        guard let appState = AppStateBridge.shared else { return }

        for program in ProgramDatabase.shared.custom {
            push(program, id: program.id.uuidString, table: .programs)
        }
        for plan in UserPlanDatabase.shared.plans {
            push(plan, id: plan.id.uuidString, table: .plans)
        }
        for entry in ExerciseDatabase.shared.customEntries {
            push(entry, id: entry.id.uuidString, table: .exercises)
        }
        for log in appState.workoutLogs {
            push(log, id: log.id.uuidString, table: .workoutLogs)
        }
        for measurement in appState.measurements {
            push(measurement, id: measurement.id.uuidString, table: .measurements)
        }
        for pr in appState.personalRecords {
            push(pr, id: pr.id.uuidString, table: .personalRecords)
        }
        for photo in appState.progressPhotos {
            push(photo, id: photo.id.uuidString, table: .progressPhotos)
        }
        for (iso, ov) in appState.dayOverrides {
            push(ov, id: iso, table: .dayOverrides)
        }
        for (iso, ql) in appState.quickLogs {
            push(ql, id: iso, table: .quickLogs)
        }
        push(appState.bodyStats, id: uid, table: .bodyStats)
        push(appState.userProfile, id: uid, table: .userProfile)
        push(appState.currentPrefsBlob(), id: uid, table: .preferences)
    }

    // MARK: - Pull + reconcile (LWW by updated_at)

    private struct RemoteRow: Decodable {
        let id: String?
        let day_iso: String?
        let user_id: String
        let payload: AnyJSON
        let updated_at: Date
    }

    /// Pulls every table for the current user and reconciles into local
    /// stores using last-write-wins by `updated_at` (row-level). Local
    /// rows with a newer `aura_local_ts_v1` stamp than the remote row win and
    /// get pushed back up; otherwise the remote row wins and is applied
    /// locally (guarded against re-push via `isApplyingRemote`).
    func pullAll() async {
        guard let uid = userID else { return }
        syncing = true
        defer { syncing = false; lastPullAt = Date() }

        async let programsRows = fetchRows(.programs, uid: uid)
        async let plansRows = fetchRows(.plans, uid: uid)
        async let exercisesRows = fetchRows(.exercises, uid: uid)
        async let workoutLogRows = fetchRows(.workoutLogs, uid: uid)
        async let measurementRows = fetchRows(.measurements, uid: uid)
        async let prRows = fetchRows(.personalRecords, uid: uid)
        async let photoRows = fetchRows(.progressPhotos, uid: uid)
        async let dayOverrideRows = fetchRows(.dayOverrides, uid: uid)
        async let quickLogRows = fetchRows(.quickLogs, uid: uid)
        async let bodyStatsRows = fetchRows(.bodyStats, uid: uid)
        async let userProfileRows = fetchRows(.userProfile, uid: uid)
        async let prefsRows = fetchRows(.preferences, uid: uid)

        let (programs, plans, exercises, logs, measurements, prs, photos, overrides, quicks, bodyStats, profile, prefs) =
            await (programsRows, plansRows, exercisesRows, workoutLogRows, measurementRows, prRows, photoRows,
                   dayOverrideRows, quickLogRows, bodyStatsRows, userProfileRows, prefsRows)

        reconcile(rows: programs, table: .programs, idOf: { (p: Program) in p.id.uuidString },
                  localLookup: { id in ProgramDatabase.shared.programs.first { $0.id.uuidString == id } })
            .map { ProgramDatabase.shared.applyRemote($0) }
        reconcile(rows: plans, table: .plans, idOf: { (p: UserPlan) in p.id.uuidString },
                  localLookup: { id in UserPlanDatabase.shared.plans.first { $0.id.uuidString == id } })
            .map { UserPlanDatabase.shared.applyRemote($0) }
        reconcile(rows: exercises, table: .exercises, idOf: { (e: ExerciseEntry) in e.id.uuidString },
                  localLookup: { id in ExerciseDatabase.shared.entries.first { $0.id.uuidString == id } })
            .map { ExerciseDatabase.shared.applyRemote($0) }

        guard let appState = AppStateBridge.shared else { return }

        reconcile(rows: logs, table: .workoutLogs, idOf: { (l: WorkoutLog) in l.id.uuidString },
                  localLookup: { id in appState.workoutLogs.first { $0.id.uuidString == id } })
            .map { appState.applyRemoteWorkoutLogs($0) }
        reconcile(rows: measurements, table: .measurements, idOf: { (m: Measurement) in m.id.uuidString },
                  localLookup: { id in appState.measurements.first { $0.id.uuidString == id } })
            .map { appState.applyRemoteMeasurements($0) }
        reconcile(rows: prs, table: .personalRecords, idOf: { (p: PersonalRecord) in p.id.uuidString },
                  localLookup: { id in appState.personalRecords.first { $0.id.uuidString == id } })
            .map { appState.applyRemotePersonalRecords($0) }
        reconcile(rows: photos, table: .progressPhotos, idOf: { (p: ProgressPhoto) in p.id.uuidString },
                  localLookup: { id in appState.progressPhotos.first { $0.id.uuidString == id } })
            .map { appState.applyRemoteProgressPhotos($0) }

        reconcileKeyed(rows: overrides, table: .dayOverrides,
                       localLookup: { key in appState.dayOverrides[key] })
            .map { appState.applyRemoteDayOverrides($0) }
        reconcileKeyed(rows: quicks, table: .quickLogs,
                       localLookup: { key in appState.quickLogs[key] })
            .map { appState.applyRemoteQuickLogs($0) }

        if let row = bodyStats.first, let decoded: BodyStats = decode(row.payload) {
            appState.applyRemoteBodyStats(decoded)
        }
        if let row = userProfile.first, let decoded: UserProfile = decode(row.payload) {
            appState.applyRemoteUserProfile(decoded)
        }
        if let row = prefs.first, let decoded: AppState.RemotePrefs = decode(row.payload) {
            appState.applyRemotePrefs(decoded)
        }
    }

    private func fetchRows(_ table: Table, uid: String) async -> [RemoteRow] {
        do {
            let response = try await client.from(table.rawValue)
                .select()
                .eq("user_id", value: uid)
                .execute()
            return try JSONDecoder().decode([RemoteRow].self, from: response.data)
        } catch {
            return []
        }
    }

    private func decode<T: Decodable>(_ json: AnyJSON) -> T? {
        guard let data = try? JSONEncoder().encode(json) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// Row-level LWW reconcile for uuid-keyed tables. Returns the merged
    /// array to apply locally, or nil if nothing changed (avoids a
    /// no-op re-persist storm).
    ///
    /// - Local rows newer than the pulled remote snapshot (per
    ///   `aura_local_ts_v1`) WIN: the remote row is skipped for that id and,
    ///   since the local value is the winner, it gets re-pushed up so the
    ///   server converges on it too (`localLookup` supplies the current
    ///   local value for that id so we have something to push).
    /// - Remote rows newer than (or with no recorded local edit for) that id
    ///   win and are applied locally; the local timestamp map is re-stamped
    ///   to the remote row's `updated_at` so a subsequent reconcile doesn't
    ///   misjudge this id as a fresh unstamped local edit.
    private func reconcile<T: Codable>(rows: [RemoteRow], table: Table, idOf: (T) -> String, localLookup: (String) -> T?) -> [T]? {
        guard !rows.isEmpty else { return nil }
        var localTsMap = loadLocalTsMap()
        var merged: [String: T] = [:]

        for row in rows {
            guard let id = row.id, let decoded: T = decode(row.payload) else { continue }
            let localTs = localTsMap["\(table.rawValue):\(id)"]
            if let localTs, localTs > row.updated_at {
                // Local edit happened after this remote snapshot — local
                // wins. Re-push the local value so the server converges;
                // don't touch the local timestamp (it already reflects the
                // more-recent local edit).
                if let localValue = localLookup(id) {
                    push(localValue, id: id, table: table)
                }
                continue
            }
            // Remote wins (or no local edit on record for this id) — apply
            // locally and re-stamp so the timestamp map matches disk.
            merged[id] = decoded
            localTsMap["\(table.rawValue):\(id)"] = row.updated_at
        }
        saveLocalTsMap(localTsMap)
        return merged.isEmpty ? nil : Array(merged.values)
    }

    private func reconcileKeyed<T: Codable>(rows: [RemoteRow], table: Table, localLookup: (String) -> T?) -> [String: T]? {
        guard !rows.isEmpty else { return nil }
        var localTsMap = loadLocalTsMap()
        var merged: [String: T] = [:]
        for row in rows {
            guard let key = row.day_iso, let decoded: T = decode(row.payload) else { continue }
            let localTs = localTsMap["\(table.rawValue):\(key)"]
            if let localTs, localTs > row.updated_at {
                if let localValue = localLookup(key) {
                    push(localValue, id: key, table: table)
                }
                continue
            }
            merged[key] = decoded
            localTsMap["\(table.rawValue):\(key)"] = row.updated_at
        }
        saveLocalTsMap(localTsMap)
        return merged.isEmpty ? nil : merged
    }

    // MARK: - Reset support (DataResetService)

    /// Deletes every row in `table` for the current user (or enqueues the
    /// delete if offline). Used by `DataResetService.resetAll(alsoRemote:)`.
    func wipeRemote(tables: [Table]) {
        guard let uid = userID else { return }
        Task {
            for table in tables {
                do {
                    _ = try await client.from(table.rawValue).delete().eq("user_id", value: uid).execute()
                } catch {
                    // Best-effort: wipe failures are not queued individually
                    // (there's no single row id to key on) — a subsequent
                    // successful pull/push cycle will not resurrect wiped
                    // local data since the local store was already cleared.
                }
            }
        }
    }
}

/// Small namespace bridging `AppState`'s collections into this file without
/// creating a circular import — `AppState` itself implements these methods
/// (see AppState.swift H8 additions); this indirection just gives
/// `SupabaseSyncService` a single `shared`-style handle without holding a
/// second `@StateObject` copy.
enum AppStateBridge {
    /// Set synchronously in `AuraFitnessApp.init()` — BEFORE `AuthService.shared`
    /// is ever touched — so `AuthService.restoreSession()`'s `onSignedIn` ->
    /// `pullAll`/backfill call chain never runs against a nil bridge on cold
    /// launch (see `AuraFitnessApp.init()` for the ordering guarantee).
    static weak var shared: AppState?

    static func hasAnyUserData() -> Bool {
        guard let s = shared else { return false }
        return !s.workoutLogs.isEmpty || !s.measurements.isEmpty || !s.personalRecords.isEmpty
            || !s.progressPhotos.isEmpty || !s.dayOverrides.isEmpty || !s.quickLogs.isEmpty
    }
}
