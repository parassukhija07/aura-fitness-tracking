import SwiftUI

struct MeasurementsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLog = false
    @State private var showPhotos = false

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
                // Weight card
                AuraCard {
                    VStack(spacing: AuraSpacing.s3) {
                        HStack {
                            Text("Weight")
                                .sectionLabelStyle()
                            Spacer()
                            if let trend = weightTrend {
                                let isDown = trend < 0
                                HStack(spacing: 2) {
                                    Image(systemName: isDown ? "arrow.down" : "arrow.up")
                                    Text("\(abs(trend), specifier: "%.1f") \(appState.weightUnit)")
                                }
                                .font(AuraFont.badge())
                                .foregroundColor(isDown ? .aura.green : .aura.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((isDown ? Color.aura.green : Color.aura.red).opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }

                        if let w = latestMeasurement?.weight {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(w, specifier: "%.1f")")
                                    .font(AuraFont.statNum(size: 36))
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

                        // Mini chart placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: AuraRadius.sm)
                                .fill(Color.aura.fill)
                                .frame(height: 60)
                            Text("Weight trend chart")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text3)
                        }
                    }
                    .padding(AuraSpacing.s4)
                }

                // Body composition tiles
                HStack(spacing: AuraSpacing.s3) {
                    measureTile("Body Fat", value: latestMeasurement?.bodyFatPct.map { "\($0, specifier: "%.1f")%" })
                    measureTile("Lean Mass", value: {
                        guard let w = latestMeasurement?.weight,
                              let bf = latestMeasurement?.bodyFatPct else { return nil }
                        return "\(w * (1 - bf/100), specifier: "%.1f") kg"
                    }())
                }

                // Circumferences
                AuraSectionLabel(title: "Circumferences")

                AuraCard {
                    VStack(spacing: 0) {
                        let latest = latestMeasurement
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
                                    Text("\(v, specifier: "%.1f") \(appState.lengthUnit)")
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

                // Action buttons
                HStack(spacing: AuraSpacing.s3) {
                    AuraPrimaryButton(label: "Log Measurement", icon: "plus") {
                        showLog = true
                    }
                    AuraTintedButton(label: "Progress Photos") {
                        showPhotos = true
                    }
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
    }

    @ViewBuilder
    private func measureTile(_ label: String, value: String?) -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(AuraFont.sectionLabel())
                    .foregroundColor(.aura.text3)
                Text(value ?? "–")
                    .font(AuraFont.statNum(size: 20))
                    .foregroundColor(.aura.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AuraSpacing.s3)
        }
    }
}
