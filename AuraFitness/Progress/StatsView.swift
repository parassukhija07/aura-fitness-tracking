import SwiftUI

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

struct StatsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPRs = false
    @State private var showWeekly = false
    @State private var selectedExerciseName = ""
    @State private var selectedMetric = "1rm"
    @State private var selectedRange = "6m"
    @State private var showExerciseSearch = false

    var totalSessions: Int { appState.workoutLogs.count }
    var totalSets: Int {
        appState.workoutLogs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }.count
    }
    var totalVolume: Double {
        appState.workoutLogs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }
            .reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
    }
    /// Distinct exercises with a PR — `personalRecords` is an append-only
    /// log, so raw count would overcount as history accumulates.
    var totalPRs: Int { Set(appState.personalRecords.map { $0.exerciseName.lowercased() }).count }

    // MARK: - Strength score engine (derived from the PR log)
    //
    // Score per muscle = best e1RM relative to bodyweight, normalised so hitting
    // a muscle's "advanced" bodyweight multiple scores 300 on a 100–500 scale.

    /// Muscle → e1RM-to-bodyweight multiple that maps to a 300 score.
    private static let advancedRatio: [String: Double] = [
        "Legs": 1.8, "Back": 1.4, "Chest": 1.2, "Shoulders": 0.9, "Arms": 0.6, "Core": 0.8,
    ]

    private func canonicalMuscle(_ m: String) -> String {
        switch m {
        case "Biceps", "Triceps", "Forearms": return "Arms"
        case "Quads", "Hamstrings", "Glutes", "Calves": return "Legs"
        default: return m
        }
    }

    /// (muscle, score 100–500), best first — only muscles with logged PRs.
    var muscleScores: [(String, Int)] {
        let bodyweight = max(appState.bodyStats.weight, 1)
        let bestByMuscle = Dictionary(grouping: appState.personalRecords,
                                      by: { canonicalMuscle($0.muscle) })
            .mapValues { $0.map(\.estimated1RM).max() ?? 0 }
        return bestByMuscle
            .compactMap { muscle, best -> (String, Int)? in
                guard best > 0, let advanced = Self.advancedRatio[muscle] else { return nil }
                let score = (best / bodyweight) / advanced * 300
                return (muscle, Int(score.clamped(to: 100...500)))
            }
            .sorted { $0.1 > $1.1 }
    }

    var strengthScore: Int? {
        guard !muscleScores.isEmpty else { return nil }
        return muscleScores.map(\.1).reduce(0, +) / muscleScores.count
    }

    private func scoreBand(_ s: Int) -> String {
        s < 200 ? "Beginner" : s < 300 ? "Intermediate" : s < 400 ? "Advanced" : "Elite"
    }

    /// Per-muscle balance = score relative to the strongest muscle.
    var muscleBalances: [(String, Int)] {
        guard let top = muscleScores.first?.1, top > 0 else { return [] }
        return muscleScores.map { ($0.0, Int(Double($0.1) / Double(top) * 100)) }
    }

    var strengthBalance: Int? {
        guard muscleBalances.count > 1 else { return nil }
        let values = muscleBalances.map { Double($0.1) }
        let avg = values.reduce(0, +) / Double(values.count)
        let deviation = values.map { abs($0 - avg) }.reduce(0, +) / Double(values.count)
        return Int((100 - deviation).clamped(to: 0...100))
    }

    var weakestMuscle: String? { muscleScores.last?.0 }

    var thisWeekByMuscle: [(String, Int)] {
        let weekLogs = appState.workoutLogs.filter { log in
            Calendar.current.isDate(log.date, equalTo: Date(), toGranularity: .weekOfYear)
        }
        let muscles = weekLogs.flatMap { $0.exercises }.flatMap { $0.muscleGroups }
        let counts = Dictionary(muscles.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value > $1.value }
    }

    // MARK: - Exercise trend engine

    /// Distinct logged exercise names, most-logged first.
    var loggedExerciseNames: [String] {
        let names = appState.workoutLogs.flatMap { $0.exercises }.map(\.name)
        let counts = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    private var rangeCutoff: Date {
        let months: Int
        switch selectedRange {
        case "1m": months = 1
        case "3m": months = 3
        case "6m": months = 6
        default:   months = 12
        }
        return Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
    }

    /// One value per session containing the selected exercise, oldest first.
    var trendValues: [Double] {
        appState.workoutLogs
            .filter { $0.date >= rangeCutoff }
            .sorted { $0.date < $1.date }
            .compactMap { log -> Double? in
                let sets = log.exercises
                    .filter { $0.name.caseInsensitiveCompare(selectedExerciseName) == .orderedSame }
                    .flatMap(\.sets)
                    .filter { $0.done }
                guard !sets.isEmpty else { return nil }
                switch selectedMetric {
                case "1rm":
                    return sets.map { PersonalRecord.compute1RM(weight: $0.weight ?? 0, reps: $0.reps ?? 1) }.max()
                case "weight":
                    return sets.map { $0.weight ?? 0 }.max()
                case "reps":
                    return sets.map { Double($0.reps ?? 0) }.max()
                default: // volume
                    return sets.reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
                }
            }
    }

    var body: some View {
        AuraScreenScroll(bottomClearance: 0) {
            VStack(spacing: AuraSpacing.s4) {
                // Consistency heatmap
                ConsistencyHeatmapView()

                // Weekly volume card (tappable → WeeklyVolumeView)
                weeklyCard

                // Strength Score & Balance side-by-side
                HStack(spacing: AuraSpacing.s3) {
                    strengthScoreCard()
                    strengthBalanceCard()
                }

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

                // This week muscles
                thisWeekMuscles()

                // Exercise trends
                exerciseTrendsCard()

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
        .sheet(isPresented: $showExerciseSearch) {
            exercisePickerSheet
        }
        .onAppear {
            if selectedExerciseName.isEmpty || !loggedExerciseNames.contains(selectedExerciseName) {
                selectedExerciseName = loggedExerciseNames.first ?? ""
            }
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
                            Text(UnitFormatter.weightNumber(weekVol, unit: appState.weightUnit))
                                .font(AuraFont.statNum(size: 26))
                                .foregroundColor(.aura.text)
                            Text(appState.weightUnit)
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

    // MARK: Strength score / balance cards
    @ViewBuilder
    private func strengthScoreCard() -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                Text("Strength Score")
                    .font(AuraFont.sectionLabel())
                    .foregroundColor(.aura.text3)

                if let score = strengthScore {
                    HStack(alignment: .top, spacing: AuraSpacing.s2) {
                        Text("\(score)")
                            .font(AuraFont.statNum(size: 32))
                            .foregroundColor(.aura.text)
                    }
                    .padding(.vertical, 2)

                    let next = min(((score / 100) + 1) * 100, 500)
                    HStack(spacing: 6) {
                        Text(scoreBand(score))
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.aura.accent.opacity(0.12))
                            .clipShape(Capsule())
                        if score < 500 {
                            Text("\(score * 100 / next)% to \(next)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.aura.text2)
                        }
                    }

                    VStack(spacing: 5) {
                        ForEach(muscleScores.prefix(3), id: \.0) { muscle, score in
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
                } else {
                    scoreEmptyState("Set PRs while logging to build your score")
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

                if let balance = strengthBalance {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(balance)")
                            .font(AuraFont.statNum(size: 32))
                            .foregroundColor(.aura.text)
                        Text("%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.aura.text3)
                    }
                    .padding(.vertical, 2)

                    if let weakest = weakestMuscle {
                        Text("\(weakest) weakest")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.blue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.aura.blue.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    VStack(spacing: 5) {
                        ForEach(muscleBalances.prefix(3), id: \.0) { muscle, pct in
                            VStack(spacing: 2) {
                                HStack {
                                    Text(muscle)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.aura.text2)
                                    Spacer()
                                    Text("\(pct)%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.aura.accent)
                                }
                                AuraProgressBar(value: Double(pct) / 100.0, height: 3)
                            }
                        }
                    }
                } else {
                    scoreEmptyState("Log PRs across muscles to compare balance")
                }
            }
            .padding(AuraSpacing.s3)
        }
    }

    private func scoreEmptyState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("—")
                .font(AuraFont.statNum(size: 32))
                .foregroundColor(.aura.text3)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.aura.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
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

    // MARK: Exercise trends

    private var metricIsWeight: Bool { selectedMetric != "reps" }

    private func trendValueLabel(_ v: Double) -> String {
        metricIsWeight
            ? "\(UnitFormatter.weightNumber(v, unit: appState.weightUnit)) \(appState.weightUnit)"
            : "\(Int(v)) reps"
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

                if selectedExerciseName.isEmpty {
                    Text("Log workouts to see per-exercise trends here.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text3)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, AuraSpacing.s6)
                } else {
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

                    let values = trendValues
                    VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                        if let current = values.last {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trendValueLabel(current))
                                        .font(AuraFont.statNum(size: 26))
                                        .foregroundColor(.aura.text)
                                    Text(metricLabel(selectedMetric))
                                        .font(AuraFont.secondary())
                                        .foregroundColor(.aura.text2)
                                }
                                Spacer()
                                if let first = values.first, values.count > 1 {
                                    let delta = current - first
                                    HStack(spacing: 4) {
                                        Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("\(delta >= 0 ? "+" : "−")\(trendValueLabel(abs(delta)))")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundColor(delta >= 0 ? .aura.green : .aura.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background((delta >= 0 ? Color.aura.green : Color.aura.red).opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        if values.count > 1 {
                            AuraLineChart(data: values, height: 80)
                        } else {
                            RoundedRectangle(cornerRadius: AuraRadius.sm)
                                .fill(Color.aura.fill)
                                .frame(height: 80)
                                .overlay {
                                    Text(values.isEmpty
                                         ? "No sessions in this range"
                                         : "Log more sessions to draw a trend")
                                        .font(AuraFont.secondary())
                                        .foregroundColor(.aura.text3)
                                }
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
            }
            .padding(AuraSpacing.s4)
        }
    }

    // MARK: Exercise picker sheet

    private var exercisePickerSheet: some View {
        ExerciseTrendPicker(
            names: loggedExerciseNames,
            selected: selectedExerciseName,
            onPick: { selectedExerciseName = $0; showExerciseSearch = false }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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

// MARK: - Exercise trend picker sheet

private struct ExerciseTrendPicker: View {
    let names: [String]
    let selected: String
    let onPick: (String) -> Void

    @State private var query = ""

    private var filtered: [String] {
        query.isEmpty ? names : names.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            Text("Choose Exercise")
                .font(AuraFont.navTitle())
                .foregroundColor(.aura.text)
                .padding(.vertical, AuraSpacing.s2)

            HStack(spacing: AuraSpacing.s2) {
                Image(systemName: "magnifyingglass").foregroundColor(.aura.text3)
                TextField("Search logged exercises", text: $query)
                    .font(AuraFont.body())
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, AuraSpacing.s2)

            if filtered.isEmpty {
                Text(names.isEmpty ? "No logged exercises yet" : "No matches")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text3)
                    .padding(.vertical, AuraSpacing.s8)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filtered, id: \.self) { name in
                            Button { onPick(name) } label: {
                                HStack {
                                    Text(name)
                                        .font(AuraFont.body())
                                        .foregroundColor(.aura.text)
                                    Spacer()
                                    if name == selected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.aura.accent)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, AuraSpacing.s4)
                            }
                            .buttonStyle(.plain)
                            Divider().padding(.leading, AuraSpacing.s4)
                        }
                    }
                }
            }
        }
        .background(Color.aura.elevated)
    }
}
