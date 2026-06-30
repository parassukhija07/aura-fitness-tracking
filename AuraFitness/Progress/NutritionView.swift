import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDetailsEdit = false

<<<<<<< HEAD
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
=======
    private var stats: BodyStats { appState.bodyStats }

    // Goal / macro options come straight from the canonical constant tables.
    private var goalKeys: [String]  { NutritionConstants.goalAdjustments.map(\.label) }
    private var macroKeys: [String] { NutritionConstants.macroSplits.map(\.label) }
    private var activityKeys: [String] { NutritionConstants.activityMultipliers.map(\.label) }

    private var cal: Double { stats.targetCalories }
    private var macros: MacroTargets { stats.macros }
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
<<<<<<< HEAD
                profileCard
                bmiTdeeRow
                goalSection
                macroSplitSection
                dailyTargetsCard
=======
                bodyWeightCard
                detailsHeader
                detailsGrid
                statTiles
                goalSection
                macroSection
                dailyTargetsSection
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)
        }
        .background(Color.aura.bgGrouped)
        .sheet(isPresented: $showDetailsEdit) {
            editDetailsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

<<<<<<< HEAD
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
=======
    // MARK: Body weight card
    private var bodyWeightCard: some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Body Weight")
                            .font(AuraFont.sectionLabel())
                            .foregroundColor(.aura.text3)
                        Text("\(String(format: "%.1f", stats.weight))")
                            .font(AuraFont.statNum(size: 28))
                            .foregroundColor(.aura.text)
                            +
                            Text(" kg")
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text2)
                    }
                    Spacer()
                    Text("Target \(String(format: "%.0f", stats.targetWeight)) kg")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.aura.accent)
                        .clipShape(Capsule())
                }
                RoundedRectangle(cornerRadius: AuraRadius.sm)
                    .fill(Color.aura.fill)
                    .frame(height: 110)
                    .overlay {
                        Text("Weight trend chart")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text3)
                    }
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
            }
            .padding(AuraSpacing.s4)
        }
    }

<<<<<<< HEAD
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
=======
    private var detailsHeader: some View {
        HStack {
            Text("Your Details").sectionLabelStyle()
            Spacer()
            Button { showDetailsEdit = true } label: {
                Text("Edit")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.aura.accent)
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
    }

    private var detailsGrid: some View {
        AuraCard {
            HStack(spacing: AuraSpacing.s4) {
                detailCol("Height", "\(Int(stats.height)) cm")
                Divider()
                detailCol("Weight", "\(String(format: "%.1f", stats.weight)) kg")
                Divider()
                detailCol("Age", "\(stats.age)")
                Divider()
                detailCol("Sex", stats.sex)
            }
            .padding(AuraSpacing.s4)
        }
    }

    private func detailCol(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AuraFont.sectionLabel())
                .foregroundColor(.aura.text3)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.aura.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: BMI & TDEE
    private var statTiles: some View {
        HStack(spacing: AuraSpacing.s3) {
            StatTile(value: String(format: "%.1f", stats.bmi), label: bmiLabel, color: bmiColor)
            StatTile(value: "\(Int(stats.tdee))", label: "TDEE (kcal)", color: .aura.accent)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
        }
    }

    // MARK: Goal chips
    private var goalSection: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Goal")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
<<<<<<< HEAD
                    ForEach(Array(zip(goals, goalLabels)), id: \.0) { key, label in
                        AuraChip(label: label, active: appState.bodyStats.goalType == key) {
=======
                    ForEach(goalKeys, id: \.self) { key in
                        AuraChip(label: key, active: stats.goalType == key) {
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
                            appState.bodyStats.goalType = key
                        }
                    }
                }
            }
        }
    }

    // MARK: Macro split chips
<<<<<<< HEAD
    private var macroSplitSection: some View {
=======
    private var macroSection: some View {
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Macro Split")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
<<<<<<< HEAD
                    ForEach(Array(zip(macroSplits, macroLabels)), id: \.0) { key, label in
                        AuraChip(label: label, active: appState.bodyStats.macroSplit == key) {
=======
                    ForEach(macroKeys, id: \.self) { key in
                        AuraChip(label: key, active: stats.macroSplit == key) {
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
                            appState.bodyStats.macroSplit = key
                        }
                    }
                }
            }
        }
    }

<<<<<<< HEAD
    // MARK: Daily targets card with progress bars
    private var dailyTargetsCard: some View {
=======
    // MARK: Daily targets
    private var dailyTargetsSection: some View {
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Daily Targets")
            AuraCard {
                VStack(spacing: AuraSpacing.s3) {
<<<<<<< HEAD
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
=======
                    macroRow("Calories", value: "\(Int(cal)) kcal", color: .aura.accent, fraction: 1.0)
                    Divider()
                    macroRow("Protein", value: "\(macros.protein) g", color: .aura.red,
                             fraction: calorieFraction(grams: macros.protein, perGram: 4))
                    Divider()
                    macroRow("Carbs", value: "\(macros.carbs) g", color: .aura.accent,
                             fraction: calorieFraction(grams: macros.carbs, perGram: 4))
                    Divider()
                    macroRow("Fats", value: "\(macros.fats) g", color: .aura.blue,
                             fraction: calorieFraction(grams: macros.fats, perGram: 9))
                    Divider()
                    macroRow("Fiber", value: "\(macros.fiber) g", color: .aura.green,
                             fraction: min(1, Double(macros.fiber) / 50))
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
                }
                .padding(AuraSpacing.s4)
            }
        }
<<<<<<< HEAD
=======
    }

    // MARK: Edit sheet
    @ViewBuilder
    private func editDetailsSheet() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Details")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.aura.text)
                Spacer()
                Button { showDetailsEdit = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.aura.text3)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, AuraSpacing.screenPad)

            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    // Editable numeric fields
                    VStack(spacing: AuraSpacing.s3) {
                        editRow("Height (cm)", value: $appState.bodyStats.height, decimals: false)
                        editRow("Weight (kg)", value: $appState.bodyStats.weight, decimals: true)
                        editIntRow("Age", value: $appState.bodyStats.age)
                        editRow("Target Weight (kg)", value: $appState.bodyStats.targetWeight, decimals: true)
                    }
                    .padding(AuraSpacing.s4)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))

                    Text("Sex").sectionLabelStyle()
                    HStack(spacing: AuraSpacing.s3) {
                        ForEach(["Male", "Female"], id: \.self) { sex in
                            Button {
                                appState.bodyStats.sex = sex
                            } label: {
                                Text(sex)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(stats.sex == sex ? .white : .aura.text2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(stats.sex == sex ? Color.aura.text : Color.aura.fill)
                                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                            }
                        }
                    }

                    Text("Activity Level").sectionLabelStyle()
                    VStack(spacing: 6) {
                        ForEach(activityKeys, id: \.self) { level in
                            Button {
                                appState.bodyStats.activityLevel = level
                            } label: {
                                HStack {
                                    Text(level)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(stats.activityLevel == level ? .aura.accent : .aura.text)
                                    Spacer()
                                    if stats.activityLevel == level {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.aura.accent)
                                    }
                                }
                                .padding(.horizontal, AuraSpacing.s4)
                                .padding(.vertical, 12)
                                .background(Color.aura.surface)
                                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                            }
                        }
                    }

                    AuraPrimaryButton(label: "Done") { showDetailsEdit = false }
                }
                .padding(AuraSpacing.screenPad)
            }
        }
        .background(Color.aura.bgGrouped)
    }

    private func editRow(_ label: String, value: Binding<Double>, decimals: Bool) -> some View {
        HStack {
            Text(label).font(AuraFont.body()).foregroundColor(.aura.text)
            Spacer()
            TextField(label, value: value, format: decimals ? .number.precision(.fractionLength(1)) : .number.precision(.fractionLength(0)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.aura.accent)
                .frame(width: 90)
        }
    }

    private func editIntRow(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label).font(AuraFont.body()).foregroundColor(.aura.text)
            Spacer()
            TextField(label, value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.aura.accent)
                .frame(width: 90)
        }
    }

    // MARK: BMI helpers (<18.5/<25/<30/else)
    private var bmiLabel: String {
        let b = stats.bmi
        if b < 18.5 { return "BMI · Under" }
        if b < 25   { return "BMI · Normal" }
        if b < 30   { return "BMI · Over" }
        return "BMI · Obese"
    }
    private var bmiColor: Color {
        let b = stats.bmi
        if b < 18.5 { return .aura.blue }
        if b < 25   { return .aura.green }
        if b < 30   { return .aura.accent }
        return .aura.red
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
    }

    private func calorieFraction(grams: Int, perGram: Double) -> Double {
        guard cal > 0 else { return 0 }
        return min(1, (Double(grams) * perGram) / cal)
    }

    @ViewBuilder
<<<<<<< HEAD
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
=======
    private func macroRow(_ label: String, value: String, color: Color, fraction: Double) -> some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: AuraSpacing.s2) {
                    Circle().fill(color).frame(width: 8, height: 8)
                    Text(label).font(AuraFont.body()).foregroundColor(.aura.text)
                }
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(color)
            }
            AuraProgressBar(value: fraction, color: color, height: 5)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
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
