import Foundation

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

// MARK: - BodyStats
struct BodyStats: Codable {
    var height: Double = 175       // cm
    var weight: Double = 75        // kg
    var age: Int = 28
    var sex: String = "Male"       // "Male" | "Female"
    var activityLevel: String = "Moderately Active"
    var targetWeight: Double? = nil
    var goalType: String = "leanGain"       // "loseFat" | "leanGain" | "gainMuscle" | "maintain"
    var macroSplit: String = "balanced"     // "balanced" | "highCarb" | "highProtein" | "keto"

    var bmi: Double {
        let hm = height / 100
        return weight / (hm * hm)
    }

    /// Mifflin-St Jeor TDEE
    var tdee: Double {
        let bmr: Double
        if sex == "Male" {
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        } else {
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
        }
        let multiplier: Double
        switch activityLevel {
        case "Sedentary":           multiplier = 1.2
        case "Lightly Active":      multiplier = 1.375
        case "Moderately Active":   multiplier = 1.55
        case "Very Active":         multiplier = 1.725
        default:                    multiplier = 1.55
        }
        return bmr * multiplier
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

    static func compute1RM(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(reps) / 30.0)
    }
}
