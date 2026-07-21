import SwiftUI
import Combine

// MARK: - ExerciseEntry (canonical, flat, library record)
struct ExerciseEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: String          // Chest / Back / Legs / Shoulders / Arms / Core / Cardio / Warm-up
    var equipment: String         // Barbell / Dumbbell / Cable / Machine / Smith Machine / Bodyweight
    var musclesTargeted: [String] // primary + secondary
    var type: String              // Compound / Machine / Warm Up / Isolation
    var difficulty: String        // Beginner / Intermediate / Advanced
    var repRange: String          // "8–12"
    var youtubeURL: String        // tutorial link
    var imageURL: String
    var proTips: [String]
    var warmupProtocol: ExerciseWarmupProtocol
    var isCable: Bool = false
    var pulley: String = "single"  // single | double
    var isCustom: Bool = false     // user-created
    var notes: String = ""
    var isFavorite: Bool = false

    // Merge fields from existing Exercise (workout usage data)
    var plannedSets: Int = 3
    var hint: String = ""          // legacy coaching cue (maps to proTips[0] for new entries)
}

struct ExerciseWarmupProtocol: Codable, Hashable {
    var type: String              // "Full Progressive Protocol", "2-Set Standard Protocol", etc.
    var steps: [WarmupStep]
}

struct WarmupStep: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var set: Int
    var intensity: String         // "50% Target Weight", "Empty Bar", etc.
    var reps: Int
    var description: String
}

// MARK: - ExerciseDatabase
@MainActor
final class ExerciseDatabase: ObservableObject {
    static let shared = ExerciseDatabase()

    @Published var entries: [ExerciseEntry] = []

    private let storageKey = "aura_exercise_db_v1"

    /// Guards against a push loop while applying pulled remote rows.
    private var isApplyingRemote = false

    var categories: [String] {
        Array(Set(entries.map { $0.category })).sorted()
    }
    var equipment: [String] {
        Array(Set(entries.map { $0.equipment })).sorted()
    }
    var customEntries: [ExerciseEntry] { entries.filter { $0.isCustom } }
    var libraryEntries: [ExerciseEntry] { entries.filter { !$0.isCustom } }

    // MARK: Query
    func filtered(category: String? = nil, equipment: String? = nil, query: String = "") -> [ExerciseEntry] {
        entries.filter { e in
            let catOK = category == nil || e.category == category!
            let eqOK  = equipment == nil || e.equipment == equipment!
            let qOK   = query.isEmpty || e.name.localizedCaseInsensitiveContains(query)
                        || e.musclesTargeted.joined(separator: " ").localizedCaseInsensitiveContains(query)
            return catOK && eqOK && qOK
        }
    }

    func entry(named: String) -> ExerciseEntry? {
        entries.first { $0.name.localizedCaseInsensitiveCompare(named) == .orderedSame }
    }

    func entry(id: UUID) -> ExerciseEntry? {
        entries.first { $0.id == id }
    }

    // MARK: CRUD
    func add(_ entry: ExerciseEntry) {
        entries.append(entry)
        persist()
        syncPush(entry)
    }

    func update(_ updated: ExerciseEntry) {
        guard let i = entries.firstIndex(where: { $0.id == updated.id }) else { return }
        entries[i] = updated
        persist()
        syncPush(updated)
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
        syncDelete(id: id)
    }

    func toggleFavorite(id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].isFavorite.toggle()
        persist()
        syncPush(entries[i])
    }

    // MARK: - Remote sync hooks
    /// Single chokepoint for every entry write-through in this class — all
    /// the CRUD methods above route here, so the ownership gate only has to
    /// exist once.
    private func syncPush(_ entry: ExerciseEntry) {
        guard !isApplyingRemote else { return }
        // The bundled library ships in the binary; only custom entries sync.
        // See Syncable.swift.
        guard entry.isSyncable else { return }
        entry.syncPush(table: .exercises)
    }
    private func syncDelete(id: UUID) {
        guard !isApplyingRemote else { return }
        SupabaseSyncService.shared.delete(id: id.uuidString, table: .exercises)
    }

    /// Replaces `entries` with pulled remote rows merged over local, without
    /// re-pushing (guards the push loop).
    /// Non-syncable rows are dropped on the way in: devices predating the
    /// ownership policy pushed the whole bundled catalog, and those legacy
    /// rows must never overwrite the shipped library. Belt-and-braces
    /// alongside the push gate in `syncPush` and the one-time
    /// `cleanupPredefinedRemoteRows` sweep.
    func applyRemote(_ remoteEntries: [ExerciseEntry]) {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        var byID: [UUID: ExerciseEntry] = [:]
        for e in entries { byID[e.id] = e }
        for e in remoteEntries where e.isSyncable { byID[e.id] = e }
        entries = Array(byID.values)
        persist()
    }

    /// Drops entries deleted on another device, as reported by the
    /// `aura_deletions` tombstones in a delta pull. `applyRemote` above is a
    /// union merge and can only ever ADD rows, so a remote delete needs this
    /// separate path or the entry survives locally and gets re-pushed.
    func applyRemoteDeletions(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        let before = entries.count
        entries.removeAll { ids.contains($0.id) }
        guard entries.count != before else { return }
        persist()
    }

    /// Drops ALL entries (library + custom) back to the raw seed — distinct
    /// from `resetToSeed()` below, which preserves customs.
    func hardReset() {
        entries = Self.seedEntries()
        persist()
    }

    // Convert to lightweight Exercise for use in workouts
    func toExercise(_ entry: ExerciseEntry, sets: Int? = nil) -> Exercise {
        let numSets = sets ?? entry.plannedSets
        return Exercise(
            id: entry.id,
            name: entry.name,
            primaryMuscle: entry.musclesTargeted.first ?? entry.category,
            muscleGroups: entry.musclesTargeted,
            equipment: entry.equipment,
            difficulty: entry.difficulty,
            isCable: entry.isCable,
            pulley: entry.pulley,
            repRange: entry.repRange,
            plannedSets: numSets,
            warmup: entry.warmupProtocol.steps.map { WarmupSet(reps: $0.reps, label: $0.intensity) },
            hint: entry.proTips.first ?? entry.hint,
            imageURL: entry.imageURL.isEmpty ? nil : entry.imageURL,
            youtubeURL: entry.youtubeURL.isEmpty ? nil : entry.youtubeURL,
            sets: (0..<numSets).map { _ in WorkoutSet() }
        )
    }

    // MARK: Persistence
    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([ExerciseEntry].self, from: data),
           !saved.isEmpty {
            entries = saved
        } else {
            entries = Self.seedEntries()
            persist()
        }
    }

    // Reset to seed (preserves custom entries)
    func resetToSeed() {
        let customs = entries.filter { $0.isCustom }
        entries = Self.seedEntries() + customs
        persist()
    }
}

// MARK: - Seed Data (merged from ExerciseLibrary + JSON)
extension ExerciseDatabase {
    static func seedEntries() -> [ExerciseEntry] {
        // Convert existing ExerciseLibrary exercises
        let legacyEntries = ExerciseLibrary.all.map { ex -> ExerciseEntry in
            ExerciseEntry(
                id: ex.id,
                name: ex.name,
                category: categoryFrom(muscle: ex.primaryMuscle),
                equipment: ex.equipment,
                musclesTargeted: ex.muscleGroups,
                type: ex.equipment == "Bodyweight" ? "Compound" : (ex.isCable || ex.equipment == "Machine" ? "Machine" : "Compound"),
                difficulty: ex.difficulty,
                repRange: ex.repRange,
                youtubeURL: ex.youtubeURL ?? "",
                imageURL: ex.imageURL ?? "",
                proTips: ex.hint.isEmpty ? [] : [ex.hint],
                warmupProtocol: ExerciseWarmupProtocol(
                    type: ex.warmup.isEmpty ? "No Warmup Required" : "Standard Protocol",
                    steps: ex.warmup.enumerated().map { i, ws in
                        WarmupStep(set: i + 1, intensity: ws.label, reps: ws.reps, description: "")
                    }
                ),
                isCable: ex.isCable,
                pulley: ex.pulley,
                plannedSets: ex.plannedSets,
                hint: ex.hint
            )
        }

        // JSON library entries (deduplicated by name)
        let jsonEntries = jsonLibraryEntries().filter { j in
            !legacyEntries.contains { $0.name.lowercased() == j.name.lowercased() }
        }

        return legacyEntries + jsonEntries
    }

    private static func categoryFrom(muscle: String) -> String {
        switch muscle.lowercased() {
        case let m where m.contains("chest") || m.contains("pec"): return "Chest"
        case let m where m.contains("back") || m.contains("lat") || m.contains("trap") || m.contains("rhom"):  return "Back"
        case let m where m.contains("quad") || m.contains("ham") || m.contains("glut") || m.contains("calf") || m.contains("leg"): return "Legs"
        case let m where m.contains("shoulder") || m.contains("delt"): return "Shoulders"
        case let m where m.contains("bicep") || m.contains("tricep") || m.contains("arm"): return "Arms"
        case let m where m.contains("core") || m.contains("abs") || m.contains("oblique"): return "Core"
        case let m where m.contains("cardio"): return "Cardio"
        default: return muscle.isEmpty ? "Other" : muscle
        }
    }

    // Parse JSON gym_exercise_library.json bundled entries.
    // Falls back to the small hardcoded list ONLY when the resource is missing
    // or wholly undecodable — a single malformed record is skipped, not fatal.
    static func jsonLibraryEntries() -> [ExerciseEntry] {
        guard let url = Bundle.main.url(forResource: "gym_exercise_library", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ ExerciseDatabase: gym_exercise_library.json not found in the app bundle — falling back to \(hardcodedJsonEntries().count) hardcoded entries. Check the Resources build phase.")
            return hardcodedJsonEntries()
        }
        // Lossy array decode: each element is wrapped so one bad record is
        // dropped individually rather than discarding the whole library.
        guard let raw = try? JSONDecoder().decode([FailableDecodable<GymExerciseJSON>].self, from: data) else {
            print("⚠️ ExerciseDatabase: gym_exercise_library.json could not be decoded — falling back to hardcoded entries.")
            return hardcodedJsonEntries()
        }
        let parsed = raw.compactMap { $0.base?.toEntry() }
        guard !parsed.isEmpty else {
            print("⚠️ ExerciseDatabase: gym_exercise_library.json decoded to 0 usable entries — falling back to hardcoded entries.")
            return hardcodedJsonEntries()
        }
        return parsed
    }

    // Fallback: real exercises from the JSON (top-quality ones only, skipping "Variant N" filler)
    static func hardcodedJsonEntries() -> [ExerciseEntry] {
        [
            ExerciseEntry(
                name: "Barbell Bench Press",
                category: "Chest", equipment: "Barbell",
                musclesTargeted: ["Pectoralis Major", "Triceps Brachii", "Anterior Deltoid"],
                type: "Compound", difficulty: "Intermediate", repRange: "4–8",
                youtubeURL: "https://www.youtube.com/watch?v=rT7DgCrMOhE",
                imageURL: "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b",
                proTips: ["Keep your feet flat on the floor.", "Retract your scapula and lock your shoulders back.", "Control the descent to your mid-chest."],
                warmupProtocol: ExerciseWarmupProtocol(type: "Full Progressive Protocol", steps: [
                    WarmupStep(set: 1, intensity: "Empty Bar", reps: 12, description: "Focus on bar path and shoulder retraction."),
                    WarmupStep(set: 2, intensity: "50% Target Weight", reps: 8, description: "Explosive concentric phase."),
                    WarmupStep(set: 3, intensity: "70% Target Weight", reps: 4, description: "Acclimatize to load without fatigue."),
                    WarmupStep(set: 4, intensity: "90% Target Weight", reps: 1, description: "Single feeler rep to prepare CNS.")
                ]), isCable: false, plannedSets: 4
            ),
            ExerciseEntry(
                name: "Dumbbell Incline Bench Press",
                category: "Chest", equipment: "Dumbbell",
                musclesTargeted: ["Upper Pectoralis Major", "Anterior Deltoid", "Triceps Brachii"],
                type: "Compound", difficulty: "Intermediate", repRange: "8–12",
                youtubeURL: "https://www.youtube.com/watch?v=8iPjxAfa824",
                imageURL: "https://images.unsplash.com/photo-1517838277536-f5f99be501cd",
                proTips: ["Set the incline angle to 30 degrees to minimize anterior deltoid dominance.", "Press up and slightly inward without clanking the weights."],
                warmupProtocol: ExerciseWarmupProtocol(type: "2-Set Standard Protocol", steps: [
                    WarmupStep(set: 1, intensity: "50% Target Weight", reps: 10, description: "Establish deep stretch at the bottom."),
                    WarmupStep(set: 2, intensity: "75% Target Weight", reps: 5, description: "Build stability and joint tracking.")
                ]), isCable: false, plannedSets: 3
            ),
            ExerciseEntry(
                name: "Cable Crossover",
                category: "Chest", equipment: "Cable",
                musclesTargeted: ["Sternal Pectoralis Major", "Serratus Anterior"],
                type: "Machine", difficulty: "Beginner", repRange: "12–15",
                youtubeURL: "https://www.youtube.com/watch?v=W796-0Xf4pU",
                imageURL: "https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5",
                proTips: ["Maintain a slight bend in your elbows throughout.", "Squeeze the handles together at the peak contraction like hugging a tree."],
                warmupProtocol: ExerciseWarmupProtocol(type: "1-Set Direct Protocol", steps: [
                    WarmupStep(set: 1, intensity: "60% Target Weight", reps: 12, description: "Pump blood into target fibers.")
                ]), isCable: true, pulley: "double", plannedSets: 3
            ),
            ExerciseEntry(
                name: "Barbell Conventional Deadlift",
                category: "Back", equipment: "Barbell",
                musclesTargeted: ["Latissimus Dorsi", "Erector Spinae", "Gluteus Maximus", "Hamstrings"],
                type: "Compound", difficulty: "Advanced", repRange: "3–6",
                youtubeURL: "https://www.youtube.com/watch?v=op9kVnSso6Q",
                imageURL: "https://images.unsplash.com/photo-1517838277536-f5f99be501cd",
                proTips: ["Keep the bar scraping your shins.", "Brace your core using the Valsalva maneuver.", "Drive through the floor with your heels."],
                warmupProtocol: ExerciseWarmupProtocol(type: "Full Progressive Protocol", steps: [
                    WarmupStep(set: 1, intensity: "Empty Bar / Light Weight", reps: 10, description: "Hinge mechanics check."),
                    WarmupStep(set: 2, intensity: "40% Target Weight", reps: 8, description: "Engage lats and set hips back."),
                    WarmupStep(set: 3, intensity: "60% Target Weight", reps: 5, description: "Crisp lockouts."),
                    WarmupStep(set: 4, intensity: "80% Target Weight", reps: 2, description: "CNS priming.")
                ]), isCable: false, plannedSets: 3
            ),
            ExerciseEntry(
                name: "Lat Pulldown",
                category: "Back", equipment: "Machine",
                musclesTargeted: ["Latissimus Dorsi", "Teres Major", "Biceps Brachii"],
                type: "Machine", difficulty: "Beginner", repRange: "10–14",
                youtubeURL: "https://www.youtube.com/watch?v=CAwf7n6Luuc",
                imageURL: "https://images.unsplash.com/photo-1605296867304-46d5465a25f1",
                proTips: ["Pull down to your upper chest.", "Drive down with your elbows, not your hands.", "Avoid leaning back excessively."],
                warmupProtocol: ExerciseWarmupProtocol(type: "2-Set Standard Protocol", steps: [
                    WarmupStep(set: 1, intensity: "50% Target Weight", reps: 12, description: "Focus on full overhead stretch."),
                    WarmupStep(set: 2, intensity: "75% Target Weight", reps: 6, description: "Controlled eccentric tempo.")
                ]), isCable: true, plannedSets: 3
            ),
            ExerciseEntry(
                name: "Barbell Back Squat",
                category: "Legs", equipment: "Barbell",
                musclesTargeted: ["Quadriceps", "Gluteus Maximus", "Hamstrings", "Core"],
                type: "Compound", difficulty: "Advanced", repRange: "5–8",
                youtubeURL: "https://www.youtube.com/watch?v=MVMNk0HiTMc",
                imageURL: "https://images.unsplash.com/photo-1574680096145-d05b474e2155",
                proTips: ["Break at hips and knees simultaneously.", "Keep knees tracking over toes.", "Maintain a neutral spine under load."],
                warmupProtocol: ExerciseWarmupProtocol(type: "Full Progressive Protocol", steps: [
                    WarmupStep(set: 1, intensity: "Empty Bar", reps: 15, description: "Open up hip flexors and ankles."),
                    WarmupStep(set: 2, intensity: "50% Target Weight", reps: 8, description: "Achieve full depth below parallel."),
                    WarmupStep(set: 3, intensity: "70% Target Weight", reps: 4, description: "Stay tight at the hole."),
                    WarmupStep(set: 4, intensity: "90% Target Weight", reps: 1, description: "Heavy load walkout and single rep.")
                ]), isCable: false, plannedSets: 4
            ),
            ExerciseEntry(
                name: "Dumbbell Overhead Press",
                category: "Shoulders", equipment: "Dumbbell",
                musclesTargeted: ["Anterior Deltoid", "Lateral Deltoid", "Triceps Brachii"],
                type: "Compound", difficulty: "Intermediate", repRange: "8–12",
                youtubeURL: "https://www.youtube.com/watch?v=qEwKCR5JCog",
                imageURL: "https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5",
                proTips: ["Do not flare elbows out fully; keep them in the scapular plane.", "Press all the way to lockout without hyperextending lower back."],
                warmupProtocol: ExerciseWarmupProtocol(type: "2-Set Standard Protocol", steps: [
                    WarmupStep(set: 1, intensity: "50% Target Weight", reps: 10, description: "Warm shoulder girdles."),
                    WarmupStep(set: 2, intensity: "75% Target Weight", reps: 5, description: "Set core stability.")
                ]), isCable: false, plannedSets: 3
            ),
            ExerciseEntry(
                name: "Dumbbell Bicep Curl",
                category: "Arms", equipment: "Dumbbell",
                musclesTargeted: ["Biceps Brachii", "Brachialis", "Brachioradialis"],
                type: "Compound", difficulty: "Beginner", repRange: "10–14",
                youtubeURL: "https://www.youtube.com/watch?v=ykJmrZ5v0oo",
                imageURL: "https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e",
                proTips: ["Keep elbows pinned to your sides.", "Supinate your wrists at the top of the movement for maximum peak contraction."],
                warmupProtocol: ExerciseWarmupProtocol(type: "1-Set Direct Protocol", steps: [
                    WarmupStep(set: 1, intensity: "60% Target Weight", reps: 12, description: "Lubricate elbow joints.")
                ]), isCable: false, plannedSets: 3
            ),
            ExerciseEntry(
                name: "Hanging Knee Raise",
                category: "Core", equipment: "Bodyweight",
                musclesTargeted: ["Rectus Abdominis", "Iliopsoas"],
                type: "Compound", difficulty: "Beginner", repRange: "10–15",
                youtubeURL: "https://www.youtube.com/watch?v=rMvS_N1gXqU",
                imageURL: "https://images.unsplash.com/photo-1517838277536-f5f99be501cd",
                proTips: ["Avoid swinging your torso.", "Initiate the movement by tilting the pelvis upward, not just lifting thighs."],
                warmupProtocol: ExerciseWarmupProtocol(type: "No Warmup Required", steps: []),
                isCable: false, plannedSets: 3
            ),
            ExerciseEntry(
                name: "Arm Circles",
                category: "Warm-up", equipment: "Bodyweight",
                musclesTargeted: ["Rotator Cuff", "Deltoids"],
                type: "Warm Up", difficulty: "Beginner", repRange: "20",
                youtubeURL: "https://www.youtube.com/watch?v=140OCTGy994",
                imageURL: "https://images.unsplash.com/photo-1605296867304-46d5465a25f1",
                proTips: ["Start with small circles, gradually increasing radius.", "Keep torso fixed to ensure motion stays isolation within shoulders."],
                warmupProtocol: ExerciseWarmupProtocol(type: "Activation Movement", steps: [
                    WarmupStep(set: 1, intensity: "Bodyweight", reps: 20, description: "10 circles forward, 10 circles backward.")
                ]), isCable: false, plannedSets: 1
            ),
            ExerciseEntry(
                name: "World's Greatest Stretch",
                category: "Warm-up", equipment: "Bodyweight",
                musclesTargeted: ["Hip Flexors", "Thoracic Spine", "Hamstrings"],
                type: "Warm Up", difficulty: "Beginner", repRange: "6/side",
                youtubeURL: "https://www.youtube.com/watch?v=-CiDwNInZcw",
                imageURL: "https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5",
                proTips: ["Rotate through the upper back, keeping your base hip locked straight.", "Exhale deeply as you reach upward."],
                warmupProtocol: ExerciseWarmupProtocol(type: "Mobility Sequence", steps: [
                    WarmupStep(set: 1, intensity: "Bodyweight", reps: 6, description: "Perform 6 dynamic iterations per side slowly.")
                ]), isCable: false, plannedSets: 1
            )
        ]
    }
}

// MARK: - Lossy element wrapper
/// Wraps one array element so a malformed record decodes to `nil` (skipped)
/// instead of throwing and taking the whole array down with it.
struct FailableDecodable<Base: Decodable>: Decodable {
    let base: Base?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        base = try? container.decode(Base.self)
    }
}

// MARK: - JSON Decodable bridge
struct GymExerciseJSON: Codable {
    let name: String
    let category: String
    let equipment: String
    let muscles_targeted: [String]
    let type: String
    let youtube_url: String
    let image_url: String
    let pro_tips: [String]
    let warmup_protocol: WarmupProtocolJSON

    struct WarmupProtocolJSON: Codable {
        let type: String
        let steps: [WarmupStepJSON]
    }
    struct WarmupStepJSON: Codable {
        let set: Int
        let intensity: String
        let reps: Int
        let description: String
    }

    func toEntry() -> ExerciseEntry {
        let diff: String = {
            let n = name.lowercased()
            if n.contains("deadlift") || n.contains("squat") || n.contains("bulgarian") { return "Advanced" }
            if n.contains("barbell") || n.contains("overhead") { return "Intermediate" }
            return "Beginner"
        }()
        return ExerciseEntry(
            name: name,
            category: category,
            equipment: equipment,
            musclesTargeted: muscles_targeted,
            type: type,
            difficulty: diff,
            repRange: "8–12",
            youtubeURL: youtube_url,
            imageURL: image_url,
            proTips: pro_tips,
            warmupProtocol: ExerciseWarmupProtocol(
                type: warmup_protocol.type,
                steps: warmup_protocol.steps.map {
                    WarmupStep(set: $0.set, intensity: $0.intensity, reps: $0.reps, description: $0.description)
                }
            ),
            isCable: equipment.lowercased() == "cable",
            plannedSets: 3
        )
    }
}
