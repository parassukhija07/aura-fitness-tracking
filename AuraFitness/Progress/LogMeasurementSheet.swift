import SwiftUI

struct LogMeasurementSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var date = Date()
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var neck = ""
    @State private var chest = ""
    @State private var waist = ""
    @State private var hips = ""
    @State private var arms = ""
    @State private var thighs = ""
    @State private var shoulders = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Fill only what you measured — partial saves are allowed.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                Section("Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .tint(.aura.accent)
                }
                Section("Weight & Body Composition") {
                    numField("Weight (\(appState.weightUnit))", text: $weight)
                    numField("Body Fat %", text: $bodyFat)
                }
                Section("Circumferences (\(appState.lengthUnit))") {
                    numField("Neck", text: $neck)
                    numField("Chest", text: $chest)
                    numField("Waist", text: $waist)
                    numField("Hips", text: $hips)
                    numField("Arms", text: $arms)
                    numField("Thighs", text: $thighs)
                    numField("Shoulders", text: $shoulders)
                }
            }
            .navigationTitle("Log Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .foregroundColor(.aura.accent)
                }
            }
        }
    }

    @ViewBuilder
    private func numField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("–", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.aura.accent)
        }
    }

    private func save() {
        let m = Measurement(
            date: date,
            weight: UnitFormatter.parseWeightToKg(weight, unit: appState.weightUnit),
            bodyFatPct: Double(bodyFat),
            neck: UnitFormatter.parseLengthToCm(neck, unit: appState.lengthUnit),
            chest: UnitFormatter.parseLengthToCm(chest, unit: appState.lengthUnit),
            waist: UnitFormatter.parseLengthToCm(waist, unit: appState.lengthUnit),
            hips: UnitFormatter.parseLengthToCm(hips, unit: appState.lengthUnit),
            arms: UnitFormatter.parseLengthToCm(arms, unit: appState.lengthUnit),
            thighs: UnitFormatter.parseLengthToCm(thighs, unit: appState.lengthUnit),
            shoulders: UnitFormatter.parseLengthToCm(shoulders, unit: appState.lengthUnit)
        )
        appState.measurements.append(m)
    }
}
