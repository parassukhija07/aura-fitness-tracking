import Foundation

// MARK: - ProgressPhoto
struct ProgressPhoto: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var imageData: Data
    var weight: Double?
    var note: String = ""
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
        ("Balanced", [30, 40, 30]), ("High carb", [25, 55, 20]),
        ("High protein", [40, 35, 25]), ("Keto", [30, 8, 62]),
    ]
    static func macroSplit(_ key: String) -> [Int] {
        macroSplits.first { $0.label == key }?.pct ?? [30, 40, 30]
    }
}

// MARK: - Daily macro targets (grams)
struct MacroTargets {
    var protein: Int
    var carbs: Int
    var fats: Int
    var fiber: Int
}

// MARK: - BodyStats
struct BodyStats: Codable {
    var height: Double = 178       // cm
    var weight: Double = 78.4      // kg
    var age: Int = 28
    var sex: String = "Male"       // "Male" | "Female"
    var activityLevel: String = "Moderate"  // key into NutritionConstants.ACT
    var targetWeight: Double = 80          // kg
    var goalType: String = "Lean gain"      // key into GOAL_ADJ
    var macroSplit: String = "Balanced"     // key into MACRO_SPLIT

    /// BMI = wt / (h/100)²
    var bmi: Double {
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
struct UserProfile: Codable {
    var firstName: String = "Alex"
    var lastName: String = "Jordan"
    var email: String = ""
    var phone: String = ""
    var birthday: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    var gender: String = "Male"
    var location: String = ""
    var country: String = "United States"
    var city: String = "Austin"
    var state: String = "TX"
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
