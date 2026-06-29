import SwiftUI

struct MeasurementsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLog = false
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

    var latestMeasurement: Measurement? {
        appState.measurements.sorted { $0.date > $1.date }.first
    }

    var weightTrend: Double? {
        let wts = appState.measurements.sorted { $0.date < $1.date }.compactMap { $0.weight }
        guard wts.count >= 2 else { return nil }
        return wts.last! - wts.first!
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
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
                        }
                    }
                }

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
                    }
                    .padding(AuraSpacing.s4)
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
        }
        .background(Color.aura.bgGrouped)
        .sheet(isPresented: $showLog) {
            LogMeasurementSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPhotos) {
            ProgressPhotosView()
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
        guard let idx = measurements.firstIndex(of: metric) else { return "" }
        return measurementUnits[idx]
    }
}
