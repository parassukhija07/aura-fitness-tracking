import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPRs = false
    @State private var showWeekly = false

    var totalSessions: Int { appState.workoutLogs.count }
    var totalSets: Int {
        appState.workoutLogs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }.count
    }
    var totalVolume: Double {
        appState.workoutLogs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }
            .reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
    }
    var totalPRs: Int { appState.personalRecords.count }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                // Heatmap
                ConsistencyHeatmapView()

                // Weekly volume card (tappable → WeeklyVolumeView)
                weeklyCard

                // This week muscles
                thisWeekMuscles

                // Lifetime stats
                AuraSectionLabel(title: "Lifetime")
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: AuraSpacing.s3
                ) {
                    StatTile(value: "\(totalSessions)", label: "Sessions", color: .aura.accent)
                    StatTile(value: "\(totalSets)", label: "Sets logged", color: .aura.blue)
                    StatTile(value: formatVolume(totalVolume), label: "Volume (kg)", color: .aura.green)
                    StatTile(value: "\(totalPRs)", label: "Personal records", color: .aura.purple)
                }

                // PRs button
                AuraTintedButton(label: "Personal Records", icon: "trophy.fill") {
                    showPRs = true
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, 20)
        }
        .background(Color.aura.bgGrouped)
        .navigationDestination(isPresented: $showPRs) {
            PersonalRecordsView()
        }
        .navigationDestination(isPresented: $showWeekly) {
            WeeklyVolumeView()
        }
    }

    // MARK: Weekly volume card
    private var weeklyCard: some View {
        let cal = Calendar.current
        let weekLogs = appState.workoutLogs.filter {
            cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }
        let weekVol = weekLogs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }
            .reduce(0.0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
        let weekSets = weekLogs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }.count

        return Button { showWeekly = true } label: {
            AuraCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(AuraFont.sectionLabel())
                            .foregroundColor(.aura.text3)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(formatVolume(weekVol))
                                .font(AuraFont.statNum(size: 26))
                                .foregroundColor(.aura.text)
                            Text("kg")
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text2)
                        }
                        Text("\(weekLogs.count) sessions · \(weekSets) sets")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.aura.text3)
                }
                .padding(AuraSpacing.s4)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Muscle focus bars
    @ViewBuilder
    private var thisWeekMuscles: some View {
        let cal = Calendar.current
        let weekLogs = appState.workoutLogs.filter {
            cal.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }
        let muscles = weekLogs.flatMap { $0.exercises }.flatMap { $0.muscleGroups }
        let counts = Dictionary(muscles.map { ($0, 1) }, uniquingKeysWith: +)
        let sorted = counts.sorted { $0.value > $1.value }.prefix(5)

        if !sorted.isEmpty {
            AuraSectionLabel(title: "This Week — Muscle Focus")
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    ForEach(sorted, id: \.key) { muscle, count in
                        HStack(spacing: AuraSpacing.s2) {
                            Text(muscle)
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text)
                                .frame(width: 88, alignment: .leading)
                            AuraProgressBar(
                                value: Double(count) / Double(sorted.first?.value ?? 1),
                                height: 6
                            )
                            Text("\(count)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.aura.text2)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                    Text("sets per muscle group")
                        .font(.system(size: 10))
                        .foregroundColor(.aura.text3)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(AuraSpacing.s4)
            }
        }
    }

    private func formatVolume(_ v: Double) -> String {
        v >= 1_000_000 ? String(format: "%.1fM", v / 1_000_000)
            : v >= 1_000 ? String(format: "%.1fk", v / 1_000)
            : String(format: "%.0f", v)
    }
}
