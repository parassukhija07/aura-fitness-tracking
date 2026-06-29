import SwiftUI

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

struct StatsView: View {
    @EnvironmentObject var appState: AppState
    @State private var volumeTab = "Volume"
    @State private var showPRs = false
    @State private var selectedExerciseName = "Barbell Bench Press"
    @State private var selectedMetric = "1rm"
    @State private var selectedRange = "6m"
    @State private var showExerciseSearch = false

    var totalSessions: Int { appState.workoutLogs.count }
    var totalSets: Int { appState.workoutLogs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }.count }
    var totalVolume: Double {
        appState.workoutLogs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }
            .reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
    }
    var totalPRs: Int { appState.personalRecords.count }

    var strengthScore: Int {
        let muscleScores = [
            ("Legs", 290), ("Chest", 280), ("Back", 260),
            ("Arms", 255), ("Shoulders", 240)
        ]
        return muscleScores.map { $0.1 }.reduce(0, +) / muscleScores.count
    }

    var strengthBalance: Int {
        let muscleBalances = [
            ("Legs", 88), ("Chest", 82), ("Back", 75),
            ("Arms", 72), ("Shoulders", 58)
        ]
        let avg = Double(muscleBalances.map { $0.1 }.reduce(0, +)) / Double(muscleBalances.count)
        let deviation = muscleBalances.map { abs(Double($0.1) - avg) }.reduce(0, +) / Double(muscleBalances.count)
        return Int((100 - deviation).clamped(to: 0...100))
    }

    var thisWeekByMuscle: [(String, Int)] {
        let weekLogs = appState.workoutLogs.filter { log in
            Calendar.current.isDate(log.date, equalTo: Date(), toGranularity: .weekOfYear)
        }
        let muscles = weekLogs.flatMap { $0.exercises }.flatMap { $0.muscleGroups }
        let counts = Dictionary(muscles.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value > $1.value }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                // Consistency heatmap
                ConsistencyHeatmapView()

                // Strength Score & Balance side-by-side
                HStack(spacing: AuraSpacing.s3) {
                    strengthScoreCard()
                    strengthBalanceCard()
                }

                // Lifetime stats
                AuraSectionLabel(title: "Lifetime")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AuraSpacing.s3) {
                    StatTile(value: "\(totalSessions)", label: "Sessions", color: .aura.accent)
                    StatTile(value: "\(totalSets)", label: "Sets", color: .aura.blue)
                    StatTile(value: "\(Int(totalVolume).formatted())", label: "Volume (kg)", color: .aura.green)
                    StatTile(value: "\(totalPRs)", label: "PRs", color: .aura.purple)
                }

                // This week muscles
                thisWeekMuscles()

                // Exercise trends
                exerciseTrendsCard()

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
    private func strengthScoreCard() -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                Text("Strength Score")
                    .font(AuraFont.sectionLabel())
                    .foregroundColor(.aura.text3)

                HStack(alignment: .top, spacing: AuraSpacing.s2) {
                    Text("\(strengthScore)")
                        .font(AuraFont.statNum(size: 32))
                        .foregroundColor(.aura.text)
                }
                .padding(.vertical, 2)

                HStack(spacing: 6) {
                    Text("Intermediate")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.aura.accent.opacity(0.12))
                        .clipShape(Capsule())
                    Text("73% to 300")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.aura.text2)
                }

                VStack(spacing: 5) {
                    ForEach([("Legs", 290), ("Chest", 280), ("Back", 260)], id: \.0) { muscle, score in
                        VStack(spacing: 2) {
                            HStack {
                                Text(muscle)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.aura.text2)
                                Spacer()
                                Text("\(score)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.aura.accent)
                            }
                            AuraProgressBar(value: Double(score - 100) / Double(500 - 100), height: 3)
                        }
                    }
                }
            }
            .padding(AuraSpacing.s3)
        }
    }

    @ViewBuilder
    private func strengthBalanceCard() -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                Text("Strength Balance")
                    .font(AuraFont.sectionLabel())
                    .foregroundColor(.aura.text3)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(strengthBalance)")
                        .font(AuraFont.statNum(size: 32))
                        .foregroundColor(.aura.text)
                    Text("%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.aura.text3)
                }
                .padding(.vertical, 2)

                Text("Shoulders weakest")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.blue)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.aura.blue.opacity(0.12))
                    .clipShape(Capsule())

                VStack(spacing: 5) {
                    ForEach([("Legs", 88), ("Chest", 82), ("Back", 75)], id: \.0) { muscle, balance in
                        VStack(spacing: 2) {
                            HStack {
                                Text(muscle)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.aura.text2)
                                Spacer()
                                Text("\(balance)%")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.aura.accent)
                            }
                            AuraProgressBar(value: Double(balance) / 100.0, height: 3)
                        }
                    }
                }
            }
            .padding(AuraSpacing.s3)
        }
    }

    @ViewBuilder
    private func thisWeekMuscles() -> some View {
        if !thisWeekByMuscle.isEmpty {
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    Text("This Week — Volume by Muscle")
                        .sectionLabelStyle()
                    ForEach(thisWeekByMuscle.prefix(5), id: \.0) { muscle, count in
                        HStack {
                            Text(muscle)
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text)
                                .frame(width: 100, alignment: .leading)
                            AuraProgressBar(value: Double(count) / Double(thisWeekByMuscle.first?.1 ?? 1))
                            Text("\(count)%")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
                .padding(AuraSpacing.s4)
            }
        }
    }

    @ViewBuilder
    private func exerciseTrendsCard() -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                HStack {
                    Text("Exercise Trends")
                        .font(AuraFont.secondary())
                        .fontWeight(.bold)
                        .foregroundColor(.aura.text)
                    Spacer()
                    Button {
                        showExerciseSearch = true
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.aura.accent)
                            .clipShape(Circle())
                    }
                }

                Text(selectedExerciseName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.aura.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    ForEach(["1rm", "weight", "reps", "volume"], id: \.self) { metric in
                        Button {
                            selectedMetric = metric
                        } label: {
                            Text(metricLabel(metric))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(selectedMetric == metric ? .white : .aura.text2)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(selectedMetric == metric ? Color.aura.accent : Color.aura.fill)
                                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("62.0 kg")
                                .font(AuraFont.statNum(size: 26))
                                .foregroundColor(.aura.text)
                            Text(metricLabel(selectedMetric))
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .semibold))
                            Text("+1.2 kg")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.aura.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.aura.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(.vertical, 2)

                    RoundedRectangle(cornerRadius: AuraRadius.sm)
                        .fill(Color.aura.fill)
                        .frame(height: 80)
                        .overlay {
                            Text("Chart placeholder")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text3)
                        }
                }

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
    }

    private func metricLabel(_ metric: String) -> String {
        switch metric {
        case "1rm": return "1 Rep Max"
        case "weight": return "Max Weight"
        case "reps": return "Max Reps"
        case "volume": return "Max Volume"
        default: return metric
        }
    }
}
