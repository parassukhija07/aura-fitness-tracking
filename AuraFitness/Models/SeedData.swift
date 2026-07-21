import Foundation
import CryptoKit

// MARK: - Stable seed identifiers
//
// Seeded programs and workouts used to get a fresh `UUID()` on every install.
// That is fine locally — the ids are persisted on first launch and stay put —
// but it breaks the moment anything CROSSES devices: `UserPlan.weekSchedule`
// and `DayOverride.workoutId` reference workouts BY ID, and plans/overrides
// sync. A plan pulled onto a second device pointed at workout ids that device
// had never generated, so the whole week resolved to empty.
//
// Deriving the ids from the content name instead means every install on every
// device computes the same id for "Push Day A", and those references resolve
// anywhere. Existing installs are migrated by `SeedIDMigration` (see
// ProgramDatabase.swift), which rewrites the old random ids and every
// reference to them.
enum StableID {
    /// Frozen namespace. NEVER change this value — it would silently
    /// re-issue every seed id and orphan every existing plan reference.
    private static let namespace = UUID(uuidString: "6B1D4E9A-3F27-4C58-9A0E-2D8C7B5F1A34")!

    static func program(_ name: String) -> UUID { v5("program:" + name) }
    static func workout(_ name: String) -> UUID { v5("workout:" + name) }

    /// Library exercise ids. Load-bearing for a second reason beyond the
    /// cross-device one above: the global catalog table seeded by
    /// `supabase/seed/generate_seed.py` computes these SAME ids server-side,
    /// which is what lets a pulled catalog row REPLACE its bundled
    /// counterpart instead of landing beside it as a duplicate.
    static func exercise(_ name: String) -> UUID { v5("exercise:" + name) }

    /// Warm-up steps are `Identifiable` and rendered in id-keyed lists, so a
    /// refreshed catalog entry must not hand them new ids on every pull.
    /// Keyed by POSITION, not by the step's own `set` number — a malformed
    /// record can repeat a set number, and two steps sharing an id collapse
    /// in the list. Mirrored by `warmup_step_id` in the seed generator.
    static func warmupStep(exercise: String, index: Int) -> UUID {
        v5("warmupstep:\(exercise)#\(index)")
    }

    /// RFC 4122 §4.3 name-based UUID, SHA-1 flavour (version 5): hash the
    /// namespace bytes followed by the name, then stamp the version and
    /// variant bits into the first 16 bytes of the digest.
    private static func v5(_ name: String) -> UUID {
        var input = withUnsafeBytes(of: namespace.uuid) { Array($0) }
        input.append(contentsOf: Array(name.utf8))
        var b = Array(Insecure.SHA1.hash(data: Data(input)).prefix(16))
        b[6] = (b[6] & 0x0F) | 0x50   // version 5
        b[8] = (b[8] & 0x3F) | 0x80   // RFC 4122 variant
        return UUID(uuid: (b[0], b[1], b[2],  b[3],  b[4],  b[5],  b[6],  b[7],
                           b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}

// MARK: - Exercise Library (80+ exercises)
enum ExerciseLibrary {
    static let all: [Exercise] = chest + back + shoulders + arms + legs + core + cardio + smith

    // MARK: Chest
    static let chest: [Exercise] = [
        ex("Barbell Bench Press", muscle: "Chest", groups: ["Chest","Front Delts","Triceps"], equip: "Barbell", diff: "Intermediate",
           repRange: "4–8", planned: 4, sets: 4,
           pr: PRRecord(weight: 100, reps: 5, date: "Jan 15"),
           target: TargetRecord(weight: 102.5, reps: 5, note: "+2.5 kg"),
           history: [SetHistory(weight: "80", reps: "6"), SetHistory(weight: "80", reps: "5"), SetHistory(weight: "77.5", reps: "6")],
           warmup: [WarmupSet(reps: 12, label: "Empty bar"), WarmupSet(reps: 8, label: "40%"),
                    WarmupSet(reps: 5, label: "60%"), WarmupSet(reps: 3, label: "80%")],
           hint: "Drive your feet into the floor and keep your shoulder blades pinned back and down. Lower the bar to your lower chest."),
        ex("Incline Dumbbell Press", muscle: "Upper Chest", groups: ["Upper Chest","Front Delts"], equip: "Dumbbell", diff: "Intermediate",
           repRange: "8–12", planned: 3, sets: 3,
           pr: PRRecord(weight: 36, reps: 10, date: "Jan 10"),
           target: TargetRecord(weight: 36, reps: 10, note: "Match best"),
           history: [SetHistory(weight: "30", reps: "10"), SetHistory(weight: "30", reps: "9"), SetHistory(weight: "28", reps: "10"), SetHistory(weight: "28", reps: "8")],
           warmup: [WarmupSet(reps: 10, label: "50%"), WarmupSet(reps: 6, label: "75%")],
           hint: "Set the bench to ~30°. Keep dumbbells stacked over your elbows."),
        ex("Cable Fly", muscle: "Chest", groups: ["Chest"], equip: "Cable", diff: "Beginner",
           isCable: true, pulley: "double", repRange: "12–15", planned: 3, sets: 3,
           pr: PRRecord(weight: 15, reps: 15, date: "Jan 12"),
           target: TargetRecord(weight: 15, reps: 15, note: "Focus on stretch"),
           history: [SetHistory(weight: "14", reps: "14"), SetHistory(weight: "14", reps: "13"), SetHistory(weight: "12.5", reps: "15")],
           hint: "Lead with your pinkies and squeeze at the midline. Keep a soft bend in the elbows."),
        ex("Dumbbell Bench Press", muscle: "Chest", groups: ["Chest","Front Delts","Triceps"], equip: "Dumbbell", diff: "Beginner",
           repRange: "8–12", planned: 3, sets: 3, hint: "Control the descent. Touch elbows to 90° at the bottom."),
        ex("Push-Up", muscle: "Chest", groups: ["Chest","Triceps","Front Delts"], equip: "Bodyweight", diff: "Beginner",
           repRange: "15–20", planned: 3, sets: 3, hint: "Keep your core tight and hips level. Full lockout at the top."),
        ex("Pec Deck", muscle: "Chest", groups: ["Chest"], equip: "Machine", diff: "Beginner",
           repRange: "12–15", planned: 3, sets: 3, hint: "Squeeze hard at the peak contraction. Control the return."),
        ex("Incline Barbell Press", muscle: "Upper Chest", groups: ["Upper Chest","Front Delts"], equip: "Barbell", diff: "Intermediate",
           repRange: "6–10", planned: 3, sets: 3, hint: "Keep elbows at ~45° to protect the shoulder joint."),
        ex("Decline Bench Press", muscle: "Lower Chest", groups: ["Lower Chest","Triceps"], equip: "Barbell", diff: "Intermediate",
           repRange: "8–12", planned: 3, sets: 3, hint: "Lower the bar to your lower chest. Slight stretch at the bottom."),
    ]

    // MARK: Back
    static let back: [Exercise] = [
        ex("Barbell Row", muscle: "Back", groups: ["Lats","Rhomboids","Rear Delts"], equip: "Barbell", diff: "Intermediate",
           repRange: "6–10", planned: 4, sets: 4,
           pr: PRRecord(weight: 90, reps: 8, date: "Jan 14"),
           target: TargetRecord(weight: 92.5, reps: 8, note: "Keep chest up"),
           hint: "Hinge at the hips, keep your lower back neutral. Pull to your belly button."),
        ex("Pull-Ups", muscle: "Back", groups: ["Lats","Biceps"], equip: "Bodyweight", diff: "Intermediate",
           repRange: "6–12", planned: 4, sets: 4,
           hint: "Full hang at the bottom. Pull until your chin clears the bar."),
        ex("Seated Cable Row", muscle: "Back", groups: ["Lats","Rhomboids"], equip: "Cable", diff: "Beginner",
           isCable: true, repRange: "10–14", planned: 3, sets: 3,
           hint: "Drive your elbows back, squeeze your shoulder blades together at the peak."),
        ex("Face Pulls", muscle: "Rear Delts", groups: ["Rear Delts","External Rotators"], equip: "Cable", diff: "Beginner",
           isCable: true, pulley: "single", repRange: "15–20", planned: 3, sets: 3,
           hint: "Pull to your forehead, external rotate at the end. Great for shoulder health."),
        ex("Lat Pulldown", muscle: "Back", groups: ["Lats","Biceps"], equip: "Cable", diff: "Beginner",
           isCable: true, repRange: "10–14", planned: 3, sets: 3,
           hint: "Lean back slightly, pull to your upper chest. Avoid swinging."),
        ex("Deadlift", muscle: "Back", groups: ["Back","Glutes","Hamstrings"], equip: "Barbell", diff: "Advanced",
           repRange: "3–6", planned: 3, sets: 3,
           pr: PRRecord(weight: 140, reps: 5, date: "Jan 8"),
           warmup: [WarmupSet(reps: 5, label: "50%"), WarmupSet(reps: 3, label: "70%"), WarmupSet(reps: 1, label: "85%")],
           hint: "Keep the bar close, drive the floor away. Neutral spine throughout."),
        ex("Weighted Pull-Ups", muscle: "Back", groups: ["Lats","Biceps"], equip: "Bodyweight", diff: "Advanced",
           repRange: "5–8", planned: 4, sets: 4,
           hint: "Use a dip belt. Same cues as bodyweight pull-ups but brace harder."),
        ex("T-Bar Row", muscle: "Back", groups: ["Lats","Rhomboids"], equip: "Barbell", diff: "Intermediate",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Grip shoulder-width. Chest pad optional. Squeeze your back at the top."),
        ex("Single-Arm Dumbbell Row", muscle: "Back", groups: ["Lats","Rear Delts"], equip: "Dumbbell", diff: "Beginner",
           repRange: "10–14", planned: 3, sets: 3,
           hint: "Support with your non-working arm. Row to your hip, elbow stays close."),
    ]

    // MARK: Shoulders
    static let shoulders: [Exercise] = [
        ex("Overhead Press", muscle: "Shoulders", groups: ["Front Delts","Side Delts","Triceps"], equip: "Barbell", diff: "Intermediate",
           repRange: "5–8", planned: 4, sets: 4,
           pr: PRRecord(weight: 70, reps: 5, date: "Jan 11"),
           warmup: [WarmupSet(reps: 10, label: "Empty bar"), WarmupSet(reps: 5, label: "60%"), WarmupSet(reps: 3, label: "80%")],
           hint: "Brace your core hard. Press in a straight line; bar passes close to your face."),
        ex("Seated Shoulder Press", muscle: "Shoulders", groups: ["Front Delts","Side Delts"], equip: "Machine", diff: "Beginner",
           repRange: "8–12", planned: 3, sets: 3,
           pr: PRRecord(weight: 47.5, reps: 10, date: "Jan 12"),
           target: TargetRecord(weight: 50, reps: 9, note: "+2.5 kg"),
           history: [SetHistory(weight: "45", reps: "10"), SetHistory(weight: "45", reps: "9"), SetHistory(weight: "42.5", reps: "10")],
           hint: "Keep your core braced and avoid arching your lower back as you press overhead."),
        ex("Cable Lateral Raise", muscle: "Side Delts", groups: ["Side Delts"], equip: "Cable", diff: "Beginner",
           isCable: true, pulley: "single", repRange: "12–15", planned: 3, sets: 3,
           pr: PRRecord(weight: 12, reps: 13, date: "Jan 10"),
           target: TargetRecord(weight: 12, reps: 13, note: "Slow eccentric"),
           history: [SetHistory(weight: "10", reps: "13"), SetHistory(weight: "10", reps: "12"), SetHistory(weight: "10", reps: "11")],
           hint: "Lead with your elbow, not your hand. Imagine pouring water from a jug at the top."),
        ex("Dumbbell Lateral Raise", muscle: "Side Delts", groups: ["Side Delts"], equip: "Dumbbell", diff: "Beginner",
           repRange: "12–15", planned: 3, sets: 3,
           hint: "Lead with your elbows, slight forward lean. Pause briefly at the top."),
        ex("Arnold Press", muscle: "Shoulders", groups: ["Front Delts","Side Delts"], equip: "Dumbbell", diff: "Intermediate",
           repRange: "10–12", planned: 3, sets: 3,
           hint: "Start with palms facing you, rotate outward as you press overhead."),
        ex("Rear Delt Fly", muscle: "Rear Delts", groups: ["Rear Delts"], equip: "Dumbbell", diff: "Beginner",
           repRange: "12–15", planned: 3, sets: 3,
           hint: "Hinge forward at hips. Keep slight bend in elbows. Squeeze at the top."),
        ex("Upright Row", muscle: "Side Delts", groups: ["Side Delts","Traps"], equip: "Barbell", diff: "Intermediate",
           repRange: "10–14", planned: 3, sets: 3,
           hint: "Wide grip reduces shoulder stress. Lead with your elbows."),
    ]

    // MARK: Arms
    static let arms: [Exercise] = [
        ex("Barbell Curl", muscle: "Biceps", groups: ["Biceps"], equip: "Barbell", diff: "Beginner",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Keep your elbows at your sides. Squeeze hard at the top. Full extension down."),
        ex("Triceps Rope Pushdown", muscle: "Triceps", groups: ["Triceps"], equip: "Cable", diff: "Beginner",
           isCable: true, pulley: "single", repRange: "10–14", planned: 3, sets: 3,
           pr: PRRecord(weight: 27.5, reps: 12, date: "Jan 12"),
           target: TargetRecord(weight: 30, reps: 10, note: "+2.5 kg"),
           hint: "Keep your elbows pinned to your sides and spread the rope apart at the bottom."),
        ex("Skull Crushers", muscle: "Triceps", groups: ["Triceps"], equip: "Barbell", diff: "Intermediate",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Lower the bar toward your forehead with control. Elbows stay tucked."),
        ex("Hammer Curl", muscle: "Biceps", groups: ["Biceps","Brachialis"], equip: "Dumbbell", diff: "Beginner",
           repRange: "10–14", planned: 3, sets: 3,
           hint: "Neutral grip throughout. Great for brachialis development."),
        ex("Overhead Triceps Extension", muscle: "Triceps", groups: ["Triceps"], equip: "Cable", diff: "Beginner",
           isCable: true, repRange: "12–15", planned: 3, sets: 3,
           hint: "Keep your elbows pointing forward. Full stretch at the bottom."),
        ex("Dumbbell Curl", muscle: "Biceps", groups: ["Biceps"], equip: "Dumbbell", diff: "Beginner",
           repRange: "10–12", planned: 3, sets: 3,
           hint: "Supinate at the top for peak contraction. Alternate or simultaneous."),
        ex("Tricep Dips", muscle: "Triceps", groups: ["Triceps","Chest"], equip: "Bodyweight", diff: "Intermediate",
           repRange: "8–15", planned: 3, sets: 3,
           hint: "Keep upright for tricep focus. Lower until upper arms are parallel to floor."),
        ex("Concentration Curl", muscle: "Biceps", groups: ["Biceps"], equip: "Dumbbell", diff: "Beginner",
           repRange: "12–15", planned: 3, sets: 3,
           hint: "Brace elbow against inner thigh. Pure bicep isolation."),
        ex("Cable Curl", muscle: "Biceps", groups: ["Biceps"], equip: "Cable", diff: "Beginner",
           isCable: true, repRange: "12–15", planned: 3, sets: 3,
           hint: "Constant tension throughout the movement. Great finisher."),
        ex("Close-Grip Bench Press", muscle: "Triceps", groups: ["Triceps","Chest"], equip: "Barbell", diff: "Intermediate",
           repRange: "6–10", planned: 3, sets: 3,
           hint: "Grip shoulder-width. Elbows tuck in. More tricep, less chest."),
    ]

    // MARK: Legs
    static let legs: [Exercise] = [
        ex("Barbell Squat", muscle: "Quads", groups: ["Quads","Glutes","Hamstrings"], equip: "Barbell", diff: "Advanced",
           repRange: "5–8", planned: 4, sets: 4,
           pr: PRRecord(weight: 120, reps: 5, date: "Jan 9"),
           warmup: [WarmupSet(reps: 10, label: "Empty bar"), WarmupSet(reps: 8, label: "40%"),
                    WarmupSet(reps: 5, label: "60%"), WarmupSet(reps: 3, label: "80%")],
           hint: "Break at hips and knees simultaneously. Knees track over toes. Chest up."),
        ex("Romanian Deadlift", muscle: "Hamstrings", groups: ["Hamstrings","Glutes"], equip: "Barbell", diff: "Intermediate",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Hip hinge with soft knees. Feel the stretch in your hamstrings. Neutral spine."),
        ex("Leg Press", muscle: "Quads", groups: ["Quads","Glutes"], equip: "Machine", diff: "Beginner",
           repRange: "10–15", planned: 3, sets: 3,
           hint: "Place feet shoulder-width. Don't lock knees at the top. Full depth if safe."),
        ex("Leg Curl", muscle: "Hamstrings", groups: ["Hamstrings"], equip: "Machine", diff: "Beginner",
           repRange: "12–15", planned: 3, sets: 3,
           hint: "Squeeze at the top. Slow eccentric for maximum fiber recruitment."),
        ex("Leg Extension", muscle: "Quads", groups: ["Quads"], equip: "Machine", diff: "Beginner",
           repRange: "12–15", planned: 3, sets: 3,
           hint: "Full extension, 1-second pause at the top. Loaded stretch at the bottom."),
        ex("Calf Raises", muscle: "Calves", groups: ["Calves"], equip: "Machine", diff: "Beginner",
           repRange: "15–20", planned: 3, sets: 3,
           hint: "Full range of motion. Pause at the top and bottom."),
        ex("Front Squat", muscle: "Quads", groups: ["Quads","Core"], equip: "Barbell", diff: "Advanced",
           repRange: "5–8", planned: 4, sets: 4,
           hint: "Elbows high, chest up. More quad-dominant than back squat."),
        ex("Walking Lunges", muscle: "Quads", groups: ["Quads","Glutes","Hamstrings"], equip: "Dumbbell", diff: "Intermediate",
           repRange: "12–16", planned: 3, sets: 3,
           hint: "Keep torso upright. Front knee tracks over toe. Full step forward."),
        ex("Sumo Deadlift", muscle: "Glutes", groups: ["Glutes","Hamstrings","Adductors"], equip: "Barbell", diff: "Intermediate",
           repRange: "5–8", planned: 4, sets: 4,
           hint: "Wide stance, toes pointed out. Push the floor away, hips forward at the top."),
        ex("Seated Calf Raise", muscle: "Calves", groups: ["Soleus"], equip: "Machine", diff: "Beginner",
           repRange: "15–20", planned: 3, sets: 3,
           hint: "Targets the soleus more than standing calf raises. Full ROM."),
        ex("Hip Thrust", muscle: "Glutes", groups: ["Glutes","Hamstrings"], equip: "Barbell", diff: "Intermediate",
           repRange: "10–15", planned: 3, sets: 3,
           hint: "Drive your hips up, squeeze glutes hard at the top. Chin tucked."),
    ]

    // MARK: Core
    static let core: [Exercise] = [
        ex("Plank", muscle: "Core", groups: ["Core","Abs"], equip: "Bodyweight", diff: "Beginner",
           repRange: "30–60s", planned: 3, sets: 3,
           hint: "Neutral spine, squeeze everything. No sagging hips."),
        ex("Cable Crunch", muscle: "Abs", groups: ["Abs"], equip: "Cable", diff: "Beginner",
           isCable: true, repRange: "15–20", planned: 3, sets: 3,
           hint: "Kneel and crunch downward. Pull from your abs, not your arms."),
        ex("Hanging Leg Raise", muscle: "Abs", groups: ["Abs","Hip Flexors"], equip: "Bodyweight", diff: "Intermediate",
           repRange: "10–15", planned: 3, sets: 3,
           hint: "Avoid swinging. Tuck hips under at the top for peak contraction."),
        ex("Ab Wheel", muscle: "Abs", groups: ["Abs","Core"], equip: "Bodyweight", diff: "Intermediate",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Keep core braced. Roll out slowly. Don't let your hips drop."),
        ex("Russian Twist", muscle: "Obliques", groups: ["Obliques","Abs"], equip: "Bodyweight", diff: "Beginner",
           repRange: "20–30", planned: 3, sets: 3,
           hint: "Lean back slightly. Rotate from your torso, not your arms."),
        ex("Decline Sit-Up", muscle: "Abs", groups: ["Abs"], equip: "Bodyweight", diff: "Beginner",
           repRange: "15–20", planned: 3, sets: 3,
           hint: "Avoid pulling on your neck. Use your abs to curl up."),
    ]

    // MARK: Cardio
    static let cardio: [Exercise] = [
        ex("Treadmill Run", muscle: "Cardio", groups: ["Cardio"], equip: "Machine", diff: "Beginner",
           repRange: "20–45 min", planned: 1, sets: 1,
           hint: "Maintain a pace where you can still hold a conversation."),
        ex("Box Jump", muscle: "Legs", groups: ["Quads","Glutes","Calves"], equip: "Bodyweight", diff: "Intermediate",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Land softly. Step down, don't jump down to protect your joints."),
        ex("Burpees", muscle: "Full Body", groups: ["Chest","Legs","Cardio"], equip: "Bodyweight", diff: "Intermediate",
           repRange: "10–20", planned: 3, sets: 3,
           hint: "Keep a steady pace. Jump at the top for extra intensity."),
        ex("Rowing Machine", muscle: "Back", groups: ["Back","Arms","Legs"], equip: "Machine", diff: "Beginner",
           repRange: "500m–2000m", planned: 3, sets: 3,
           hint: "Drive with legs first, then lean back, then pull. Reverse on the way forward."),
        ex("Cycling", muscle: "Cardio", groups: ["Cardio","Legs"], equip: "Machine", diff: "Beginner",
           repRange: "20–45 min", planned: 1, sets: 1,
           hint: "Keep cadence 80–100 RPM. Adjust resistance to maintain target heart rate."),
        ex("Jump Rope", muscle: "Cardio", groups: ["Cardio","Calves"], equip: "Bodyweight", diff: "Beginner",
           repRange: "2–5 min", planned: 3, sets: 3,
           hint: "Land on the balls of your feet. Small jumps, wrists drive the rope."),
        ex("Battle Ropes", muscle: "Cardio", groups: ["Cardio","Shoulders","Arms"], equip: "Machine", diff: "Intermediate",
           repRange: "30–45s", planned: 4, sets: 4,
           hint: "Keep your core engaged. Drive waves with your full arms, not just wrists."),
        ex("Mountain Climbers", muscle: "Core", groups: ["Core","Cardio","Shoulders"], equip: "Bodyweight", diff: "Beginner",
           repRange: "20–30s", planned: 3, sets: 3,
           hint: "Keep hips level. Drive knees to chest in a running motion."),
        ex("Jump Squats", muscle: "Legs", groups: ["Quads","Glutes","Cardio"], equip: "Bodyweight", diff: "Intermediate",
           repRange: "12–20", planned: 3, sets: 3,
           hint: "Soft landing, absorb through your hips and knees. Explode on every rep."),
    ]

    // MARK: Additional — Smith Machine & extra compound lifts
    static let smith: [Exercise] = [
        ex("Smith Machine Bench Press", muscle: "Chest", groups: ["Chest","Front Delts","Triceps"], equip: "Smith Machine", diff: "Beginner",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Useful for controlled chest work. Keep shoulder blades retracted."),
        ex("Smith Machine Squat", muscle: "Quads", groups: ["Quads","Glutes"], equip: "Smith Machine", diff: "Beginner",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Place feet slightly forward of the bar. Keep chest tall."),
        ex("Smith Machine Row", muscle: "Back", groups: ["Lats","Rhomboids"], equip: "Smith Machine", diff: "Beginner",
           repRange: "10–14", planned: 3, sets: 3,
           hint: "Underhand grip hits more bicep. Overhand grip hits more upper back."),
        ex("Smith Machine Shoulder Press", muscle: "Shoulders", groups: ["Front Delts","Side Delts"], equip: "Smith Machine", diff: "Beginner",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Great for shoulder isolation without balance demand."),
        ex("Smith Machine Hip Thrust", muscle: "Glutes", groups: ["Glutes","Hamstrings"], equip: "Smith Machine", diff: "Beginner",
           repRange: "10–15", planned: 3, sets: 3,
           hint: "Load is consistent throughout the range. Squeeze glutes hard at the top."),
        ex("Smith Machine Calf Raise", muscle: "Calves", groups: ["Calves"], equip: "Smith Machine", diff: "Beginner",
           repRange: "15–20", planned: 3, sets: 3,
           hint: "Full ROM — stretch all the way down and squeeze all the way up."),
        ex("Goblet Squat", muscle: "Quads", groups: ["Quads","Glutes","Core"], equip: "Dumbbell", diff: "Beginner",
           repRange: "12–15", planned: 3, sets: 3,
           hint: "Hold dumbbell at chest height. Elbows inside knees at the bottom."),
        ex("Bulgarian Split Squat", muscle: "Quads", groups: ["Quads","Glutes","Hamstrings"], equip: "Dumbbell", diff: "Advanced",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Rear foot elevated. Front knee tracks toes. Torso upright."),
        ex("Incline Cable Fly", muscle: "Upper Chest", groups: ["Upper Chest"], equip: "Cable", diff: "Intermediate",
           isCable: true, pulley: "double", repRange: "12–15", planned: 3, sets: 3,
           hint: "Set pulleys low, cross hands at the top. Squeeze upper chest."),
        ex("Low Cable Fly", muscle: "Upper Chest", groups: ["Upper Chest"], equip: "Cable", diff: "Intermediate",
           isCable: true, pulley: "single", repRange: "12–15", planned: 3, sets: 3,
           hint: "Pulleys at the bottom, arc upward. Targets upper chest fibres."),
        ex("Cable Crossover", muscle: "Chest", groups: ["Chest"], equip: "Cable", diff: "Beginner",
           isCable: true, pulley: "double", repRange: "12–15", planned: 3, sets: 3,
           hint: "Cross hands at the midline. Control the stretch on the way out."),
        ex("Preacher Curl", muscle: "Biceps", groups: ["Biceps"], equip: "Machine", diff: "Beginner",
           repRange: "10–14", planned: 3, sets: 3,
           hint: "Full extension at the bottom. Avoid swinging by bracing against the pad."),
        ex("Reverse Curl", muscle: "Biceps", groups: ["Biceps","Brachialis"], equip: "Barbell", diff: "Beginner",
           repRange: "10–14", planned: 3, sets: 3,
           hint: "Overhand grip. Targets brachialis and brachioradialis. Control the descent."),
        ex("Chest Dips", muscle: "Chest", groups: ["Chest","Triceps"], equip: "Bodyweight", diff: "Intermediate",
           repRange: "8–12", planned: 3, sets: 3,
           hint: "Lean forward to shift load to chest. Lower until upper arms parallel floor."),
        ex("Leg Press (Narrow Stance)", muscle: "Quads", groups: ["Quads"], equip: "Machine", diff: "Beginner",
           repRange: "10–15", planned: 3, sets: 3,
           hint: "Narrow, high foot position maximises quad activation."),
        ex("Glute Kickback", muscle: "Glutes", groups: ["Glutes"], equip: "Cable", diff: "Beginner",
           isCable: true, pulley: "single", repRange: "15–20", planned: 3, sets: 3,
           hint: "Squeeze the glute at full extension. Don't arch your lower back."),
        ex("Nordic Hamstring Curl", muscle: "Hamstrings", groups: ["Hamstrings"], equip: "Bodyweight", diff: "Advanced",
           repRange: "5–8", planned: 3, sets: 3,
           hint: "Eccentric dominant. Lower slowly, use arms to push off the floor at the bottom."),
        ex("Landmine Press", muscle: "Shoulders", groups: ["Front Delts","Upper Chest"], equip: "Barbell", diff: "Intermediate",
           repRange: "10–14", planned: 3, sets: 3,
           hint: "Great shoulder-friendly press variation. Arc the bar up and slightly forward."),
        ex("Cable Pull-Through", muscle: "Glutes", groups: ["Glutes","Hamstrings"], equip: "Cable", diff: "Beginner",
           isCable: true, pulley: "single", repRange: "12–15", planned: 3, sets: 3,
           hint: "Hip hinge movement. Drive hips forward at the top, squeeze glutes."),
        ex("Sissy Squat", muscle: "Quads", groups: ["Quads"], equip: "Bodyweight", diff: "Advanced",
           repRange: "10–15", planned: 3, sets: 3,
           hint: "Lean back as you lower. Extreme quad stretch. Use support if needed."),
        ex("Chest Supported Row", muscle: "Back", groups: ["Rhomboids","Lats","Rear Delts"], equip: "Dumbbell", diff: "Beginner",
           repRange: "12–15", planned: 3, sets: 3,
           hint: "Incline bench support eliminates momentum. Pure back isolation."),
        ex("Wrist Curl", muscle: "Forearms", groups: ["Forearms"], equip: "Dumbbell", diff: "Beginner",
           repRange: "15–20", planned: 3, sets: 3,
           hint: "Rest forearms on thighs. Small controlled wrist curl. Don't overload."),
        ex("Shrugs", muscle: "Traps", groups: ["Traps"], equip: "Dumbbell", diff: "Beginner",
           repRange: "12–15", planned: 3, sets: 3,
           hint: "Straight up, not rolling. Hold at the top for 1 second."),
    ]

    // MARK: - Builder
    static func ex(
        _ name: String, muscle: String, groups: [String], equip: String, diff: String,
        isCable: Bool = false, pulley: String = "single",
        repRange: String = "8–12", planned: Int = 3, sets: Int = 3,
        pr: PRRecord? = nil, target: TargetRecord? = nil,
        history: [SetHistory] = [],
        warmup: [WarmupSet] = [], hint: String = ""
    ) -> Exercise {
        var e = Exercise(
            name: name, primaryMuscle: muscle, muscleGroups: groups,
            equipment: equip, difficulty: diff, isCable: isCable, pulley: pulley,
            repRange: repRange, plannedSets: planned,
            lastPR: pr, target: target, history: history, warmup: warmup, hint: hint
        )
        e.sets = (0..<sets).map { _ in WorkoutSet() }
        return e
    }
}

// MARK: - Seed Programs
enum SeedData {
    // MARK: PPL
    private static func pplPushA() -> Workout {
        var w = Workout(id: StableID.workout("Push Day A"), name: "Push Day A", primaryMuscles: "Chest · Shoulders · Triceps",
                        estimatedMinutes: 60, exercises: [])
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.chest[0] }
        w.exercises = [
            find("Barbell Bench Press"),
            find("Incline Dumbbell Press"),
            find("Cable Fly"),
            find("Dumbbell Bench Press"),
            find("Seated Shoulder Press"),
            find("Cable Lateral Raise"),
            find("Triceps Rope Pushdown"),
            find("Skull Crushers")
        ]
        return w
    }
    private static func pplPullA() -> Workout {
        var w = Workout(id: StableID.workout("Pull Day A"), name: "Pull Day A", primaryMuscles: "Back · Biceps",
                        estimatedMinutes: 55, exercises: [])
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.back[0] }
        w.exercises = [
            find("Barbell Row"),
            find("Pull-Ups"),
            find("Seated Cable Row"),
            find("Lat Pulldown"),
            find("Face Pulls"),
            find("Barbell Curl"),
            find("Hammer Curl"),
            find("Cable Curl")
        ]
        return w
    }
    private static func pplLegsA() -> Workout {
        var w = Workout(id: StableID.workout("Leg Day A"), name: "Leg Day A", primaryMuscles: "Quads · Hamstrings · Calves",
                        estimatedMinutes: 65, exercises: [])
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.legs[0] }
        w.exercises = [
            find("Barbell Squat"),
            find("Romanian Deadlift"),
            find("Leg Press"),
            find("Leg Curl"),
            find("Leg Extension"),
            find("Hip Thrust"),
            find("Calf Raises"),
            find("Hanging Leg Raise")
        ]
        return w
    }
    private static func pplPushB() -> Workout {
        var w = Workout(id: StableID.workout("Push Day B"), name: "Push Day B", primaryMuscles: "Shoulders · Chest · Triceps",
                        estimatedMinutes: 58, exercises: [])
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.shoulders[0] }
        w.exercises = [
            find("Overhead Press"),
            find("Dumbbell Lateral Raise"),
            find("Incline Dumbbell Press"),
            find("Cable Lateral Raise"),
            find("Arnold Press"),
            find("Rear Delt Fly"),
            find("Skull Crushers"),
            find("Tricep Dips")
        ]
        return w
    }
    private static func pplPullB() -> Workout {
        var w = Workout(id: StableID.workout("Pull Day B"), name: "Pull Day B", primaryMuscles: "Back · Biceps",
                        estimatedMinutes: 60, exercises: [])
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.back[0] }
        w.exercises = [
            find("Deadlift"),
            find("Weighted Pull-Ups"),
            find("Seated Cable Row"),
            find("T-Bar Row"),
            find("Face Pulls"),
            find("Hammer Curl"),
            find("Concentration Curl"),
            find("Reverse Curl")
        ]
        return w
    }
    private static func pplLegsB() -> Workout {
        var w = Workout(id: StableID.workout("Leg Day B"), name: "Leg Day B", primaryMuscles: "Glutes · Quads · Hamstrings",
                        estimatedMinutes: 65, exercises: [])
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.legs[0] }
        w.exercises = [
            find("Front Squat"),
            find("Sumo Deadlift"),
            find("Walking Lunges"),
            find("Leg Press"),
            find("Leg Curl"),
            find("Bulgarian Split Squat"),
            find("Seated Calf Raise"),
            find("Ab Wheel")
        ]
        return w
    }

    // MARK: StrongLifts 5×5
    private static func sl5x5WorkoutA() -> Workout {
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise {
            var e = lib.first { $0.name == name } ?? ExerciseLibrary.chest[0]
            e.plannedSets = 5
            e.sets = (0..<5).map { _ in WorkoutSet() }
            e.repRange = "5"
            return e
        }
        return Workout(id: StableID.workout("Workout A"), name: "Workout A", primaryMuscles: "Full Body", estimatedMinutes: 45,
                       exercises: [find("Barbell Squat"), find("Barbell Bench Press"), find("Barbell Row")])
    }
    private static func sl5x5WorkoutB() -> Workout {
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise {
            var e = lib.first { $0.name == name } ?? ExerciseLibrary.chest[0]
            e.plannedSets = 5
            e.sets = (0..<5).map { _ in WorkoutSet() }
            e.repRange = "5"
            return e
        }
        return Workout(id: StableID.workout("Workout B"), name: "Workout B", primaryMuscles: "Full Body", estimatedMinutes: 45,
                       exercises: [find("Barbell Squat"), find("Overhead Press"), find("Deadlift")])
    }

    // MARK: Upper/Lower
    private static func ulUpper() -> Workout {
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.chest[0] }
        return Workout(id: StableID.workout("Upper Body"), name: "Upper Body", primaryMuscles: "Chest · Back · Shoulders · Arms", estimatedMinutes: 60,
                       exercises: [find("Barbell Bench Press"), find("Barbell Row"), find("Overhead Press"),
                                   find("Lat Pulldown"), find("Dumbbell Lateral Raise"), find("Barbell Curl"), find("Skull Crushers")])
    }
    private static func ulLower() -> Workout {
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.legs[0] }
        return Workout(id: StableID.workout("Lower Body"), name: "Lower Body", primaryMuscles: "Quads · Hamstrings · Glutes", estimatedMinutes: 55,
                       exercises: [find("Barbell Squat"), find("Romanian Deadlift"), find("Leg Press"),
                                   find("Leg Curl"), find("Calf Raises"), find("Hip Thrust")])
    }

    // MARK: Full Body
    private static func fullBodyWorkout() -> Workout {
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.chest[0] }
        return Workout(id: StableID.workout("Full Body"), name: "Full Body", primaryMuscles: "Full Body", estimatedMinutes: 50,
                       exercises: [find("Barbell Squat"), find("Barbell Bench Press"), find("Barbell Row"),
                                   find("Overhead Press"), find("Romanian Deadlift"), find("Barbell Curl"), find("Triceps Rope Pushdown")])
    }

    // MARK: HIIT
    private static func hiitWorkout() -> Workout {
        let lib = ExerciseLibrary.all
        func find(_ name: String) -> Exercise { lib.first { $0.name == name } ?? ExerciseLibrary.cardio[0] }
        return Workout(id: StableID.workout("HIIT Circuit"), name: "HIIT Circuit", primaryMuscles: "Cardio · Full Body", estimatedMinutes: 30,
                       exercises: [find("Burpees"), find("Box Jump"), find("Jump Rope"),
                                   find("Cycling"), find("Hanging Leg Raise")])
    }

    // MARK: - Programs
    static let programs: [Program] = [
        Program(
            id: StableID.program("Push · Pull · Legs"),
            name: "Push · Pull · Legs",
            daysPerWeek: 6, level: "Intermediate", style: "Hypertrophy",
            description: "The classic PPL split targets each muscle group twice per week with dedicated push, pull, and leg sessions. Ideal for intermediate lifters looking to build size and strength simultaneously.",
            workouts: [pplPushA(), pplPullA(), pplLegsA(), pplPushB(), pplPullB(), pplLegsB()]
        ),
        Program(
            id: StableID.program("StrongLifts 5×5"),
            name: "StrongLifts 5×5",
            daysPerWeek: 3, level: "Beginner", style: "Strength",
            description: "A proven strength program built around 5 compound lifts. Alternate Workout A and B three times a week with a rest day between each. Add 2.5 kg per session.",
            workouts: [sl5x5WorkoutA(), sl5x5WorkoutB()]
        ),
        Program(
            id: StableID.program("Upper / Lower"),
            name: "Upper / Lower",
            daysPerWeek: 4, level: "Intermediate", style: "Strength + Hypertrophy",
            description: "Alternate upper and lower body days four times per week. Balances frequency with volume — great transition from full-body to more advanced splits.",
            workouts: [ulUpper(), ulLower()]
        ),
        Program(
            id: StableID.program("Full Body 3×"),
            name: "Full Body 3×",
            daysPerWeek: 3, level: "Beginner", style: "Strength",
            description: "Hit every major muscle group three times a week. Perfect for beginners who want to build a foundation of strength and movement patterns.",
            workouts: [fullBodyWorkout()]
        ),
        Program(
            id: StableID.program("HIIT Cardio"),
            name: "HIIT Cardio",
            daysPerWeek: 3, level: "All Levels", style: "Cardio",
            description: "High-intensity interval training to maximize calorie burn and improve cardiovascular fitness. Short sessions with maximal effort intervals.",
            workouts: [hiitWorkout()]
        )
    ]

    // MARK: - Default user plan
    static func makeDefaultPlan() -> UserPlan {
        let ppl = programs[0]
        let workouts = ppl.workouts
        // Classic 6-day PPL: Mon Push A, Tue Pull A, Wed Legs A, Thu rest, Fri Push B, Sat Pull B, Sun Legs B
        var schedule: [Int: UUID?] = [:]
        schedule[0] = workouts[5].id   // Sun = Legs B
        schedule[1] = workouts[0].id   // Mon = Push A
        schedule[2] = workouts[1].id   // Tue = Pull A
        schedule[3] = workouts[2].id   // Wed = Legs A
        schedule[4] = .some(nil)          // Thu = rest (explicit)
        schedule[5] = workouts[3].id   // Fri = Push B
        schedule[6] = workouts[4].id   // Sat = Pull B

        return UserPlan(
            name: "My PPL Plan",
            isDefault: true,
            sourceProgramID: ppl.id,
            weekSchedule: schedule,
            customWorkouts: []
        )
    }

    // MARK: - Empty workout (FAB quick-action "Start Workout" with no plan)
    static func emptyWorkout() -> Workout {
        Workout(
            name: "Empty Workout",
            primaryMuscles: "—",
            estimatedMinutes: 0,
            exercises: [],
            program: nil
        )
    }
}
