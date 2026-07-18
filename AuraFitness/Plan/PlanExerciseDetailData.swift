import Foundation

// MARK: - Exercise detail data
//
// Mirror of the computed seeds in `.design-import-v9/plan/exercise-detail.jsx`:
// levelFor, XD_INFO + defaults, history generation, Epley PBs.

struct XDActivation: Hashable { let muscle: String; let p: Int }

struct XDInfo {
    var desc: String
    var primary: [String]
    var secondary: [String]
    var activation: [XDActivation]
    var tips: [String]
}

enum PlanExerciseDetail {

    /// `levelFor` — derived purely from equipment.
    static func level(for equip: String) -> String {
        switch equip {
        case "Bodyweight", "Machine", "Smith": return "Beginner"
        case "Dumbbell", "Cable": return "Intermediate"
        case "Barbell": return "Advanced"
        default: return "Intermediate"
        }
    }

    /// `getXDInfo` — explicit entry when present, else a per-muscle default.
    static func info(for ex: PlanLibExercise) -> XDInfo {
        if let i = xdInfo[ex.id] { return i }
        let def = muscleDefault[ex.muscle] ?? muscleDefault["Chest"]!
        return XDInfo(
            desc: "\(ex.name) is a targeted \(ex.equip.lowercased()) exercise focusing on the \(ex.muscle.lowercased()).",
            primary: def.primary,
            secondary: def.secondary,
            activation: def.activation,
            tips: [
                "Maintain full range of motion on every rep",
                "Control the eccentric phase — don't drop the weight",
                "Focus on the mind-muscle connection with the target muscle",
                "Progressive overload is key: add weight or reps each session",
            ]
        )
    }

    private static let muscleDefault: [String: (primary: [String], secondary: [String], activation: [XDActivation])] = [
        "Chest":     (["Chest"], ["Triceps", "Shoulders"], [.init(muscle: "Chest", p: 80), .init(muscle: "Triceps", p: 42), .init(muscle: "Shoulders", p: 30)]),
        "Back":      (["Back"], ["Biceps"], [.init(muscle: "Back", p: 78), .init(muscle: "Biceps", p: 44)]),
        "Shoulders": (["Shoulders"], ["Triceps"], [.init(muscle: "Shoulders", p: 76), .init(muscle: "Triceps", p: 40)]),
        "Biceps":    (["Biceps"], [], [.init(muscle: "Biceps", p: 85), .init(muscle: "Forearms", p: 28)]),
        "Triceps":   (["Triceps"], [], [.init(muscle: "Triceps", p: 86)]),
        "Legs":      (["Legs"], ["Core"], [.init(muscle: "Quads", p: 82), .init(muscle: "Glutes", p: 50), .init(muscle: "Hamstrings", p: 32)]),
        "Core":      (["Core"], ["Shoulders"], [.init(muscle: "Core", p: 84), .init(muscle: "Shoulders", p: 24)]),
    ]

    private static let xdInfo: [String: XDInfo] = [
        "bbar": XDInfo(
            desc: "The barbell bench press is the foundation of upper-body strength. Pressing a loaded bar from chest to lockout trains the pecs, anterior delts, and triceps in one powerful movement.",
            primary: ["Chest"], secondary: ["Triceps", "Shoulders"],
            activation: [.init(muscle: "Chest", p: 82), .init(muscle: "Triceps", p: 55), .init(muscle: "Shoulders", p: 38)],
            tips: ["Retract and depress shoulder blades before unracking", "Lower bar to mid-chest — not your neck", "Drive feet into the floor throughout", "Keep elbows at 45–75° to protect the shoulder"]),
        "cfly": XDInfo(
            desc: "Cable flies maintain constant tension on the pecs through the full range, making them ideal for isolating the chest after heavier compound work.",
            primary: ["Chest"], secondary: ["Shoulders"],
            activation: [.init(muscle: "Chest", p: 90), .init(muscle: "Shoulders", p: 35)],
            tips: ["Lead with pinkies and squeeze at the midline", "Think \"hugging a tree\" — keep a soft elbow bend", "Control the eccentric; don't let cables yank you back", "Slight forward lean increases chest activation"]),
        "idb": XDInfo(
            desc: "Incline dumbbell press shifts emphasis to the upper (clavicular) portion of the pecs while allowing a natural wrist path and greater stretch at the bottom.",
            primary: ["Chest"], secondary: ["Shoulders", "Triceps"],
            activation: [.init(muscle: "Chest", p: 78), .init(muscle: "Shoulders", p: 48), .init(muscle: "Triceps", p: 35)],
            tips: ["Set bench to 30–45° — higher angles shift load to delts", "Allow a deep stretch at bottom without losing tension", "Neutral or semi-supinated grip reduces shoulder impingement", "Keep wrists stacked directly over elbows"]),
        "brow": XDInfo(
            desc: "The barbell row is the premier back-builder for thickness. Hinging at the hips and rowing the bar to the lower chest trains the entire posterior chain.",
            primary: ["Back"], secondary: ["Biceps"],
            activation: [.init(muscle: "Back", p: 80), .init(muscle: "Biceps", p: 50), .init(muscle: "Rear Delts", p: 30)],
            tips: ["Hinge to ~45° and keep a neutral spine throughout", "Row to your lower chest/upper abdomen, not your hips", "Lead with your elbows — don't curl the weight", "Squeeze the lats at the top for a full contraction"]),
        "pull": XDInfo(
            desc: "Pull-ups are the ultimate bodyweight back exercise, developing lat width, grip strength, and scapular stability simultaneously.",
            primary: ["Back"], secondary: ["Biceps"],
            activation: [.init(muscle: "Back", p: 85), .init(muscle: "Biceps", p: 45), .init(muscle: "Core", p: 25)],
            tips: ["Start from a dead hang to maximise range of motion", "Initiate by depressing your shoulder blades first", "Pull elbows toward your hips, not just downward", "Cross ankles and brace core to reduce swinging"]),
        "ohp": XDInfo(
            desc: "The overhead press builds boulder shoulders and full-body stability. Pressing overhead demands core bracing and scapular coordination throughout the lift.",
            primary: ["Shoulders"], secondary: ["Triceps"],
            activation: [.init(muscle: "Shoulders", p: 78), .init(muscle: "Triceps", p: 52), .init(muscle: "Upper Chest", p: 22)],
            tips: ["Start bar just above clavicles, not on chest", "Push your head through the window at lockout", "Brace and maintain a neutral spine — avoid lumbar hyperextension", "Slightly wider than shoulder-width grip balances pressing strength"]),
        "latdb": XDInfo(
            desc: "Lateral raises isolate the medial deltoid — the muscle responsible for shoulder width. Light weight and strict form beat heavy cheating every time.",
            primary: ["Shoulders"], secondary: [],
            activation: [.init(muscle: "Shoulders", p: 85), .init(muscle: "Traps", p: 30)],
            tips: ["Lead with your elbows, not your hands", "Stop at shoulder height — going higher recruits traps excessively", "Slight forward lean shifts load to medial delt", "Control the descent; the eccentric builds more muscle"]),
        "squat": XDInfo(
            desc: "The barbell squat is the king of lower-body exercises, loading the entire lower body and core while demanding significant mobility and stability.",
            primary: ["Legs"], secondary: ["Core"],
            activation: [.init(muscle: "Quads", p: 85), .init(muscle: "Glutes", p: 55), .init(muscle: "Hamstrings", p: 35), .init(muscle: "Core", p: 40)],
            tips: ["High-bar: more upright torso and quad dominant", "Break at hips and knees simultaneously on the descent", "Knees track in line with toes throughout", "Brace your core like you're about to take a punch"]),
        "bcurl": XDInfo(
            desc: "The barbell curl allows maximum loading for bicep development. The supinated grip fully engages both heads of the biceps brachii.",
            primary: ["Biceps"], secondary: [],
            activation: [.init(muscle: "Biceps", p: 88), .init(muscle: "Forearms", p: 30)],
            tips: ["Keep elbows pinned at your sides throughout", "Don't swing — momentum kills bicep tension", "Full extension at the bottom for complete range", "Supinate wrists slightly at the top for peak contraction"]),
        "tpush": XDInfo(
            desc: "Cable pushdowns isolate the triceps with constant tension through the full range. The cable angle keeps resistance where free weights would lose it at lockout.",
            primary: ["Triceps"], secondary: [],
            activation: [.init(muscle: "Triceps", p: 87), .init(muscle: "Anconeus", p: 25)],
            tips: ["Keep elbows pinned at your sides — they are the pivot", "Fully extend to lockout on every rep", "Vary grip (rope vs straight bar) to hit different heads", "Hinge slightly at hips to stabilise the torso"]),
    ]

    // MARK: History / PBs

    struct HistSet: Hashable { var weight: Double; var reps: Int }
    struct HistSession: Hashable { var date: String; var sets: [HistSet] }
    struct PBs { var e1rm: Double; var maxW: Double; var maxR: Int; var maxVol: Int }

    // Real session history now comes from `AppState.realHistory(forExercise:)`,
    // derived from the user's actual `workoutLogs` (see AppState.swift).

    /// `epley` — w × (1 + reps/30), rounded to 0.25; reps ≤ 1 returns the weight.
    static func epley(_ w: Double, _ r: Int) -> Double {
        if r <= 1 { return w }
        return (w * (1 + Double(r) / 30) * 4).rounded() / 4
    }

    static func calcPBs(_ sessions: [HistSession]) -> PBs {
        var maxE = 0.0, maxW = 0.0, maxR = 0, maxVol = 0.0
        for s in sessions {
            var sv = 0.0
            for set in s.sets {
                let e = epley(set.weight, set.reps)
                if e > maxE { maxE = e }
                if set.weight > maxW { maxW = set.weight }
                if set.reps > maxR { maxR = set.reps }
                sv += set.weight * Double(set.reps)
            }
            if sv > maxVol { maxVol = sv }
        }
        return PBs(e1rm: maxE, maxW: maxW, maxR: maxR, maxVol: Int(maxVol.rounded()))
    }
}

/// Trims trailing ".0" so `80.0` prints as `80` and `82.5` stays `82.5`.
func planNum(_ v: Double) -> String {
    v == v.rounded() ? String(Int(v)) : String(v)
}
