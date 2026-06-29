import SwiftUI

struct WorkoutSettingsView: View {
    @EnvironmentObject var appState: AppState

    /// "Show first" seg maps the boolean showRepsFirst to "reps"/"weight".
    private var showFirst: Binding<String> {
        Binding(
            get: { appState.showRepsFirst ? "Reps / time" : "Weight" },
            set: { appState.showRepsFirst = ($0 == "Reps / time") }
        )
    }

    var body: some View {
        SettingsScreenScaffold(title: "Workout") {
            // ── Display ─────────────────────────────────────────────
            SettingsSectionLabel(title: "Display")
            SettingsGroup {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    Text("Show first")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text)
                    AuraSegmentedPicker(options: ["Reps / time", "Weight"], selection: showFirst)
                }
                .padding(AuraSpacing.s4)
                Divider().padding(.leading, AuraSpacing.s4)
                SettingsControlRow(title: "Show PRs during workout",
                                   subtitle: "Surface your records inline") {
                    AuraToggle(isOn: $appState.showPRsDuringWorkout)
                }
            }

            // ── Exercise targets ────────────────────────────────────
            SettingsSectionLabel(title: "Exercise targets")
            SettingsGroup {
                SettingsControlRow(title: "Default sets") {
                    AuraStepper(value: $appState.defaultSets, range: 1...10)
                }
                Divider().padding(.leading, AuraSpacing.s4)

                // Default rep range — two interlocked steppers (lo ≤ hi).
                SettingsControlRow(title: "Default rep range") {
                    HStack(spacing: AuraSpacing.s2) {
                        AuraStepper(value: $appState.defaultRepLow,
                                    range: 1...appState.defaultRepHigh)
                        Text("–").foregroundColor(.aura.text2)
                        AuraStepper(value: $appState.defaultRepHigh,
                                    range: appState.defaultRepLow...30)
                    }
                }
                Divider().padding(.leading, AuraSpacing.s4)

                SettingsControlRow(title: "Rest between sets") {
                    AuraStepper(value: $appState.defaultRestBetweenSets,
                                range: 15...300, step: 15, format: fmtRest)
                }
                Divider().padding(.leading, AuraSpacing.s4)
                SettingsControlRow(title: "Rest between exercises") {
                    AuraStepper(value: $appState.defaultRestBetweenExercises,
                                range: 15...300, step: 15, format: fmtRest)
                }
            }

            // ── Automation ──────────────────────────────────────────
            SettingsSectionLabel(title: "Automation")
            SettingsGroup {
                SettingsControlRow(title: "Auto rest timer",
                                   subtitle: "Start timer after each set") {
                    AuraToggle(isOn: $appState.autoRestTimer)
                }
                Divider().padding(.leading, AuraSpacing.s4)
                SettingsControlRow(title: "Auto-play video",
                                   subtitle: "Play demo when opening an exercise") {
                    AuraToggle(isOn: $appState.autoPlayVideo)
                }
            }
        }
    }
}
