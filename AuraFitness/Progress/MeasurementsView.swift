import SwiftUI

struct MeasurementsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLog = false
    @State private var showHistory = false
    @State private var showPhotos = false
    @State private var showHowTo = false
    @State private var selectedMetric = "weight"
    @State private var selectedRange = "6m"

    let measurements = ["weight", "bodyFat", "chest", "waist", "arms", "thighs", "shoulders", "neck", "hips"]
    let measurementLabels = ["Weight", "Body fat", "Chest", "Waist", "Arms", "Thighs", "Shoulders", "Neck", "Hips"]

    /// Chips surface the first 7 metrics; neck + hips are reachable from the
    /// grid below, which covers all 9.
    private var chipMetrics: ArraySlice<String> { measurements.prefix(7) }

    /// Metrics where a DOWNWARD move is the improvement.
    private static let lowerIsBetter: Set<String> = ["waist", "bodyFat", "hips"]

    let measurementHowTo = [
        ("Chest", "Around the fullest part, under the armpits, arms relaxed."),
        ("Waist", "At the narrowest point, usually just above the navel."),
        ("Arms", "Flexed bicep at its peak, mid-upper arm."),
        ("Thighs", "Around the largest part of the upper thigh."),
        ("Shoulders", "Around the widest part, over the deltoids."),
        ("Neck", "At the middle, just below the Adam's apple."),
    ]

    private var sorted: [Measurement] {
        appState.measurements.sorted { $0.date < $1.date }
    }
    private var latest: Measurement? { sorted.last }

    private var leanMass: Double? {
        guard let w = latest?.weight, let bf = latest?.bodyFatPct else { return nil }
        return w * (1 - bf / 100)
    }

    // MARK: - Series

    private func value(_ m: Measurement, _ metric: String) -> Double? {
        switch metric {
        case "weight":    return m.weight
        case "bodyFat":   return m.bodyFatPct
        case "chest":     return m.chest
        case "waist":     return m.waist
        case "arms":      return m.arms
        case "thighs":    return m.thighs
        case "shoulders": return m.shoulders
        case "neck":      return m.neck
        case "hips":      return m.hips
        default:          return nil
        }
    }

    /// Every recorded value for a metric, oldest first. Entries that never
    /// touched this metric are `nil` and drop out — that is the partial-save
    /// contract showing through.
    private func series(_ metric: String) -> [(date: Date, value: Double)] {
        sorted.compactMap { m in value(m, metric).map { (m.date, $0) } }
    }

    private var rangeDays: Int {
        switch selectedRange {
        case "1m": return 30
        case "3m": return 90
        case "6m": return 180
        default:   return 365
        }
    }

    /// The visible window. Empty is a legitimate state (e.g. 1M selected but
    /// the last log was 3 months ago) — the chart shows its empty copy.
    private func rangedSeries(_ metric: String) -> [(date: Date, value: Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date()) ?? Date()
        return series(metric).filter { $0.date >= cutoff }
    }

    // MARK: - Formatting (canonical kg/cm in, display units out)

    private func label(_ metric: String) -> String {
        guard let idx = measurements.firstIndex(of: metric) else { return metric }
        return measurementLabels[idx]
    }

    private func displayValue(_ v: Double, _ metric: String) -> Double {
        switch metric {
        case "weight":  return UnitFormatter.weightValue(v, unit: appState.weightUnit)
        case "bodyFat": return v
        default:        return UnitFormatter.lengthValue(v, unit: appState.lengthUnit)
        }
    }

    private func formatted(_ v: Double, _ metric: String) -> String {
        switch metric {
        case "weight":  return UnitFormatter.weight(v, unit: appState.weightUnit)
        case "bodyFat": return String(format: "%.1f%%", v)
        default:        return UnitFormatter.length(v, unit: appState.lengthUnit)
        }
    }

    /// Axis tick label — `v` has already been converted to display units.
    private func axisTickLabel(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.1f", v)
    }

    /// Up to 4 short month names sampled evenly across the plotted points.
    private func chartLabels(_ pts: [(date: Date, value: Double)]) -> [String] {
        guard !pts.isEmpty else { return [] }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        let count = min(4, pts.count)
        return (0..<count).map { i in
            let idx = count == 1
                ? pts.count - 1
                : Int((Double(i) * Double(pts.count - 1) / Double(count - 1)).rounded())
            return fmt.string(from: pts[idx].date)
        }
    }

    var body: some View {
        AuraScreenScroll(bottomClearance: 0) {
            VStack(spacing: AuraSpacing.s4) {
                metricChips
                heroCard
                measurementGrid
                actionButtons
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)
        }
        .background(Color.aura.bgGrouped)
        .sheet(isPresented: $showLog) {
            LogMeasurementSheet()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPhotos) {
            ProgressPhotosView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showHistory) {
            historySheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHowTo) {
            measurementHowToSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        // Honour a FAB deep link, then clear it so it fires only once.
        .onChange(of: appState.progressDeepLink) { _, link in consumeDeepLink(link) }
        .onAppear { consumeDeepLink(appState.progressDeepLink) }
    }

    private func consumeDeepLink(_ link: AppState.ProgressDeepLink?) {
        guard let link else { return }
        switch link {
        case .measurements: showLog = true
        case .photos:       showPhotos = true
        }
        appState.progressDeepLink = nil
    }

    // MARK: Metric chips
    private var metricChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AuraSpacing.s2) {
                ForEach(Array(chipMetrics), id: \.self) { metric in
                    AuraChip(label: label(metric), active: selectedMetric == metric) {
                        selectedMetric = metric
                    }
                }
            }
        }
    }

    // MARK: Hero card
    private var heroCard: some View {
        let all = series(selectedMetric)
        let ranged = rangedSeries(selectedMetric)
        let current = all.last?.value

        return AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label(selectedMetric).uppercased())
                            .font(AuraFont.jakarta(10, .bold))
                            .foregroundColor(.aura.text3)
                            .tracking(0.5)
                        Text(current.map { formatted($0, selectedMetric) } ?? "—")
                            .font(AuraFont.statNum(size: 32))
                            .foregroundColor(current == nil ? .aura.text3 : .aura.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if selectedMetric == "bodyFat", let lean = leanMass {
                            Text("Lean mass \(UnitFormatter.weight(lean, unit: appState.weightUnit))")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: AuraSpacing.s2) {
                        Button { showHowTo = true } label: {
                            Image(systemName: "questionmark.circle")
                                .font(AuraFont.jakarta(15, .semibold))
                                .foregroundColor(.aura.text3)
                        }
                        // Lifetime move: current vs the first value ever
                        // recorded for this metric. Needs two points.
                        if let first = all.first?.value, let current, all.count >= 2 {
                            deltaBadge(current - first, metric: selectedMetric)
                        }
                    }
                }

                if ranged.isEmpty {
                    ZStack {
                        RoundedRectangle(cornerRadius: AuraRadius.sm)
                            .fill(Color.aura.fill)
                            .frame(height: 80)
                        Text("Log more measurements to see trend")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text3)
                    }
                } else {
                    AuraAxisChart(
                        points: ranged.map { displayValue($0.value, selectedMetric) },
                        xLabels: chartLabels(ranged),
                        valueFormatter: axisTickLabel,
                        height: 100
                    )
                }

                rangeToggle(disabled: all.isEmpty)
            }
            .padding(AuraSpacing.s4)
        }
    }

    @ViewBuilder
    private func deltaBadge(_ delta: Double, metric: String) -> some View {
        let flat = delta == 0
        let improved = Self.lowerIsBetter.contains(metric) ? delta < 0 : delta > 0
        let tint: Color = flat ? .aura.text2 : (improved ? .aura.green : .aura.red)
        HStack(spacing: 3) {
            if !flat {
                Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                    .font(AuraFont.jakarta(11, .bold))
            }
            Text(flat ? "±0" : "\(delta > 0 ? "+" : "−")\(formatted(abs(delta), metric))")
                .font(AuraFont.jakarta(12, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }

    private func rangeToggle(disabled: Bool) -> some View {
        HStack(spacing: 5) {
            ForEach(["1m", "3m", "6m", "1y"], id: \.self) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.uppercased())
                        .font(AuraFont.jakarta(12, .bold))
                        .foregroundColor(selectedRange == range ? .aura.text : .aura.text3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selectedRange == range ? Color.aura.surface : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding(3)
        .background(Color.aura.fill)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }

    // MARK: Current measurements grid
    private var measurementGrid: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Current")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: AuraSpacing.s2
            ) {
                ForEach(measurements, id: \.self) { metric in
                    metricTile(metric)
                }
            }
        }
    }

    private func metricTile(_ metric: String) -> some View {
        let current = series(metric).last?.value
        let active = selectedMetric == metric
        return Button {
            selectedMetric = metric
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(label(metric).uppercased())
                    .font(AuraFont.jakarta(9, .bold))
                    .foregroundColor(.aura.text3)
                    .tracking(0.4)
                    .lineLimit(1)
                Text(current.map { formatted($0, metric) } ?? "—")
                    .font(AuraFont.statNum(size: 16))
                    .foregroundColor(current == nil ? .aura.text3 : .aura.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AuraSpacing.s3)
            .background(active ? Color.aura.accentSoft : Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.md)
                    .stroke(active ? Color.aura.accent : Color.aura.separator2, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: History
    private func historySummary(_ m: Measurement) -> String {
        let parts = measurements.compactMap { metric in
            value(m, metric).map { "\(label(metric)) \(formatted($0, metric))" }
        }
        return parts.isEmpty ? "No values recorded" : parts.joined(separator: " · ")
    }

    private var historySheet: some View {
        NavigationStack {
            Group {
                if sorted.isEmpty {
                    VStack(spacing: AuraSpacing.s3) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(AuraFont.jakarta(40))
                            .foregroundColor(.aura.text3)
                        Text("No measurements logged yet")
                            .font(AuraFont.body())
                            .foregroundColor(.aura.text2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    AuraScreenScroll {
                        VStack(spacing: AuraSpacing.s2) {
                            // Newest first; each row lists only the fields
                            // that entry actually recorded.
                            ForEach(Array(sorted.reversed())) { m in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(m.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(AuraFont.jakarta(14, .bold))
                                        .foregroundColor(.aura.text)
                                    Text(historySummary(m))
                                        .font(AuraFont.secondary())
                                        .foregroundColor(.aura.text2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(AuraSpacing.s3)
                                .background(Color.aura.surface)
                                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                            }
                        }
                        .padding(.horizontal, AuraSpacing.screenPad)
                        .padding(.top, AuraSpacing.s2)
                    }
                }
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showHistory = false }
                        .foregroundColor(.aura.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func measurementHowToSheet() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("How to Measure")
                    .font(AuraFont.jakarta(17, .bold))
                    .foregroundColor(.aura.text)
                Spacer()
                Button {
                    showHowTo = false
                } label: {
                    Image(systemName: "xmark")
                        .font(AuraFont.jakarta(16, .semibold))
                        .foregroundColor(.aura.text3)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, AuraSpacing.screenPad)

            ScrollView {
                VStack(spacing: AuraSpacing.s3) {
                    ForEach(measurementHowTo, id: \.0) { title, desc in
                        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                            HStack(spacing: AuraSpacing.s2) {
                                Image(systemName: "target")
                                    .font(AuraFont.jakarta(14, .semibold))
                                    .foregroundColor(.aura.accent)
                                Text(title)
                                    .font(AuraFont.jakarta(14, .bold))
                                    .foregroundColor(.aura.text)
                            }
                            Text(desc)
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                                .lineSpacing(1.5)
                        }
                        .padding(AuraSpacing.s3)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    }
                }
                .padding(AuraSpacing.screenPad)
            }
        }
        .background(Color.aura.bgGrouped)
    }

    private func measurementUnit(_ metric: String) -> String {
        switch metric {
        case "weight": return appState.weightUnit
        case "bodyFat": return "%"
        default: return appState.lengthUnit
        }
    }

    // MARK: Actions
    private var actionButtons: some View {
        VStack(spacing: AuraSpacing.s2) {
            HStack(spacing: AuraSpacing.s3) {
                AuraPrimaryButton(label: "Log", icon: "plus") { showLog = true }
                AuraGrayButton(label: "History", icon: "clock.arrow.circlepath") { showHistory = true }
            }
            AuraTintedButton(label: "Progress Photos", icon: "photo.stack") { showPhotos = true }
        }
    }
}
