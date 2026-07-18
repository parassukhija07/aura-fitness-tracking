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
    func syncPush(table: SupabaseSyncService.Table) {
        SupabaseSyncService.shared.push(self, id: stringID, table: table)
    }
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
