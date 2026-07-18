import HealthKit

/// §5.7 — minimal HealthKit bridge: body-weight and workout two-way sync,
/// gated by `AppState.appleHealthConnected`.
///
/// Requires the HealthKit capability enabled in Xcode (Signing & Capabilities
/// → + Capability → HealthKit) so `AuraFitness.entitlements` actually takes
/// effect — see that file for the entitlement key. Without it, `isAvailable`
/// still returns true on-device but every authorization request fails.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private var bodyMassType: HKQuantityType { HKQuantityType(.bodyMass) }
    private var workoutType: HKObjectType { HKObjectType.workoutType() }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read+write for body weight and read+write for workouts.
    /// Flips `appState.appleHealthConnected` on success so the Profile UI
    /// reflects a real grant instead of an optimistic toggle.
    func requestAuthorization(appState: AppState) async {
        guard isAvailable else { return }
        let toShare: Set<HKSampleType> = [HKQuantityType(.bodyMass), HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = [bodyMassType, workoutType]
        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
            appState.appleHealthConnected = true
        } catch {
            appState.appleHealthConnected = false
        }
    }

    func disconnect(appState: AppState) {
        // HealthKit has no programmatic "revoke" API — access is only
        // withdrawn from iOS Settings → Health → Data Access & Devices. This
        // just stops Aura from reading/writing until re-enabled.
        appState.appleHealthConnected = false
    }

    /// Writes a single body-weight sample (kg) at `date`.
    func saveBodyWeight(kg: Double, date: Date = Date()) {
        guard isAvailable else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: date, end: date)
        store.save(sample) { _, _ in }
    }

    /// Writes a completed workout as a generic HealthKit workout entry.
    func saveWorkout(start: Date, durationSeconds: Int) {
        guard isAvailable else { return }
        let end = start.addingTimeInterval(TimeInterval(durationSeconds))
        let workout = HKWorkout(activityType: .traditionalStrengthTraining, start: start, end: end)
        store.save(workout) { _, _ in }
    }

    /// Reads the most recent body-weight sample, if any, converted to kg.
    func fetchLatestBodyWeight() async -> Double? {
        guard isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: bodyMassType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }
}
