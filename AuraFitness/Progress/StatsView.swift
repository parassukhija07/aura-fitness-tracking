import SwiftUI

struct StatsView: View {
    @EnvironmentObject var appState: AppState
    @State private var volumeTab = "Volume"
    @State private var showPRs = false

    var totalSessions: Int { appState.workoutLogs.count }
    var totalSets: Int { appState.workoutLogs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }.count }
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

                // This week muscles
                thisWeekMuscles()

                // Lifetime stats
                AuraSectionLabel(title: "Lifetime")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AuraSpacing.s3) {
                    StatTile(value: "\(totalSessions)", label: "Sessions", color: .aura.accent)
                    StatTile(value: "\(totalSets)", label: "Sets", color: .aura.blue)
                    StatTile(value: "\(Int(totalVolume).formatted())", label: "Volume (kg)", color: .aura.green)
                    StatTile(value: "\(totalPRs)", label: "PRs", color: .aura.purple)
                }

                // PRs button
                AuraTintedButton(label: "Personal Records", icon: "trophy.fill") {
                    showPRs = true
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, 40)
        }
        .background(Color.aura.bgGrouped)
        .navigationDestination(isPresented: $showPRs) {
            PersonalRecordsView()
        }
    }

    @ViewBuilder
    private func thisWeekMuscles() -> some View {
        let weekLogs = appState.workoutLogs.filter { log in
            Calendar.current.isDate(log.date, equalTo: Date(), toGranularity: .weekOfYear)
        }
        let muscles = weekLogs.flatMap { $0.exercises }.flatMap { $0.muscleGroups }
        let counts = Dictionary(muscles.map { ($0, 1) }, uniquingKeysWith: +)
        let sorted = counts.sorted { $0.value > $1.value }.prefix(5)

        if !sorted.isEmpty {
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    Text("This Week — Muscle Focus")
                        .sectionLabelStyle()
                    ForEach(sorted, id: \.key) { muscle, count in
                        HStack {
                            Text(muscle)
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text)
                                .frame(width: 100, alignment: .leading)
                            AuraProgressBar(value: Double(count) / Double(sorted.first?.value ?? 1))
                            Text("\(count)")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                                .frame(width: 24, alignment: .trailing)
                        }
                    }
                }
                .padding(AuraSpacing.s4)
            }
        }
    }
}
