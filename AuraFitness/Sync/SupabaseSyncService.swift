import Foundation
import Supabase

/// ISO-8601 parsing/formatting for the sync layer's server timestamps.
///
/// Lives at FILE scope, deliberately outside `SupabaseSyncService`. Inside a
/// `@MainActor` class these statics are MainActor-isolated, but the one caller
/// that matters — `deltaDecoder`'s `.custom` date strategy — is a nonisolated
/// closure the decoder invokes on whatever thread it likes. That mismatch is
/// the "call to main actor-isolated static method 'parseTimestamp' in a
/// synchronous nonisolated context" warning: benign in Swift 5 language mode,
/// a hard error in Swift 6.
///
/// `nonisolated(unsafe)` is accurate rather than a silencer: `ISO8601DateFormatter`
/// is documented as thread-safe for concurrent formatting and parsing, and
/// neither instance is ever mutated after its initialiser runs. Sharing them is
/// the point — building a formatter per row would be far more expensive than
/// the parse itself on a full pull.
private enum SyncTimestamp {
    /// Supabase emits fractional seconds (2026-07-18T10:00:00.123Z); PostgREST
    /// sometimes omits them (2026-07-18T10:00:00+00:00). Try the richer format
    /// first, then fall back — a single formatter cannot accept both.
    nonisolated(unsafe) static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    nonisolated(unsafe) static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String) -> Date? {
        isoFractional.date(from: s) ?? isoPlain.date(from: s)
    }

    /// Used for the `since` argument of the `pull_changes` RPC.
    static func string(from date: Date) -> String {
        isoFractional.string(from: date)
    }
}

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

    // MARK: - Delta-pull watermark

    /// Incremental-sync cursor: `pullChanges()` fetches only rows whose server
    /// `updated_at` is strictly greater than this. Persisted (as epoch seconds)
    /// so a relaunch resumes the delta instead of re-pulling everything.
    /// Advanced ONLY to the max server `updated_at` actually merged — never the
    /// client clock — to avoid clock-skew gaps. Epoch 0 (key absent) means
    /// "pull everything" (fresh install / post-reset / first sign-in).
    private let lastDeltaPullKey = "aura_sync_last_delta_pull_v1"
    private var lastDeltaPullAt: Date {
        get {
            let secs = UserDefaults.standard.double(forKey: lastDeltaPullKey)
            return Date(timeIntervalSince1970: secs) // absent -> 0.0 -> 1970 (pull all)
        }
        set { UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: lastDeltaPullKey) }
    }

    /// Clears the delta watermark so the next `pullChanges()` re-pulls from
    /// epoch. Called on sign-out and full data reset (state the service should
    /// forget). Kept here (not inlined at the call sites) so the persisted key
    /// name stays owned by this file.
    func resetSyncState() {
        UserDefaults.standard.removeObject(forKey: lastDeltaPullKey)
    }

    // MARK: - Delta timestamp coding
    //
    // The `pull_changes` RPC emits `updated_at` as an ISO-8601 UTC string
    // (YYYY-MM-DDTHH:MM:SS.mmmZ — see 0002_pull_changes_rpc.sql), NOT the
    // numeric reference-date the default `JSONDecoder` strategy expects, so the
    // delta response needs a decoder with an explicit ISO strategy. Row
    // *payloads* are still decoded by `decode(_:)` with default coders (they
    // were pushed with default coders, so their dates are numeric) — this
    // decoder only ever touches the top-level `updated_at`.
    private static let deltaDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let raw = try container.decode(String.self)
            guard let date = SyncTimestamp.parse(raw) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Unparseable RPC timestamp: \(raw)")
            }
            return date
        }
        return decoder
    }()

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
    ///
    /// `stampLocalChange` runs BEFORE the `userID` guard so guest-mode edits
    /// (no network push, `userID == nil`) are still timestamped locally. This
    /// is load-bearing for guest -> sign-in migration: `pullAll`'s LWW
    /// reconcile compares this local stamp against the remote row's
    /// `updated_at` to decide whether a guest edit should win over an older
    /// pre-existing cloud row. Without stamping while `uid` is nil, guest
    /// edits would never carry a timestamp and could be silently overwritten
    /// by older remote data on first sign-in.
    func push<T: Encodable>(_ value: T, id: String, table: Table) {
        stampLocalChange(table: table, id: id)
        guard let uid = userID else { return }
        guard let payloadData = try? JSONEncoder().encode(value),
              let payloadJSON = String(data: payloadData, encoding: .utf8) else { return }

        Task {
            do {
                try await upsertRemote(table: table, uid: uid, rowID: id, payloadJSON: payloadJSON)
                await flushQueue()
            } catch {
                // A payload the server will never accept (0005 guardrails)
                // must not be queued — it would fail on every flush forever.
                guard !Self.isPermanentWriteFailure(error) else {
                    Self.logDroppedWrite(table: table.rawValue, rowID: id, error: error)
                    return
                }
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

    /// Plain hard delete — no tombstone bookkeeping here on purpose. The
    /// `after delete` trigger from 0003_deletions_tombstones.sql records the
    /// `aura_deletions` row server-side, so deletes that never pass through
    /// this method (Dashboard, edge functions, `wipeRemote`) are tombstoned too.
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
                // Retryable (offline, 5xx, timeout) stays queued; permanently
                // rejected payloads are dropped so one bad row can't wedge the
                // queue and block every op behind it.
                if Self.isPermanentWriteFailure(error) {
                    Self.logDroppedWrite(table: op.table, rowID: op.rowID, error: error)
                } else {
                    remaining.append(op)
                }
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

        // Before any push path runs: queues every photo whose bytes are still
        // inline, so the pushes below withhold those rows until Storage has
        // them (phase3-01). Also the resume point for a migration a previous
        // launch left half-finished.
        ProgressPhotoStorage.shared.resumePendingUploads()

        let remoteIsEmpty = await isRemoteEmpty(uid: userID)
        let localIsNonEmpty = hasAnyLocalData()

        if remoteIsEmpty && localIsNonEmpty {
            await backfillLocalToRemote(uid: userID)
        } else {
            // First sign-in on this device has an epoch-0 watermark, so this
            // pulls everything (same as the old full pull) but via the single
            // delta RPC; later foregrounds fetch only what changed.
            await pullChanges()
        }
        await flushQueue()
        // After the queue drains, so the sweep can't race a queued upsert of
        // the very rows it is deleting.
        await cleanupPredefinedRemoteRows()
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
        // Photos still waiting on their Storage upload are skipped, not lost:
        // the upload completing strips the base64 and pushes the metadata row
        // itself. Backfilling them here would send the very blob phase3-01
        // exists to keep out of Postgres.
        for photo in appState.progressPhotos where !ProgressPhotoStorage.shared.isUploadPending(photo.id) {
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
        /// Optional: the REST full-pull (`fetchRows`) selects it, but the
        /// `pull_changes` RPC omits it (rows are already `auth.uid()`-scoped).
        /// It is never read by the reconcile logic either way.
        let user_id: String?
        let payload: AnyJSON
        let updated_at: Date
    }

    /// One tombstone from `aura_deletions` (0003_deletions_tombstones.sql):
    /// "row `row_key` of `table_name` was deleted at `deleted_at`". Carries no
    /// payload — there is nothing left to carry.
    private struct DeletionRow: Decodable {
        let table_name: String
        let row_key: String
        let deleted_at: Date
    }

    /// Decoded shape of the `pull_changes` RPC — one array per `aura_*` table.
    /// The RPC always emits all 12 keys (empty array when nothing changed), so
    /// every property is non-optional and decoding is total.
    ///
    /// `aura_deletions` is the one exception: it only exists from
    /// 0004_pull_changes_v2.sql onward, so it is Optional purely so a client
    /// talking to a database still on 0002 keeps decoding (nil = this server
    /// has no tombstone support) instead of failing every delta pull into the
    /// full-pull fallback forever.
    private struct PullChangesResponse: Decodable {
        let aura_workout_logs: [RemoteRow]
        let aura_measurements: [RemoteRow]
        let aura_personal_records: [RemoteRow]
        let aura_progress_photos: [RemoteRow]
        let aura_programs: [RemoteRow]
        let aura_plans: [RemoteRow]
        let aura_exercises: [RemoteRow]
        let aura_day_overrides: [RemoteRow]
        let aura_quick_logs: [RemoteRow]
        let aura_body_stats: [RemoteRow]
        let aura_user_profile: [RemoteRow]
        let aura_preferences: [RemoteRow]
        let aura_deletions: [DeletionRow]?
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

        mergeRemoteRows(programs: programs, plans: plans, exercises: exercises,
                        logs: logs, measurements: measurements, prs: prs,
                        photos: photos, overrides: overrides, quicks: quicks,
                        bodyStats: bodyStats, profile: profile, prefs: prefs)
    }

    // MARK: - Incremental pull (delta RPC, with full-pull fallback)

    /// One-request incremental sync: calls the `pull_changes(since)` RPC with
    /// the persisted watermark and routes every returned row through the SAME
    /// per-table LWW merge `pullAll()` uses (`mergeRemoteRows`). The watermark
    /// advances to the max server `updated_at` merged, and ONLY after a fully
    /// successful merge (empty delta leaves it untouched — never regress it).
    ///
    /// Deletions ride along in the same response as `aura_deletions`
    /// tombstones and are applied FIRST, before any per-table merge, with the
    /// keys they removed handed to the merge so its local-only re-push can't
    /// push a just-deleted row straight back up. See `applyDeletions`.
    ///
    /// Fallback ladder (terminates — no retry loop): an auth failure (JWT
    /// expired / 401) is treated as signed-out and does nothing. Any other RPC
    /// or decode failure — notably a 404 (migration not applied yet) or a 400
    /// (bad `since`) — degrades to exactly one legacy full `pullAll()`. Note
    /// that the fallback CANNOT see tombstones (`pullAll` reads the tables
    /// directly, and a deleted row is simply absent) — deletions are missed
    /// for that cycle and picked up by the next successful delta pull.
    func pullChanges() async {
        guard userID != nil else { return }
        syncing = true
        defer { syncing = false; lastPullAt = Date() }

        let sinceISO = SyncTimestamp.string(from: lastDeltaPullAt)
        do {
            let response = try await client.rpc("pull_changes", params: ["since": sinceISO]).execute()
            let delta = try Self.deltaDecoder.decode(PullChangesResponse.self, from: response.data)
            let (tombstoned, maxDeletedAt) = applyDeletions(delta.aura_deletions ?? [])
            let maxTs = mergeRemoteRows(
                programs: delta.aura_programs, plans: delta.aura_plans, exercises: delta.aura_exercises,
                logs: delta.aura_workout_logs, measurements: delta.aura_measurements, prs: delta.aura_personal_records,
                photos: delta.aura_progress_photos, overrides: delta.aura_day_overrides, quicks: delta.aura_quick_logs,
                bodyStats: delta.aura_body_stats, profile: delta.aura_user_profile, prefs: delta.aura_preferences,
                skipRePush: tombstoned)
            // Advance only forward, and only if the response carried rows.
            // Tombstones count: they're filtered by `deleted_at > since` off
            // the same watermark, so leaving them out would re-deliver every
            // deletion on every pull until an unrelated row happened to change.
            if let maxTs = [maxTs, maxDeletedAt].compactMap({ $0 }).max(), maxTs > lastDeltaPullAt {
                lastDeltaPullAt = maxTs
            }
        } catch {
            // Signed-out: don't fall back, don't retry — pullAll would just 401
            // too and this call is fire-and-forget.
            guard !Self.isAuthError(error) else { return }
            // Migration-not-applied (404) / bad-since (400) / transient: one
            // full pull, then stop.
            await pullAll()
        }
    }

    /// Best-effort classification of an expired/missing-JWT failure. On these
    /// we must not fall back to a full pull (the user is effectively signed
    /// out). PostgREST/GoTrue don't expose a stable typed status here, so match
    /// the known message shapes.
    private static func isAuthError(_ error: Error) -> Bool {
        let text = "\(error)".lowercased()
        return text.contains("jwt") || text.contains("401")
            || text.contains("unauthorized") || text.contains("not authenticated")
    }

    // MARK: - Write failure classification (payload guardrails)

    /// True when re-sending this exact payload can only ever fail again, so
    /// the queued op must be DROPPED rather than retried forever. The headline
    /// case is `23514` — the CHECK constraints from 0005_payload_guardrails.sql
    /// (payload over its size cap, or not a JSON object).
    ///
    /// Deliberately an ALLOW-LIST of SQLSTATE codes: anything unrecognised —
    /// offline, timeout, 5xx, a code added by a future PostgREST — stays
    /// queued. Silently discarding a write is far worse than retrying one.
    /// Auth failures are explicitly excluded: a refreshed token fixes those,
    /// so they are transient no matter what else the message says.
    ///
    /// Matching on the error's text mirrors `isAuthError` above — the
    /// PostgREST/GoTrue errors this SDK surfaces don't expose a stable typed
    /// status to switch on.
    ///
    /// NOTE: only the remote queue op is dropped. The local store keeps the
    /// row and stays authoritative, so nothing the user created is lost — it
    /// just stops trying to reach Supabase until the payload is fixed.
    private static func isPermanentWriteFailure(_ error: Error) -> Bool {
        guard !isAuthError(error) else { return false }
        let text = "\(error)".lowercased()
        return text.contains("23514")   // check_violation — the payload guardrails
            || text.contains("23502")   // not_null_violation
            || text.contains("23503")   // foreign_key_violation — user row is gone
            || text.contains("22p02")   // invalid_text_representation
            || text.contains("22003")   // numeric_value_out_of_range
    }

    /// Surfaces a dropped write. Uses `print` to match the existing diagnostic
    /// style in this codebase (see ExerciseDatabase's seed-load warnings);
    /// there is no os_log convention here to follow yet.
    private static func logDroppedWrite(table: String, rowID: String, error: Error) {
        print("⚠️ SupabaseSyncService: permanently rejected write to \(table) row \(rowID) — dropping the queued op, local copy kept. \(error)")
    }

    /// Shared per-table LWW merge + local apply used by BOTH `pullAll()` (full
    /// snapshot) and `pullChanges()` (incremental delta). Takes the already-
    /// decoded rows per table, reconciles each into its local store, and
    /// returns the maximum `updated_at` seen across every row (nil when the
    /// batch is empty) so `pullChanges()` can advance its watermark.
    ///
    /// `skipRePush` holds the `"table:key"` stamps of rows a tombstone just
    /// removed this cycle. Those rows must never take the local-wins re-push
    /// branch below — that would recreate remotely exactly what was deleted.
    @discardableResult
    private func mergeRemoteRows(
        programs: [RemoteRow], plans: [RemoteRow], exercises: [RemoteRow],
        logs: [RemoteRow], measurements: [RemoteRow], prs: [RemoteRow],
        photos: [RemoteRow], overrides: [RemoteRow], quicks: [RemoteRow],
        bodyStats: [RemoteRow], profile: [RemoteRow], prefs: [RemoteRow],
        skipRePush: Set<String> = []
    ) -> Date? {
        // The `localLookup` closures for programs/exercises refuse non-syncable
        // values on purpose. `reconcile`'s local-wins branch pushes whatever
        // lookup returns, bypassing the stores' own `syncPush` ownership gate —
        // returning nil there is what stops a predefined program being
        // republished by the merge itself.
        reconcile(rows: programs, table: .programs, idOf: { (p: Program) in p.id.uuidString },
                  localLookup: { id in
                      ProgramDatabase.shared.programs.first { $0.id.uuidString == id && $0.isSyncable }
                  },
                  skipRePush: skipRePush)
            .map { ProgramDatabase.shared.applyRemote($0) }
        reconcile(rows: plans, table: .plans, idOf: { (p: UserPlan) in p.id.uuidString },
                  localLookup: { id in UserPlanDatabase.shared.plans.first { $0.id.uuidString == id } },
                  skipRePush: skipRePush)
            .map { UserPlanDatabase.shared.applyRemote($0) }
        reconcile(rows: exercises, table: .exercises, idOf: { (e: ExerciseEntry) in e.id.uuidString },
                  localLookup: { id in
                      ExerciseDatabase.shared.entries.first { $0.id.uuidString == id && $0.isSyncable }
                  },
                  skipRePush: skipRePush)
            .map { ExerciseDatabase.shared.applyRemote($0) }

        // Programs/plans/exercises apply above even without the AppState bridge
        // (they live in their own singletons); the rest need it. A nil bridge
        // skips only those applies — the watermark still advances off all rows.
        if let appState = AppStateBridge.shared {
            reconcile(rows: logs, table: .workoutLogs, idOf: { (l: WorkoutLog) in l.id.uuidString },
                      localLookup: { id in appState.workoutLogs.first { $0.id.uuidString == id } },
                      skipRePush: skipRePush)
                .map { appState.applyRemoteWorkoutLogs($0) }
            reconcile(rows: measurements, table: .measurements, idOf: { (m: Measurement) in m.id.uuidString },
                      localLookup: { id in appState.measurements.first { $0.id.uuidString == id } },
                      skipRePush: skipRePush)
                .map { appState.applyRemoteMeasurements($0) }
            reconcile(rows: prs, table: .personalRecords, idOf: { (p: PersonalRecord) in p.id.uuidString },
                      localLookup: { id in appState.personalRecords.first { $0.id.uuidString == id } },
                      skipRePush: skipRePush)
                .map { appState.applyRemotePersonalRecords($0) }
            // Same shape as the programs/exercises lookups above: returning nil
            // suppresses the local-wins re-push. A photo mid-upload has nothing
            // worth pushing yet — only its base64 — and the upload completing
            // pushes the metadata row itself.
            reconcile(rows: photos, table: .progressPhotos, idOf: { (p: ProgressPhoto) in p.id.uuidString },
                      localLookup: { id in
                          appState.progressPhotos.first {
                              $0.id.uuidString == id && !ProgressPhotoStorage.shared.isUploadPending($0.id)
                          }
                      },
                      skipRePush: skipRePush)
                .map { appState.applyRemoteProgressPhotos($0) }

            reconcileKeyed(rows: overrides, table: .dayOverrides,
                           localLookup: { key in appState.dayOverrides[key] },
                           skipRePush: skipRePush)
                .map { appState.applyRemoteDayOverrides($0) }
            reconcileKeyed(rows: quicks, table: .quickLogs,
                           localLookup: { key in appState.quickLogs[key] },
                           skipRePush: skipRePush)
                .map { appState.applyRemoteQuickLogs($0) }

            if let row = bodyStats.first, let decoded: BodyStats = decode(row.payload) {
                appState.applyRemoteBodyStats(decoded)
            }
            if let row = profile.first, let decoded: UserProfile = decode(row.payload) {
                appState.applyRemoteUserProfile(decoded)
            }
            if let row = prefs.first, let decoded: AppState.RemotePrefs = decode(row.payload) {
                appState.applyRemotePrefs(decoded)
            }
        }

        return [programs, plans, exercises, logs, measurements, prs,
                photos, overrides, quicks, bodyStats, profile, prefs]
            .flatMap { $0 }.map(\.updated_at).max()
    }

    /// Full-table REST read for one table, used only by the legacy `pullAll()`
    /// fallback.
    ///
    /// Uses `deltaDecoder`, NOT a bare `JSONDecoder`: PostgREST serialises
    /// `updated_at` as an ISO-8601 string ("2026-07-18T10:00:00.123456+00:00"),
    /// and the default `.deferredToDate` strategy expects a Double — so a bare
    /// decoder threw `typeMismatch` on EVERY row, the catch below turned that
    /// into `[]`, and `pullAll()` silently merged nothing at all. The RPC path
    /// never hit this because it always had the ISO-aware decoder.
    ///
    /// Row payloads are unaffected: they decode separately in `decode(_:)`
    /// with default coders, matching how they were encoded.
    private func fetchRows(_ table: Table, uid: String) async -> [RemoteRow] {
        do {
            let response = try await client.from(table.rawValue)
                .select()
                .eq("user_id", value: uid)
                .execute()
            return try Self.deltaDecoder.decode([RemoteRow].self, from: response.data)
        } catch {
            // Returning [] keeps the pull fire-and-forget, but an empty result
            // is indistinguishable from "no rows" — which is exactly how the
            // decoder bug above stayed invisible. Say so out loud.
            print("⚠️ SupabaseSyncService: full pull of \(table.rawValue) failed, treating as empty — \(error)")
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
    private func reconcile<T: Codable>(rows: [RemoteRow], table: Table, idOf: (T) -> String,
                                       localLookup: (String) -> T?,
                                       skipRePush: Set<String> = []) -> [T]? {
        guard !rows.isEmpty else { return nil }
        var localTsMap = loadLocalTsMap()
        var merged: [String: T] = [:]

        for row in rows {
            guard let id = row.id, let decoded: T = decode(row.payload) else { continue }
            guard !skipRePush.contains("\(table.rawValue):\(id)") else { continue }
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

    private func reconcileKeyed<T: Codable>(rows: [RemoteRow], table: Table,
                                            localLookup: (String) -> T?,
                                            skipRePush: Set<String> = []) -> [String: T]? {
        guard !rows.isEmpty else { return nil }
        var localTsMap = loadLocalTsMap()
        var merged: [String: T] = [:]
        for row in rows {
            guard let key = row.day_iso, let decoded: T = decode(row.payload) else { continue }
            guard !skipRePush.contains("\(table.rawValue):\(key)") else { continue }
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

    // MARK: - Predefined content cleanup (one-time)

    private let predefinedCleanupKey = "aura_predefined_cleanup_done_v1"

    /// Deletes the predefined programs and bundled exercises that devices
    /// predating the ownership policy pushed into this account. Runs once per
    /// install, after sign-in.
    ///
    /// Filtering happens CLIENT-side rather than with a PostgREST
    /// `payload->>isPredefined=eq.true` filter: the arrow-operator column
    /// syntax has to survive the SDK's URL encoding, and getting that subtly
    /// wrong fails open — it would match nothing, delete nothing, and still
    /// look like success. Fetching and decoding costs one extra round trip,
    /// once, and cannot silently no-op.
    ///
    /// The flag is set ONLY after both tables finish cleanly, so a network
    /// failure mid-sweep just retries at the next sign-in. Re-running is
    /// harmless — deletes are idempotent, and the rows are gone by then.
    ///
    /// These deletes fire the phase1-02 triggers and leave tombstones behind.
    /// That is fine: the pull-side `isSyncable` filters ignore predefined rows
    /// anyway, and a tombstone for a row no device wants is a no-op.
    func cleanupPredefinedRemoteRows() async {
        guard let uid = userID else { return }
        guard !UserDefaults.standard.bool(forKey: predefinedCleanupKey) else { return }

        do {
            try await deleteNonSyncableRows(.programs, uid: uid) { (p: Program) in p.isSyncable }
            try await deleteNonSyncableRows(.exercises, uid: uid) { (e: ExerciseEntry) in e.isSyncable }
            UserDefaults.standard.set(true, forKey: predefinedCleanupKey)
        } catch {
            // Signed out, offline, or a transient failure — leave the flag
            // unset so the next sign-in tries again. Nothing local changed.
        }
    }

    /// Fetches every row of `table` for this user, decodes each payload, and
    /// deletes the ones the ownership policy says should never have been
    /// there. Throws on the first failure so the caller can withhold the
    /// completion flag — unlike `fetchRows`, which swallows errors into an
    /// empty array and would make a failed fetch indistinguishable from a
    /// clean account.
    /// Just the two fields the ownership sweep needs. Deliberately NOT
    /// `RemoteRow`: that type carries `updated_at: Date`, which the default
    /// decoder cannot read from PostgREST's ISO-8601 string, so decoding it
    /// there would throw on every run and the sweep would never complete.
    ///
    /// Declared at type scope rather than inside `deleteNonSyncableRows`,
    /// where it used to live: Swift cannot nest a type in a generic function
    /// ("type 'OwnershipRow' cannot be nested in generic function"). Still
    /// private to this class.
    private struct OwnershipRow: Decodable {
        let id: String?
        let payload: AnyJSON
    }

    private func deleteNonSyncableRows<T: Decodable>(
        _ table: Table, uid: String, isSyncable: (T) -> Bool
    ) async throws {
        let response = try await client.from(table.rawValue)
            .select("id,payload")
            .eq("user_id", value: uid)
            .execute()
        let rows = try JSONDecoder().decode([OwnershipRow].self, from: response.data)

        for row in rows {
            guard let id = row.id, let decoded: T = decode(row.payload), !isSyncable(decoded) else { continue }
            try await deleteRemote(table: table, uid: uid, rowID: id)
        }
    }

    // MARK: - Tombstones (aura_deletions)

    /// Applies the tombstones a delta pull carried, BEFORE any per-table
    /// merge. Returns the `"table:key"` stamps actually removed (so the merge
    /// can skip re-pushing them) and the newest `deleted_at` seen (so the
    /// watermark advances past every tombstone, including ones LWW rejected).
    ///
    /// LWW applies to deletes exactly as it does to edits: a local change
    /// stamped AFTER the tombstone wins, so the row is kept and re-pushed —
    /// which correctly recreates it remotely. Only when the tombstone is the
    /// newer fact is the local row dropped, together with its timestamp stamp
    /// and any queued offline upsert (a pending upsert left in the queue would
    /// resurrect the row the moment the queue flushed).
    ///
    /// A tombstone for a row this device never had removes nothing — silently,
    /// not as an error.
    private func applyDeletions(_ rows: [DeletionRow]) -> (applied: Set<String>, maxTs: Date?) {
        guard !rows.isEmpty else { return ([], nil) }
        var localTsMap = loadLocalTsMap()
        var applied: Set<String> = []
        var toRemove: [Table: Set<String>] = [:]

        for row in rows {
            guard let table = Table(rawValue: row.table_name) else { continue }
            let key = localKey(for: table, rowKey: row.row_key)
            let stampKey = "\(table.rawValue):\(key)"
            if let localTs = localTsMap[stampKey], localTs > row.deleted_at {
                repushLocal(table: table, key: key)
                continue
            }
            applied.insert(stampKey)
            localTsMap.removeValue(forKey: stampKey)
            toRemove[table, default: []].insert(key)
        }
        saveLocalTsMap(localTsMap)

        for (table, keys) in toRemove {
            dropQueuedUpserts(table: table, keys: keys)
            removeLocalRows(table: table, keys: keys)
        }
        return (applied, rows.map(\.deleted_at).max())
    }

    /// Translates a tombstone's server-side `row_key` into the key this client
    /// stamps and queues that row under. Only singletons differ: the server
    /// writes the literal `"singleton"` (one row per user, `user_id` is the
    /// PK) while the client keys them by the user id.
    private func localKey(for table: Table, rowKey: String) -> String {
        table.isSingleton ? (userID ?? rowKey) : rowKey
    }

    /// Removes tombstoned rows from the local stores. Every call lands on an
    /// `applyRemote*Deletions` (or `reset*`) helper, all of which set their
    /// store's `isApplyingRemote` guard so the removal is not echoed back up
    /// as another delete. Singletons have no "absent" state — they reset to
    /// their default value instead.
    private func removeLocalRows(table: Table, keys: Set<String>) {
        let ids = Set(keys.compactMap(UUID.init(uuidString:)))
        let appState = AppStateBridge.shared
        switch table {
        case .programs:        ProgramDatabase.shared.applyRemoteDeletions(ids: ids)
        case .plans:           UserPlanDatabase.shared.applyRemoteDeletions(ids: ids)
        case .exercises:       ExerciseDatabase.shared.applyRemoteDeletions(ids: ids)
        case .workoutLogs:     appState?.applyRemoteWorkoutLogDeletions(ids: ids)
        case .measurements:    appState?.applyRemoteMeasurementDeletions(ids: ids)
        case .personalRecords: appState?.applyRemotePersonalRecordDeletions(ids: ids)
        case .progressPhotos:  appState?.applyRemoteProgressPhotoDeletions(ids: ids)
        case .dayOverrides:    appState?.applyRemoteDayOverrideDeletions(keys: keys)
        case .quickLogs:       appState?.applyRemoteQuickLogDeletions(keys: keys)
        case .bodyStats:       appState?.resetBodyStats()
        case .userProfile:     appState?.resetUserProfile()
        case .preferences:     appState?.resetPrefs()
        }
    }

    /// Re-pushes the local value of a row whose local edit is newer than its
    /// tombstone (local wins), recreating it remotely. A row that is no longer
    /// present locally has nothing to push — the delete already agreed with
    /// local state.
    private func repushLocal(table: Table, key: String) {
        let appState = AppStateBridge.shared
        switch table {
        case .programs:
            if let v = ProgramDatabase.shared.programs.first(where: { $0.id.uuidString == key }) {
                push(v, id: key, table: table)
            }
        case .plans:
            if let v = UserPlanDatabase.shared.plans.first(where: { $0.id.uuidString == key }) {
                push(v, id: key, table: table)
            }
        case .exercises:
            if let v = ExerciseDatabase.shared.entries.first(where: { $0.id.uuidString == key }) {
                push(v, id: key, table: table)
            }
        case .workoutLogs:
            if let v = appState?.workoutLogs.first(where: { $0.id.uuidString == key }) {
                push(v, id: key, table: table)
            }
        case .measurements:
            if let v = appState?.measurements.first(where: { $0.id.uuidString == key }) {
                push(v, id: key, table: table)
            }
        case .personalRecords:
            if let v = appState?.personalRecords.first(where: { $0.id.uuidString == key }) {
                push(v, id: key, table: table)
            }
        case .progressPhotos:
            if let v = appState?.progressPhotos.first(where: { $0.id.uuidString == key }),
               !ProgressPhotoStorage.shared.isUploadPending(v.id) {
                push(v, id: key, table: table)
            }
        case .dayOverrides:
            if let v = appState?.dayOverrides[key] { push(v, id: key, table: table) }
        case .quickLogs:
            if let v = appState?.quickLogs[key] { push(v, id: key, table: table) }
        case .bodyStats:
            if let v = appState?.bodyStats { push(v, id: key, table: table) }
        case .userProfile:
            if let v = appState?.userProfile { push(v, id: key, table: table) }
        case .preferences:
            if let v = appState?.currentPrefsBlob() { push(v, id: key, table: table) }
        }
    }

    /// Drops queued offline upserts for rows a tombstone just removed. Without
    /// this the row is gone from the local store but the queue still holds its
    /// last payload, and the next `flushQueue()` writes it straight back to
    /// Supabase. Queued DELETES are left alone — they agree with the tombstone.
    private func dropQueuedUpserts(table: Table, keys: Set<String>) {
        var queue = loadQueue()
        let before = queue.count
        queue.removeAll { $0.table == table.rawValue && $0.action == .upsert && keys.contains($0.rowID) }
        guard queue.count != before else { return }
        saveQueue(queue)
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
@MainActor
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
