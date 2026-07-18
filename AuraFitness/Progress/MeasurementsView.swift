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

    // 30-day delta for weight
    private var weightDelta30: Double? {
        let wts = sorted.compactMap { m -> (Date, Double)? in
            guard let w = m.weight else { return nil }
            return (m.date, w)
        }
        guard wts.count >= 2 else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = wts.filter { $0.0 >= cutoff }
        guard let first = recent.first, let last = recent.last, first.1 != last.1 else {
            return wts.last.map { $0.1 - wts.first!.1 }
        }
        return last.1 - first.1
    }

    private var bodyFatDelta30: Double? {
        let vals = sorted.compactMap { m -> (Date, Double)? in
            guard let bf = m.bodyFatPct else { return nil }
            return (m.date, bf)
        }
        guard vals.count >= 2 else { return nil }
        return vals.last!.1 - vals.first!.1
    }

    private var leanMass: Double? {
        guard let w = latest?.weight, let bf = latest?.bodyFatPct else { return nil }
        return w * (1 - bf / 100)
    }

    private var weightChartData: [Double] {
        sorted.compactMap { $0.weight }.map { UnitFormatter.weightValue($0, unit: appState.weightUnit) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                weightCard
                compositionTiles
                circumferencesCard
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
    }

    // MARK: Weight card
    private var weightCard: some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WEIGHT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.aura.text3)
                            .tracking(0.5)
                        if let w = latest?.weight {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(UnitFormatter.weightNumber(w, unit: appState.weightUnit))
                                    .font(AuraFont.statNum(size: 32))
                                    .foregroundColor(.aura.text)
                                Text(appState.weightUnit)
                                    .font(AuraFont.body())
                                    .foregroundColor(.aura.text2)
                            }
                        } else {
                            Text("No data")
                                .font(AuraFont.statNum(size: 24))
                                .foregroundColor(.aura.text3)
                        }
                    }
                    Spacer()
                    if let delta = weightDelta30 {
                        let down = delta < 0
                        HStack(spacing: 3) {
                            Image(systemName: down ? "arrow.down" : "arrow.up")
                                .font(.system(size: 11, weight: .bold))
                            Text(String(format: "%.1f %@ / 30d", abs(UnitFormatter.weightValue(delta, unit: appState.weightUnit)), appState.weightUnit))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(down ? .aura.green : .aura.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((down ? Color.aura.green : Color.aura.red).opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                // Real weight chart
                if weightChartData.count >= 2 {
                    AuraLineChart(data: weightChartData, height: 80, showArea: true, showDot: true)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: AuraRadius.sm)
                            .fill(Color.aura.fill)
                            .frame(height: 60)
                        Text("Log more measurements to see trend")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text3)
                    }
                    .padding(AuraSpacing.s4)
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    // MARK: Body composition tiles
    private var compositionTiles: some View {
        HStack(spacing: AuraSpacing.s3) {
            compTile(
                label: "BODY FAT",
                value: latest?.bodyFatPct.map { String(format: "%.1f%%", $0) },
                delta: bodyFatDelta30.map { String(format: "%.1f%%", abs($0)) },
                deltaDown: (bodyFatDelta30 ?? 0) < 0
            )
            compTile(
                label: "LEAN MASS",
                value: leanMass.map { UnitFormatter.weight($0, unit: appState.weightUnit) },
                delta: nil,
                deltaDown: true
            )
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

    @ViewBuilder
    private func compTile(_ label: String, value: String?, delta: String?, deltaDown: Bool) -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.aura.text3)
                    .tracking(0.4)
                Text(value ?? "–")
                    .font(AuraFont.statNum(size: 22))
                    .foregroundColor(.aura.text)
                if let d = delta {
                    HStack(spacing: 2) {
                        Image(systemName: deltaDown ? "arrow.down" : "arrow.up")
                            .font(.system(size: 10, weight: .bold))
                        Text(d)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(deltaDown ? .aura.green : .aura.red)
                }
            }
            .padding(AuraSpacing.s3)
        }
    }

    @ViewBuilder
    private func measurementHowToSheet() -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("How to Measure")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.aura.text)
                Spacer()
                Button {
                    showHowTo = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
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
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.aura.accent)
                                Text(title)
                                    .font(.system(size: 14, weight: .bold))
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

    private func measurementLabel(_ metric: String) -> String {
        guard let idx = measurements.firstIndex(of: metric) else { return metric }
        return measurementLabels[idx]
    }

    private func measurementUnit(_ metric: String) -> String {
        switch metric {
        case "weight": return appState.weightUnit
        case "bodyFat": return "%"
        default: return appState.lengthUnit
        }
    }

    // MARK: Circumferences
    private var circumferencesCard: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            HStack {
                AuraSectionLabel(title: "Circumferences")
                Spacer()
                Button { showHowTo = true } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.aura.text3)
                }
            }
            AuraCard {
                VStack(spacing: 0) {
                    let items: [(String, Double?)] = [
                        ("Chest",     latest?.chest),
                        ("Waist",     latest?.waist),
                        ("Arms",      latest?.arms),
                        ("Thighs",    latest?.thighs),
                        ("Shoulders", latest?.shoulders),
                        ("Neck",      latest?.neck),
                        ("Hips",      latest?.hips),
                    ]
                    ForEach(items, id: \.0) { name, val in
                        HStack {
                            Text(name)
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text)
                            Spacer()
                            if let v = val {
                                Text(UnitFormatter.length(v, unit: appState.lengthUnit))
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.aura.text)
                            } else {
                                Text("–")
                                    .font(AuraFont.body())
                                    .foregroundColor(.aura.text3)
                            }
                        }
                        .padding(.horizontal, AuraSpacing.s4)
                        .padding(.vertical, 12)
                        if name != "Hips" { Divider().padding(.leading, AuraSpacing.s4) }
                    }
                }
            }
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
