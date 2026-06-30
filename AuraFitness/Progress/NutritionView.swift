import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var appState: AppState

    var stats: BodyStats { appState.bodyStats }
    let goals    = ["loseFat","leanGain","gainMuscle","maintain"]
    let goalLabels = ["Lose Fat","Lean Gain","Gain Muscle","Maintain"]
    let macroSplits  = ["balanced","highProtein","highCarb","keto"]
    let macroLabels  = ["Balanced","High Protein","High Carb","Keto"]

    // MARK: Macro math
    var dailyProtein: Double {
        switch stats.goalType {
        case "loseFat":    return stats.weight * 2.2
        case "gainMuscle": return stats.weight * 2.0
        case "leanGain":   return stats.weight * 1.8
        default:           return stats.weight * 1.5
        }
    }
    var dailyFats: Double {
        switch stats.macroSplit {
        case "keto":     return (dailyCalories * 0.70) / 9
        case "highCarb": return (dailyCalories * 0.20) / 9
        default:         return (dailyCalories * 0.25) / 9
        }
    }
    var dailyCarbs: Double {
        max(0, (dailyCalories - dailyProtein * 4 - dailyFats * 9) / 4)
    }
    var dailyFiber: Double { max(25, dailyCalories / 1000 * 14) }
    var dailyCalories: Double {
        switch stats.goalType {
        case "loseFat":    return stats.tdee - 300
        case "gainMuscle": return stats.tdee + 300
        case "leanGain":   return stats.tdee + 150
        default:           return stats.tdee
        }
    }
    var calorieDelta: Double { dailyCalories - stats.tdee }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                profileCard
                bmiTdeeRow
                goalSection
                macroSplitSection
                dailyTargetsCard
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)
        }
        .background(Color.aura.bgGrouped)
    }

    // MARK: Profile card
    private var profileCard: some View {
        AuraCard {
            VStack(spacing: AuraSpacing.s2) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Profile")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.aura.text)
                        Text("\(Int(stats.height)) cm · \(String(format: "%.1f", stats.weight)) kg · \(stats.age)y · \(stats.sex) · \(stats.activityLevel)")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                            .lineLimit(2)
                    }
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.aura.fill)
                            .frame(width: 46, height: 46)
                        Image(systemName: "person.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.aura.text3)
                    }
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    // MARK: BMI + TDEE tiles
    private var bmiTdeeRow: some View {
        HStack(spacing: AuraSpacing.s3) {
            AuraCard {
                VStack(spacing: 3) {
                    Text("BMI")
                        .font(AuraFont.sectionLabel())
                        .foregroundColor(.aura.text3)
                    Text(String(format: "%.1f", stats.bmi))
                        .font(AuraFont.statNum(size: 26))
                        .foregroundColor(.aura.text)
                    Text(bmiLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(bmiColor)
                }
                .frame(maxWidth: .infinity)
                .padding(AuraSpacing.s3)
            }
            AuraCard {
                VStack(spacing: 3) {
                    Text("TDEE")
                        .font(AuraFont.sectionLabel())
                        .foregroundColor(.aura.text3)
                    Text("\(Int(stats.tdee))")
                        .font(AuraFont.statNum(size: 26))
                        .foregroundColor(.aura.text)
                    Text("kcal/day")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                .frame(maxWidth: .infinity)
                .padding(AuraSpacing.s3)
            }
        }
    }

    // MARK: Goal chips
    private var goalSection: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
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
        }
    }

    // MARK: Macro split chips
    private var macroSplitSection: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
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
        }
    }

    // MARK: Daily targets card with progress bars
    private var dailyTargetsCard: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Daily Targets")
            AuraCard {
                VStack(spacing: AuraSpacing.s3) {
                    // Calories headline + surplus badge
                    HStack {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(dailyCalories))")
                                .font(AuraFont.statNum(size: 28))
                                .foregroundColor(.aura.text)
                            Text("kcal")
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text2)
                        }
                        Spacer()
                        let surplus = calorieDelta >= 0
                        HStack(spacing: 3) {
                            Text(surplus ? "+" : "")
                            Text("\(Int(abs(calorieDelta))) \(surplus ? "surplus" : "deficit")")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(surplus ? .aura.accent : .aura.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((surplus ? Color.aura.accent : Color.aura.green).opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Divider()

                    // Macro rows with progress bars
                    macroBarRow(
                        icon: "egg.fill", label: "Protein",
                        value: dailyProtein, unit: "g",
                        maxValue: max(dailyProtein, dailyCarbs, dailyFats),
                        color: .aura.accent
                    )
                    macroBarRow(
                        icon: "leaf.fill", label: "Carbs",
                        value: dailyCarbs, unit: "g",
                        maxValue: max(dailyProtein, dailyCarbs, dailyFats),
                        color: .aura.blue
                    )
                    macroBarRow(
                        icon: "drop.fill", label: "Fats",
                        value: dailyFats, unit: "g",
                        maxValue: max(dailyProtein, dailyCarbs, dailyFats),
                        color: .aura.purple
                    )
                    macroBarRow(
                        icon: "arrow.triangle.branch", label: "Fiber",
                        value: dailyFiber, unit: "g",
                        maxValue: max(dailyProtein, dailyCarbs, dailyFats),
                        color: .aura.green
                    )
                }
                .padding(AuraSpacing.s4)
            }
        }
    }

    @ViewBuilder
    private func macroBarRow(icon: String, label: String, value: Double, unit: String, maxValue: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(color)
                        .frame(width: 16)
                    Text(label)
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text)
                }
                Spacer()
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.aura.text)
            }
            AuraProgressBar(
                value: maxValue > 0 ? value / maxValue : 0,
                color: color,
                height: 6
            )
        }
    }

    // MARK: BMI helpers
    var bmiColor: Color {
        let b = stats.bmi
        if b < 18.5 { return .aura.blue }
        if b < 25   { return .aura.green }
        if b < 30   { return .aura.accent }
        return .aura.red
    }
    var bmiLabel: String {
        let b = stats.bmi
        if b < 18.5 { return "Underweight" }
        if b < 25   { return "Healthy" }
        if b < 30   { return "Overweight" }
        return "Obese"
    }
}
