import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var appState: AppState

    var stats: BodyStats { appState.bodyStats }
    let goals = ["loseFat","leanGain","gainMuscle","maintain"]
    let goalLabels = ["Lose Fat","Lean Gain","Gain Muscle","Maintain"]
    let macroSplits = ["balanced","highProtein","highCarb","keto"]
    let macroLabels = ["Balanced","High Protein","High Carb","Keto"]

    var dailyProtein: Double {
        switch stats.goalType {
        case "loseFat":    return stats.weight * 2.2
        case "gainMuscle": return stats.weight * 2.0
        case "leanGain":   return stats.weight * 1.8
        default:           return stats.weight * 1.5
        }
    }
    var dailyCalories: Double {
        switch stats.goalType {
        case "loseFat":    return stats.tdee - 300
        case "gainMuscle": return stats.tdee + 300
        case "leanGain":   return stats.tdee + 150
        default:           return stats.tdee
        }
    }
    var dailyCarbs: Double {
        let remaining = dailyCalories - dailyProtein * 4 - dailyFats * 9
        return max(0, remaining / 4)
    }
    var dailyFats: Double {
        switch stats.macroSplit {
        case "keto":        return (dailyCalories * 0.70) / 9
        case "highCarb":    return (dailyCalories * 0.20) / 9
        default:            return (dailyCalories * 0.25) / 9
        }
    }
    var dailyFiber: Double { max(25, dailyCalories / 1000 * 14) }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                // Profile card
                AuraCard {
                    HStack(spacing: AuraSpacing.s4) {
                        VStack(spacing: 4) {
                            Text("\(Int(stats.height)) cm")
                                .font(AuraFont.statNum(size: 16))
                                .foregroundColor(.aura.text)
                            Text("Height")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                        Divider()
                        VStack(spacing: 4) {
                            Text("\(String(format: "%.0f", stats.weight)) kg")
                                .font(AuraFont.statNum(size: 16))
                                .foregroundColor(.aura.text)
                            Text("Weight")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                        Divider()
                        VStack(spacing: 4) {
                            Text("\(stats.age)")
                                .font(AuraFont.statNum(size: 16))
                                .foregroundColor(.aura.text)
                            Text("Age")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                        Divider()
                        VStack(spacing: 4) {
                            Text(stats.sex)
                                .font(AuraFont.statNum(size: 14))
                                .foregroundColor(.aura.text)
                            Text("Sex")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AuraSpacing.s4)
                }

                // BMI & TDEE
                HStack(spacing: AuraSpacing.s3) {
                    StatTile(value: String(format: "%.1f", stats.bmi), label: "BMI", color: bmiColor)
                    StatTile(value: "\(Int(stats.tdee))", label: "TDEE (kcal)", color: .aura.accent)
                }

                // Goal chips
                AuraSectionLabel(title: "Goal")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AuraSpacing.s2) {
                        ForEach(Array(zip(goals, goalLabels)), id: \.0) { key, label in
                            AuraChip(label: label, active: appState.bodyStats.goalType == key) {
                                appState.bodyStats.goalType = key
                            }
                        }
                    }
                }

                // Macro split chips
                AuraSectionLabel(title: "Macro Split")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AuraSpacing.s2) {
                        ForEach(Array(zip(macroSplits, macroLabels)), id: \.0) { key, label in
                            AuraChip(label: label, active: appState.bodyStats.macroSplit == key) {
                                appState.bodyStats.macroSplit = key
                            }
                        }
                    }
                }

                // Daily targets
                AuraSectionLabel(title: "Daily Targets")
                AuraCard {
                    VStack(spacing: AuraSpacing.s3) {
                        macroRow("Calories", value: "\(Int(dailyCalories)) kcal", color: .aura.accent, fraction: 1.0)
                        Divider()
                        macroRow("Protein", value: "\(Int(dailyProtein)) g", color: .aura.red,
                                 fraction: macroCalorieFraction(grams: dailyProtein, perGram: 4))
                        Divider()
                        macroRow("Carbs", value: "\(Int(dailyCarbs)) g", color: .aura.accent,
                                 fraction: macroCalorieFraction(grams: dailyCarbs, perGram: 4))
                        Divider()
                        macroRow("Fats", value: "\(Int(dailyFats)) g", color: .aura.blue,
                                 fraction: macroCalorieFraction(grams: dailyFats, perGram: 9))
                        Divider()
                        macroRow("Fiber", value: "\(Int(dailyFiber)) g", color: .aura.green,
                                 fraction: min(1, dailyFiber / 50))
                    }
                    .padding(AuraSpacing.s4)
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
        }
        .background(Color.aura.bgGrouped)
    }

    var bmiColor: Color {
        let bmi = stats.bmi
        if bmi < 18.5 { return .aura.blue }
        if bmi < 25 { return .aura.green }
        if bmi < 30 { return .aura.accent }
        return .aura.red
    }

    /// Share of total daily calories this macro contributes (0–1).
    private func macroCalorieFraction(grams: Double, perGram: Double) -> Double {
        guard dailyCalories > 0 else { return 0 }
        return min(1, (grams * perGram) / dailyCalories)
    }

    @ViewBuilder
    private func macroRow(_ label: String, value: String, color: Color, fraction: Double) -> some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: AuraSpacing.s2) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text)
                }
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(color)
            }
            AuraProgressBar(value: fraction, color: color, height: 5)
        }
    }
}
