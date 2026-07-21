import Foundation

/// Tiny helper protocol so each store's write-through hooks read as one-liners:
/// `entry.syncPush(table: .exercises)` instead of repeating
/// `SupabaseSyncService.shared.push(entry, id: entry.stringID, table: .exercises)`
/// at every call site. Optional per the spec — stores may also inline the
/// `SupabaseSyncService.shared.push(...)` call directly.
protocol Syncable: Encodable {
    /// The row id used as the Supabase primary key (or day-ISO key for
    /// keyed-dict tables — those call `push` directly with the ISO string).
    var stringID: String { get }
}

extension Syncable {
    /// Fire-and-forget push of `self` to the given table.
    @MainActor
    func syncPush(table: SupabaseSyncService.Table) {
        SupabaseSyncService.shared.push(self, id: stringID, table: table)
    }
}

// MARK: - Ownership policy
//
// Predefined programs and the bundled exercise library are seeded IDENTICALLY
// on every install (deterministically, since `StableID` landed), so pushing
// them per-user stores the same rows again for every account and every device
// while carrying exactly zero information. Only user-created or user-owned
// content syncs.
//
// These two properties are the single source of truth for that policy — the
// stores' write-through hooks and the pull-side merge both consult them.

extension Program {
    /// Seeded programs are re-created locally on every device; only
    /// user-created ones are worth a row. Editing a predefined program is
    /// routed through a user-owned copy by the Plan tab, so an edited program
    /// arrives here already `isPredefined == false`.
    var isSyncable: Bool { !isPredefined }
}

extension ExerciseEntry {
    /// The bundled catalog ships in the app binary; only user-added exercises
    /// need a row.
    var isSyncable: Bool { isCustom }
}

extension Program: Syncable {
    var stringID: String { id.uuidString }
}
extension UserPlan: Syncable {
    var stringID: String { id.uuidString }
}
extension ExerciseEntry: Syncable {
    var stringID: String { id.uuidString }
}
extension WorkoutLog: Syncable {
    var stringID: String { id.uuidString }
}
extension Measurement: Syncable {
    var stringID: String { id.uuidString }
}
extension PersonalRecord: Syncable {
    var stringID: String { id.uuidString }
}
extension ProgressPhoto: Syncable {
    var stringID: String { id.uuidString }
}
