import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDetailsEdit = false

    private var stats: BodyStats { appState.bodyStats }

    // Goal / macro options come straight from the canonical constant tables.
    private var goalKeys: [String]  { NutritionConstants.goalAdjustments.map(\.label) }
    private var macroKeys: [String] { NutritionConstants.macroSplits.map(\.label) }
    private var activityKeys: [String] { NutritionConstants.activityMultipliers.map(\.label) }

    private var cal: Double { stats.targetCalories }
    private var macros: MacroTargets { stats.macros }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                bodyWeightCard
                detailsHeader
                detailsGrid
                statTiles
                goalSection
                macroSection
                dailyTargetsSection
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
        }
        .background(Color.aura.bgGrouped)
        .sheet(isPresented: $showDetailsEdit) {
            editDetailsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

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
            }
            .padding(AuraSpacing.s4)
        }
    }

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
        }
    }

    // MARK: Goal chips
    private var goalSection: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Goal")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(goalKeys, id: \.self) { key in
                        AuraChip(label: key, active: stats.goalType == key) {
                            appState.bodyStats.goalType = key
                        }
                    }
                }
            }
        }
    }

    // MARK: Macro split chips
    private var macroSection: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Macro Split")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(macroKeys, id: \.self) { key in
                        AuraChip(label: key, active: stats.macroSplit == key) {
                            appState.bodyStats.macroSplit = key
                        }
                    }
                }
            }
        }
    }

    // MARK: Daily targets
    private var dailyTargetsSection: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Daily Targets")
            AuraCard {
                VStack(spacing: AuraSpacing.s3) {
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
                }
                .padding(AuraSpacing.s4)
            }
        }
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
    }

    private func calorieFraction(grams: Int, perGram: Double) -> Double {
        guard cal > 0 else { return 0 }
        return min(1, (Double(grams) * perGram) / cal)
    }

    @ViewBuilder
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
        }
    }
}
