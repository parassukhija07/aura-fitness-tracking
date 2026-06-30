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
    let measurementUnits = ["kg", "%", "cm", "cm", "cm", "cm", "cm", "cm", "cm"]

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
        sorted.compactMap { $0.weight }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
<<<<<<< HEAD
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
                                Text(String(format: "%.1f", w))
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
                            Text(String(format: "%.1f %@ / 30d", abs(delta), appState.weightUnit))
                                .font(.system(size: 12, weight: .bold))
=======
                // Measurement selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(zip(measurements, measurementLabels)), id: \.0) { metric, label in
                            Button {
                                selectedMetric = metric
                            } label: {
                                Text(label)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedMetric == metric ? .white : .aura.text2)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedMetric == metric ? Color.aura.accent : Color.aura.fill)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                }

                // Selected measurement card
                AuraCard {
                    VStack(spacing: AuraSpacing.s3) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(measurementLabel(selectedMetric))
                                    .font(AuraFont.sectionLabel())
                                    .foregroundColor(.aura.text3)
                                Text("78.4")
                                    .font(AuraFont.statNum(size: 30))
                                    .foregroundColor(.aura.text)
                                    +
                                    Text(" \(measurementUnit(selectedMetric))")
                                        .font(AuraFont.body())
                                        .foregroundColor(.aura.text2)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Button {
                                    showHowTo = true
                                } label: {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.aura.accent)
                                        .frame(width: 30, height: 30)
                                }
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.up")
                                    Text("+2.2")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.aura.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.aura.green.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }

                        // Chart placeholder
                        RoundedRectangle(cornerRadius: AuraRadius.sm)
                            .fill(Color.aura.fill)
                            .frame(height: 140)
                            .overlay {
                                Text("Trend chart")
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text3)
                            }

                        // Range selector
                        HStack(spacing: 5) {
                            ForEach(["1m", "3m", "6m", "1y"], id: \.self) { range in
                                Button {
                                    selectedRange = range
                                } label: {
                                    Text(range.uppercased())
                                        .font(.system(size: 12, weight: .bold))
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
                    }
                    .padding(AuraSpacing.s4)
                }

                // Current measurements grid
                AuraSectionLabel(title: "Current Measurements")

                AuraCard {
                    VStack(spacing: 0) {
                        ForEach(Array(zip(measurements, zip(measurementLabels, measurementUnits))), id: \.0) { metric, labels in
                            VStack {
                                HStack {
                                    Text(labels.0)
                                        .font(AuraFont.body())
                                        .foregroundColor(.aura.text)
                                    Spacer()
                                    Button { selectedMetric = metric } label: {
                                        Text("78.4 \(labels.1)")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.aura.text)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, AuraSpacing.s4)
                                if metric != "hips" {
                                    Divider().padding(.leading, AuraSpacing.s4)
                                }
                            }
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
                        }
                        .foregroundColor(down ? .aura.green : .aura.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background((down ? Color.aura.green : Color.aura.red).opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

<<<<<<< HEAD
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
=======
                // Log button
                AuraPrimaryButton(label: "Log Measurements", icon: "plus") {
                    showLog = true
                }

                // History
                AuraSectionLabel(title: "History")

                AuraCard {
                    VStack(spacing: 0) {
                        ForEach([
                            ("Jun 18", "Weight 78.2 · Waist 82.1"),
                            ("Jun 11", "Weight 78.0 · Arms 38.4"),
                            ("Jun 4", "Weight 77.9 · Chest 103.5")
                        ], id: \.0) { date, note in
                            VStack {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(date)
                                            .font(AuraFont.body())
                                            .foregroundColor(.aura.text)
                                            .fontWeight(.semibold)
                                        Text(note)
                                            .font(AuraFont.secondary())
                                            .foregroundColor(.aura.text2)
                                    }
                                    Spacer()
                                    Image(systemName: "calendar.circle")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.aura.text2)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, AuraSpacing.s4)
                            }
                        }
                    }
                }

                // Photo progress
                AuraSectionLabel(title: "Photo Progress")

                AuraCard {
                    VStack(spacing: AuraSpacing.s3) {
                        HStack(spacing: AuraSpacing.s3) {
                            ForEach([("May 1", "76.2 kg"), ("Jun 25", "78.4 kg")], id: \.0) { date, weight in
                                VStack {
                                    RoundedRectangle(cornerRadius: AuraRadius.md)
                                        .fill(Color.aura.fill)
                                        .frame(height: 180)
                                        .overlay {
                                            VStack(spacing: 6) {
                                                Image(systemName: "person")
                                                    .font(.system(size: 26, weight: .semibold))
                                                    .foregroundColor(.aura.text3)
                                                Text("\(date) · \(weight)")
                                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                    .foregroundColor(.aura.text3)
                                            }
                                        }
                                    Text(date)
                                        .font(AuraFont.secondary())
                                        .foregroundColor(.aura.text2)
                                }
                            }
                        }

                        AuraTintedButton(label: "Add Comparison Photo", icon: "plus") {
                            showPhotos = true
                        }
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
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
                value: leanMass.map { String(format: "%.1f kg", $0) },
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
<<<<<<< HEAD
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
=======
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
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
            }
        }
        .background(Color.aura.bgGrouped)
    }

    private func measurementLabel(_ metric: String) -> String {
        guard let idx = measurements.firstIndex(of: metric) else { return metric }
        return measurementLabels[idx]
    }

    private func measurementUnit(_ metric: String) -> String {
        guard let idx = measurements.firstIndex(of: metric) else { return "" }
        return measurementUnits[idx]
    }

    // MARK: Circumferences
    private var circumferencesCard: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
            AuraSectionLabel(title: "Circumferences")
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
                                Text(String(format: "%.1f \(appState.lengthUnit)", v))
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
