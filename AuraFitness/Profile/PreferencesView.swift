import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section("General") {
                Picker("Dark Mode", selection: $appState.darkModePreference) {
                    ForEach(DarkModePreference.allCases, id: \.self) { pref in
                        Text(pref.label).tag(pref)
                    }
                }
                Picker("Start Week On", selection: $appState.calendarStartDay) {
                    Text("Sunday").tag(0)
                    Text("Monday").tag(1)
                }
                Picker("Log Display", selection: $appState.logDisplayMode) {
                    ForEach(["Strength Score","Strength Balance","Both"], id: \.self) { Text($0) }
                }
            }

            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $appState.notificationsEnabled)
                Picker("Rest Timer Sound", selection: $appState.restSound) {
                    Text("Ding").tag("Ding")
                    Text("Alarm").tag("Alarm")
                }
                .disabled(!appState.notificationsEnabled)
            }

            Section("Units") {
                Picker("Weight Unit", selection: $appState.weightUnit) {
                    Text("kg").tag("kg")
                    Text("lb").tag("lb")
                }
                Picker("Length Unit", selection: $appState.lengthUnit) {
                    Text("cm").tag("cm")
                    Text("in").tag("in")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.aura.accent)
    }
}
