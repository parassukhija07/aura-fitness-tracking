import SwiftUI

struct ProfileTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showWorkoutSettings = false
    @State private var showAccount = false
    @State private var showPreferences = false

    var totalSessions: Int { appState.workoutLogs.count }
    var totalPRs: Int { appState.personalRecords.count }
    var streak: Int {
        var count = 0
        var day = Date()
        let cal = Calendar.current
        while appState.hasLog(for: day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    var body: some View {
        NavigationStack {
            List {
                // Identity card
                Section {
                    HStack(spacing: AuraSpacing.s4) {
                        ZStack {
                            Circle()
                                .fill(Color.aura.accentSoft)
                                .frame(width: 64, height: 64)
                            Text("\(appState.userProfile.firstName.prefix(1))\(appState.userProfile.lastName.prefix(1))")
                                .font(.system(size: 22, weight: .heavy))
                                .foregroundColor(.aura.accent)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(appState.userProfile.firstName) \(appState.userProfile.lastName)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.aura.text)
                            HStack(spacing: AuraSpacing.s2) {
                                Text("\(appState.bodyStats.age) yrs")
                                Text("·")
                                Text("\(String(format: "%.0f", appState.bodyStats.height)) cm")
                                Text("·")
                                Text("\(String(format: "%.0f", appState.bodyStats.weight)) kg")
                            }
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                        }
                    }
                    .padding(.vertical, 8)

                    // Stats row
                    HStack {
                        profileStat("\(totalSessions)", label: "Sessions")
                        Divider()
                        profileStat("\(totalPRs)", label: "PRs")
                        Divider()
                        profileStat("\(streak)", label: "Streak")
                    }
                    .frame(height: 56)
                }
                .listRowBackground(Color.aura.surface)

                // Settings groups
                Section("Training") {
                    AuraListRow(iconName: "dumbbell.fill", iconColor: .aura.accent,
                                title: "Workout Settings",
                                subtitle: "Sets, rest times, display") { showWorkoutSettings = true }
                }
                .listRowBackground(Color.aura.surface)

                Section("Account") {
                    AuraListRow(iconName: "person.fill", iconColor: .aura.blue,
                                title: "Account Details") { showAccount = true }
                    AuraListRow(iconName: "gear", iconColor: .aura.text2,
                                title: "Preferences",
                                subtitle: "Dark mode, units, notifications") { showPreferences = true }
                    AuraListRow(iconName: "heart.fill", iconColor: .aura.red,
                                title: "Health Integrations") {}
                }
                .listRowBackground(Color.aura.surface)

                Section("Support") {
                    AuraListRow(iconName: "book.fill", iconColor: .aura.green,
                                title: "User Guides & FAQ") {}
                    AuraListRow(iconName: "envelope.fill", iconColor: .aura.blue,
                                title: "Contact Us") {}
                    AuraListRow(iconName: "lightbulb.fill", iconColor: .aura.accent,
                                title: "Request a Feature") {}
                }
                .listRowBackground(Color.aura.surface)

                Section {
                    Button {
                        // Log out
                    } label: {
                        Text("Log Out")
                            .font(AuraFont.body())
                            .foregroundColor(.aura.red)
                            .frame(maxWidth: .infinity)
                    }
                }
                .listRowBackground(Color.aura.surface)

                Section {
                    Text("Aura Fitness · v1.0.0")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text3)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .background(Color.aura.bgGrouped)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: AuraSpacing.tabBarClearance - 34)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showWorkoutSettings) {
                WorkoutSettingsView()
            }
            .navigationDestination(isPresented: $showAccount) {
                AccountDetailsView()
            }
            .navigationDestination(isPresented: $showPreferences) {
                PreferencesView()
            }
        }
    }

    @ViewBuilder
    private func profileStat(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AuraFont.statNum(size: 20))
                .foregroundColor(.aura.text)
            Text(label)
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
        }
        .frame(maxWidth: .infinity)
    }
}
