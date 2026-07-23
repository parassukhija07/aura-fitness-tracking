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

    /// Every derived figure is meaningless until height + weight are set.
    private var hasDetails: Bool { stats.hasCompleteDetails }

    // MARK: Weight series (canonical kg → display unit)
    private var weightEntries: [(date: Date, kg: Double)] {
        appState.measurements
            .sorted { $0.date < $1.date }
            .compactMap { m -> (date: Date, kg: Double)? in
                guard let kg = m.weight else { return nil }
                return (date: m.date, kg: kg)
            }
    }

    private var weightChartData: [Double] {
        weightEntries.map { UnitFormatter.weightValue($0.kg, unit: appState.weightUnit) }
    }

    /// At most 4 evenly spaced date labels so the axis never crowds.
    private var weightChartLabels: [String] {
        // Key paths do not apply to tuple members — use an explicit closure.
        let dates = weightEntries.map { $0.date }
        guard !dates.isEmpty else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        guard dates.count > 4 else { return dates.map { fmt.string(from: $0) } }
        let step = Double(dates.count - 1) / 3
        return (0..<4).map { fmt.string(from: dates[Int((Double($0) * step).rounded())]) }
    }

    var body: some View {
        AuraScreenScroll(bottomClearance: 0) {
            VStack(spacing: AuraSpacing.s4) {
                bodyWeightCard
                detailsHeader
                detailsGrid
                statTiles
                goalSection
                macroSection
                dailyTargetCard
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

    // MARK: 1 — Weight trend + target badge
    private var bodyWeightCard: some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Body Weight")
                            .font(AuraFont.sectionLabel())
                            .foregroundColor(.aura.text3)
                        Text(UnitFormatter.weightNumber(stats.weight, unit: appState.weightUnit))
                            .font(AuraFont.statNum(size: 28))
                            .foregroundColor(.aura.text)
                            +
                            Text(" \(appState.weightUnit)")
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text2)
                    }
                    Spacer()
                    Text("Target \(UnitFormatter.weight(stats.targetWeight, unit: appState.weightUnit))")
                        .font(AuraFont.jakarta(12, .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.aura.accent)
                        .clipShape(Capsule())
                }
                if weightChartData.count >= 2 {
                    AuraAxisChart(
                        points: weightChartData,
                        xLabels: weightChartLabels,
                        // Points are already in the display unit — axis ticks
                        // only need rounding, not a second conversion.
                        valueFormatter: { String(format: "%.0f", $0) },
                        height: 140
                    )
                } else {
                    RoundedRectangle(cornerRadius: AuraRadius.sm)
                        .fill(Color.aura.fill)
                        .frame(height: 110)
                        .overlay {
                            Text("Log more measurements to see trend")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text3)
                        }
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    // MARK: 2 — Your details
    private var detailsHeader: some View {
        HStack {
            Text("Your Details").sectionLabelStyle()
            Spacer()
            Button { showDetailsEdit = true } label: {
                Text("Edit")
                    .font(AuraFont.jakarta(13, .semibold))
                    .foregroundColor(.aura.accent)
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
    }

    private var detailsGrid: some View {
        AuraCard {
            VStack(spacing: AuraSpacing.s3) {
                HStack(spacing: AuraSpacing.s4) {
                    detailCol("Height", UnitFormatter.length(stats.height, unit: appState.lengthUnit))
                    Divider()
                    detailCol("Weight", UnitFormatter.weight(stats.weight, unit: appState.weightUnit))
                    Divider()
                    detailCol("Age", "\(stats.age)")
                }
                Divider()
                HStack(spacing: AuraSpacing.s4) {
                    detailCol("Sex", stats.sex)
                    Divider()
                    detailCol("Activity", stats.activityLevel)
                    Divider()
                    detailCol("Target", UnitFormatter.weight(stats.targetWeight, unit: appState.weightUnit))
                }
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
                .font(AuraFont.jakarta(15, .bold))
                .foregroundColor(.aura.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: 3 — BMI & TDEE
    private var statTiles: some View {
        VStack(spacing: AuraSpacing.s2) {
            HStack(spacing: AuraSpacing.s3) {
                StatTile(
                    value: hasDetails ? String(format: "%.1f", stats.bmi) : "—",
                    label: hasDetails ? bmiLabel : "BMI",
                    color: hasDetails ? bmiColor : .aura.text3
                )
                StatTile(
                    value: hasDetails ? "\(Int(stats.tdee))" : "—",
                    label: "TDEE (kcal)",
                    color: hasDetails ? .aura.accent : .aura.text3
                )
            }
            if !hasDetails {
                Text("Complete your details to calculate targets")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: 4 — Goal chips
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

    // MARK: 5 — Macro split chips
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

    // MARK: 6 — Daily target card
    private let proteinColor = Color.aura.red
    private let carbColor    = Color.aura.blue
    private let fatColor     = Color.aura.purple

    /// Share of `targetCalories` each macro contributes — protein/carbs 4 kcal/g,
    /// fats 9 kcal/g. Zero when there is nothing to calculate.
    private var macroFractions: (protein: Double, carbs: Double, fats: Double) {
        let p = Double(macros.protein) * 4
        let c = Double(macros.carbs) * 4
        let f = Double(macros.fats) * 9
        let total = p + c + f
        guard total > 0 else { return (0, 0, 0) }
        return (p / total, c / total, f / total)
    }

    private var dailyTargetCard: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Daily Targets")
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(hasDetails ? "\(Int(cal))" : "—")
                        .font(AuraFont.statNum(size: 34))
                        .foregroundColor(.aura.text)
                    Text("kcal")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text2)
                    Spacer()
                }

                if hasDetails {
                    macroBar
                    HStack(spacing: AuraSpacing.s3) {
                        macroValue("Protein", grams: macros.protein, color: proteinColor)
                        macroValue("Carbs", grams: macros.carbs, color: carbColor)
                        macroValue("Fats", grams: macros.fats, color: fatColor)
                        macroValue("Fiber", grams: macros.fiber, color: .aura.green)
                    }
                } else {
                    Text("Complete your details to calculate targets")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text3)
                }
            }
            .padding(AuraSpacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.aura.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
        }
    }

    /// One bar, three proportional segments (protein · carbs · fats).
    private var macroBar: some View {
        let f = macroFractions
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(proteinColor).frame(width: geo.size.width * f.protein)
                Rectangle().fill(carbColor).frame(width: geo.size.width * f.carbs)
                Rectangle().fill(fatColor).frame(width: geo.size.width * f.fats)
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
    }

    private func macroValue(_ label: String, grams: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(label)
                    .font(AuraFont.sectionLabel())
                    .foregroundColor(.aura.text3)
            }
            Text("\(grams) g")
                .font(AuraFont.jakarta(16, .bold))
                .foregroundColor(.aura.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Edit sheet
    @ViewBuilder
    private func editDetailsSheet() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Your Details")
                    .font(AuraFont.jakarta(17, .bold))
                    .foregroundColor(.aura.text)
                Spacer()
                Button { showDetailsEdit = false } label: {
                    Image(systemName: "xmark")
                        .font(AuraFont.jakarta(16, .semibold))
                        .foregroundColor(.aura.text3)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, AuraSpacing.screenPad)

            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    VStack(spacing: AuraSpacing.s3) {
                        lengthStepper("Height", value: $appState.bodyStats.height)
                        Divider()
                        weightStepper("Weight", value: $appState.bodyStats.weight)
                        Divider()
                        ageStepper
                        Divider()
                        weightStepper("Target Weight", value: $appState.bodyStats.targetWeight)
                    }
                    .padding(AuraSpacing.s4)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))

                    Text("Sex").sectionLabelStyle()
                    HStack(spacing: AuraSpacing.s3) {
                        ForEach(["Male", "Female"], id: \.self) { sex in
                            Button {
                                appState.bodyStats.sex = sex
                                appState.syncProfileFromBodyStats()
                            } label: {
                                Text(sex)
                                    .font(AuraFont.jakarta(14, .bold))
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
                                        .font(AuraFont.jakarta(14, .semibold))
                                        .foregroundColor(stats.activityLevel == level ? .aura.accent : .aura.text)
                                    Spacer()
                                    if stats.activityLevel == level {
                                        Image(systemName: "checkmark")
                                            .font(AuraFont.jakarta(14, .bold))
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

    // MARK: Steppers — display in the user's unit, store canonical cm/kg.

    /// Steps by 1 in the *display* unit; clamped against the canonical kg range.
    private func weightStepper(_ label: String, value: Binding<Double>) -> some View {
        let unit = appState.weightUnit
        let stepKg = unit == "lb" ? UnitFormatter.kgPerLb : 1
        let range = NutritionConstants.weightRangeKg
        return stepperRow(
            label: label,
            display: UnitFormatter.weight(value.wrappedValue, unit: unit),
            canDecrement: value.wrappedValue > range.lowerBound,
            canIncrement: value.wrappedValue < range.upperBound,
            onStep: { delta in
                value.wrappedValue = clamp(value.wrappedValue + delta * stepKg, to: range)
            }
        )
    }

    private func lengthStepper(_ label: String, value: Binding<Double>) -> some View {
        let unit = appState.lengthUnit
        let stepCm = unit == "in" ? UnitFormatter.cmPerInch : 1
        let range = NutritionConstants.heightRangeCm
        return stepperRow(
            label: label,
            display: UnitFormatter.length(value.wrappedValue, unit: unit),
            canDecrement: value.wrappedValue > range.lowerBound,
            canIncrement: value.wrappedValue < range.upperBound,
            onStep: { delta in
                value.wrappedValue = clamp(value.wrappedValue + delta * stepCm, to: range)
            }
        )
    }

    /// Age round-trips to Profile's birthday via the existing sync function.
    private var ageStepper: some View {
        let range = NutritionConstants.ageRange
        return stepperRow(
            label: "Age",
            display: "\(stats.age)",
            canDecrement: stats.age > range.lowerBound,
            canIncrement: stats.age < range.upperBound,
            onStep: { delta in
                appState.bodyStats.age = min(max(stats.age + Int(delta), range.lowerBound), range.upperBound)
                appState.syncProfileFromBodyStats()
            }
        )
    }

    private func stepperRow(
        label: String,
        display: String,
        canDecrement: Bool,
        canIncrement: Bool,
        onStep: @escaping (Double) -> Void
    ) -> some View {
        HStack {
            Text(label).font(AuraFont.body()).foregroundColor(.aura.text)
            Spacer()
            Text(display)
                .font(AuraFont.jakarta(15, .bold))
                .foregroundColor(.aura.accent)
                .frame(minWidth: 74, alignment: .trailing)
            HStack(spacing: 6) {
                stepButton("minus", enabled: canDecrement) { onStep(-1) }
                stepButton("plus", enabled: canIncrement) { onStep(1) }
            }
            .padding(.leading, AuraSpacing.s2)
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AuraFont.jakarta(13, .bold))
                .foregroundColor(enabled ? .aura.text : .aura.text3)
                .frame(width: 30, height: 30)
                .background(Color.aura.fill)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        }
        .disabled(!enabled)
    }

    private func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
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
}
