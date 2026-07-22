import Foundation

// MARK: - ProgressPhoto
struct ProgressPhoto: Identifiable, Codable {
    var id = UUID()
    var date: Date
    /// LEGACY inline JPEG bytes. Non-nil only while the photo has not reached
    /// Supabase Storage yet — a photo just taken, a guest-mode photo, or a row
    /// written by a client predating phase3-01. `ProgressPhotoStorage` clears
    /// it the moment the upload succeeds, so a migrated row carries metadata
    /// only and the bytes come from the bucket (or the local file cache).
    /// Optional purely so those legacy rows keep decoding.
    var imageData: Data?
    var weight: Double?
    var note: String = ""
    /// Bucket-relative object path — `{user_id}/{photo_uuid}.jpg` inside
    /// `progress-photos` (see 0006_progress_photos_storage.sql). Non-nil means
    /// the bytes are durable server-side and `imageData` is expected to be nil.
    var storagePath: String? = nil
}

// MARK: - WorkoutLog
struct WorkoutLog: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var workoutName: String
    var exercises: [Exercise]
    var durationSeconds: Int
    var sessionNotes: String = ""
}

// MARK: - Measurement
struct Measurement: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var weight: Double? = nil
    var bodyFatPct: Double? = nil
    var neck: Double? = nil
    var chest: Double? = nil
    var waist: Double? = nil
    var hips: Double? = nil
    var arms: Double? = nil
    var thighs: Double? = nil
    var shoulders: Double? = nil
}

// MARK: - Nutrition constants (canonical — mirror combined/progress.jsx)

/// Activity multipliers applied to BMR → TDEE (ACT in the prototype).
enum NutritionConstants {
    /// ACT — activity → TDEE multiplier.
    static let activityMultipliers: [(label: String, mult: Double)] = [
        ("Sedentary", 1.2), ("Light", 1.375), ("Moderate", 1.55),
        ("Active", 1.725), ("Athlete", 1.9),
    ]
    static func activityMultiplier(_ key: String) -> Double {
        activityMultipliers.first { $0.label == key }?.mult ?? 1.55
    }

    /// GOAL_ADJ — daily calorie delta applied to TDEE per goal.
    static let goalAdjustments: [(label: String, delta: Int)] = [
        ("Lose fat", -500), ("Maintain", 0), ("Lean gain", 200), ("Gain muscle", 400),
    ]
    static func goalAdjustment(_ key: String) -> Int {
        goalAdjustments.first { $0.label == key }?.delta ?? 0
    }

    /// MACRO_SPLIT — percentage [Protein, Carbs, Fats] per macro preset.
    static let macroSplits: [(label: String, pct: [Int])] = [
        ("Balanced", [30, 40, 30]), ("High carb", [25, 50, 25]),
        ("High protein", [40, 30, 30]), ("Keto", [30, 10, 60]),
    ]
    static func macroSplit(_ key: String) -> [Int] {
        macroSplits.first { $0.label == key }?.pct ?? [30, 40, 30]
    }

    /// Input bounds for the details editor. Canonical units: cm and kg.
    static let ageRange: ClosedRange<Int> = 13...100
    static let heightRangeCm: ClosedRange<Double> = 100...250
    static let weightRangeKg: ClosedRange<Double> = 30...300
}

// MARK: - Daily macro targets (grams)
struct MacroTargets {
    var protein: Int
    var carbs: Int
    var fats: Int
    var fiber: Int
}

// MARK: - BodyStats
//
// Measurements default to 0 = "not entered yet", which is what
// `hasCompleteDetails` below tests for; every derived figure (BMI/BMR/TDEE/
// macros) stays hidden until the user supplies real numbers. They previously
// shipped as a filled-in 178 cm / 78.4 kg / 28 y example, which read as the
// user's own data on a brand-new account.
//
// `sex`, `activityLevel`, `goalType` and `macroSplit` keep their defaults on
// purpose: they are keys into `NutritionConstants.ACT` / `GOAL_ADJ` /
// `MACRO_SPLIT`, and an empty string is not a member of any of those.
struct BodyStats: Codable {
    var height: Double = 0         // cm — 0 = unset
    var weight: Double = 0         // kg — 0 = unset
    var age: Int = 0               // 0 = unset
    var sex: String = "Male"       // "Male" | "Female"
    var activityLevel: String = "Moderate"  // key into NutritionConstants.ACT
    var targetWeight: Double = 0            // kg — 0 = unset
    var goalType: String = "Lean gain"      // key into GOAL_ADJ
    var macroSplit: String = "Balanced"     // key into MACRO_SPLIT

    /// True once height and weight are both set — every derived figure
    /// (BMI/BMR/TDEE/targets) is meaningless until then.
    var hasCompleteDetails: Bool { height > 0 && weight > 0 }

    /// BMI = wt / (h/100)² — 0 when height is unset (never divide by zero).
    var bmi: Double {
        guard hasCompleteDetails else { return 0 }
        let hm = height / 100
        return weight / (hm * hm)
    }

    /// BMR — Mifflin-St Jeor: 10·wt + 6.25·h − 5·age + (Male ? +5 : −161).
    var bmr: Double {
        10 * weight + 6.25 * height - 5 * Double(age) + (sex == "Male" ? 5 : -161)
    }

    /// TDEE = round(BMR × ACT[activity]).
    var tdee: Double {
        (bmr * NutritionConstants.activityMultiplier(activityLevel)).rounded()
    }

    /// Target daily calories = max(1200, TDEE + GOAL_ADJ[goal]).
    var targetCalories: Double {
        max(1200, tdee + Double(NutritionConstants.goalAdjustment(goalType)))
    }

    /// Daily macros (grams): P,C = split%·kcal ÷4 · F = split%·kcal ÷9 · fiber = kcal/1000 ×14.
    var macros: MacroTargets {
        let cal = targetCalories
        let sp = NutritionConstants.macroSplit(macroSplit)
        return MacroTargets(
            protein: Int((cal * Double(sp[0]) / 100 / 4).rounded()),
            carbs:   Int((cal * Double(sp[1]) / 100 / 4).rounded()),
            fats:    Int((cal * Double(sp[2]) / 100 / 9).rounded()),
            fiber:   Int((cal / 1000 * 14).rounded())
        )
    }
}

// MARK: - UserProfile
/// Every field starts empty. The name/location fields used to ship as
/// "Alex Jordan · Austin, TX, United States", which showed up on a brand-new
/// account as if the user had entered it.
///
/// `birthday` has no empty representation (non-optional `Date`, and the editor
/// binds a `DatePicker` straight to it), so it keeps a neutral 25-years-ago
/// starting point rather than a made-up birth date.
struct UserProfile: Codable {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var phone: String = ""
    var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var gender: String = ""
    var location: String = ""
    var country: String = ""
    var city: String = ""
    var state: String = ""
    var photoURL: String? = nil
}

// MARK: - PersonalRecord
struct PersonalRecord: Identifiable, Codable {
    var id = UUID()
    var exerciseName: String
    var muscle: String
    var weight: Double
    var reps: Int
    var date: Date
    var estimated1RM: Double   // Epley: w * (1 + r/30)

    /// Epley est. 1RM: w × (1 + reps/30), rounded to 0.25; reps ≤ 1 returns the weight.
    static func compute1RM(weight: Double, reps: Int) -> Double {
        if reps <= 1 { return weight }
        return (weight * (1 + Double(reps) / 30.0) * 4).rounded() / 4
    }
}
