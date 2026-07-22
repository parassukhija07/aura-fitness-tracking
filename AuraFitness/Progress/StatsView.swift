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
    @State private var trendRange = "6m"
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

    /// Window length per range chip.
    private var rangeDays: Int {
        switch trendRange {
        case "1m": return 30
        case "3m": return 90
        case "6m": return 180
        default:   return 365
        }
    }

    private var rangeCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date()) ?? Date()
    }

    private func metricValue(for sets: [WorkoutSet]) -> Double? {
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

    /// (date, value) per session containing the selected exercise, oldest first.
    var trendSessions: [(date: Date, value: Double)] {
        appState.workoutLogs
            .filter { $0.date >= rangeCutoff }
            .sorted { $0.date < $1.date }
            .compactMap { log -> (date: Date, value: Double)? in
                let sets = log.exercises
                    .filter { $0.name.caseInsensitiveCompare(selectedExerciseName) == .orderedSame }
                    .flatMap(\.sets)
                    .filter { $0.done }
                guard !sets.isEmpty, let value = metricValue(for: sets) else { return nil }
                return (log.date, value)
            }
    }

    /// One value per session containing the selected exercise, oldest first.
    var trendValues: [Double] { trendSessions.map(\.value) }

    /// Chart series for the visible window. 1M collapses to 4 consecutive
    /// weekly buckets (most recent session in each, carried forward across
    /// gaps, leading empties dropped); every other range plots per session.
    var trendSeries: (points: [Double], labels: [String]) {
        let sessions = trendSessions
        guard !sessions.isEmpty else { return ([], []) }

        guard trendRange == "1m" else {
            let points = sessions.map(\.value)
            return (points, monthLabels(count: min(4, points.count)))
        }

        let cal = Calendar.current
        let start = rangeCutoff
        var buckets: [Double?] = Array(repeating: nil, count: 4)
        for session in sessions {
            let days = cal.dateComponents([.day], from: start, to: session.date).day ?? 0
            // Sessions arrive oldest-first, so the last write per bucket
            // is that bucket's most recent session.
            buckets[min(max(days / 7, 0), 3)] = session.value
        }

        var points: [Double] = []
        var labels: [String] = []
        var carried: Double? = nil
        for (i, bucket) in buckets.enumerated() {
            if let bucket { carried = bucket }
            guard let value = carried else { continue }  // leading empties drop
            points.append(value)
            labels.append("W\(i + 1)")
        }
        return (points, labels)
    }

    /// Short month names spread evenly across the visible window.
    private func monthLabels(count: Int) -> [String] {
        guard count > 0 else { return [] }
        let start = rangeCutoff
        let span = Date().timeIntervalSince(start)
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM"
        return (0..<count).map { i in
            let offset = count == 1 ? span : span * Double(i) / Double(count - 1)
            return fmt.string(from: start.addingTimeInterval(offset))
        }
    }

    var body: some View {
        AuraScreenScroll(bottomClearance: 0) {
            VStack(spacing: AuraSpacing.s4) {
                // Consistency heatmap
                ConsistencyHeatmapView()

                // Weekly volume card (tappable → WeeklyVolumeView)
                weeklyCard

                // Strength Score / Balance — gated by the Profile
                // "Show on progress" setting (appState.logDisplayMode).
                performanceCards()

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
                        .font(AuraFont.jakarta(14, .semibold))
                        .foregroundColor(.aura.text3)
                }
                .padding(AuraSpacing.s4)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Strength score / balance cards

    /// Honours the Profile → General → "Show on progress" setting. Any
    /// unrecognised persisted value falls through to both cards.
    @ViewBuilder
    private func performanceCards() -> some View {
        switch appState.logDisplayMode {
        case "Strength Score":
            strengthScoreCard()
        case "Strength Balance":
            strengthBalanceCard()
        default:
            HStack(spacing: AuraSpacing.s3) {
                strengthScoreCard()
                    .frame(maxWidth: .infinity)
                strengthBalanceCard()
                    .frame(maxWidth: .infinity)
            }
        }
    }

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
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.vertical, 2)

                    let next = min(((score / 100) + 1) * 100, 500)
                    HStack(spacing: 6) {
                        Text(scoreBand(score))
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.aura.accent.opacity(0.12))
                            .clipShape(Capsule())
                        if score < 500 {
                            Text("\(score * 100 / next)% to \(next)")
                                .font(AuraFont.jakarta(10, .semibold))
                                .foregroundColor(.aura.text2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }

                    VStack(spacing: 5) {
                        ForEach(muscleScores.prefix(3), id: \.0) { muscle, score in
                            VStack(spacing: 2) {
                                HStack {
                                    Text(muscle)
                                        .font(AuraFont.jakarta(10, .semibold))
                                        .foregroundColor(.aura.text2)
                                    Spacer()
                                    Text("\(score)")
                                        .font(AuraFont.jakarta(10, .bold))
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
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("%")
                            .font(AuraFont.jakarta(16, .bold))
                            .foregroundColor(.aura.text3)
                    }
                    .padding(.vertical, 2)

                    if let weakest = weakestMuscle {
                        Text("\(weakest) weakest")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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
                                        .font(AuraFont.jakarta(10, .semibold))
                                        .foregroundColor(.aura.text2)
                                    Spacer()
                                    Text("\(pct)%")
                                        .font(AuraFont.jakarta(10, .bold))
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
                .font(AuraFont.jakarta(11, .medium))
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
                        .font(AuraFont.jakarta(10))
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

    /// Canonical kg → the unit currently on screen (reps pass through).
    private func displayValue(_ v: Double) -> Double {
        metricIsWeight ? UnitFormatter.weightValue(v, unit: appState.weightUnit) : v
    }

    /// Axis tick label. `v` is already in display units — reps are integers.
    private func axisLabel(_ v: Double) -> String {
        guard metricIsWeight else { return String(Int(v.rounded())) }
        return v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.1f", v)
    }

    @ViewBuilder
    private func deltaBadge(_ delta: Double) -> some View {
        let flat = delta == 0
        let up = delta > 0
        let tint: Color = flat ? .aura.text2 : (up ? .aura.green : .aura.red)
        HStack(spacing: 4) {
            if !flat {
                Image(systemName: up ? "arrow.up" : "arrow.down")
                    .font(AuraFont.jakarta(12, .semibold))
            }
            Text(flat ? "±0" : "\(up ? "+" : "−")\(trendValueLabel(abs(delta)))")
                .font(AuraFont.jakarta(11, .bold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4))
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
                            .font(AuraFont.jakarta(14, .semibold))
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
                        .font(AuraFont.jakarta(15, .bold))
                        .foregroundColor(.aura.text)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        ForEach(["1rm", "weight", "reps", "volume"], id: \.self) { metric in
                            Button {
                                selectedMetric = metric
                            } label: {
                                Text(metricLabel(metric))
                                    .font(AuraFont.jakarta(11, .bold))
                                    .foregroundColor(selectedMetric == metric ? .white : .aura.text2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(selectedMetric == metric ? Color.aura.accent : Color.aura.fill)
                                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                            }
                        }
                    }

                    let series = trendSeries
                    let values = series.points
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
                                // Hidden for a single point — nothing to compare against.
                                if let first = values.first, values.count > 1 {
                                    deltaBadge(current - first)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        if values.isEmpty {
                            RoundedRectangle(cornerRadius: AuraRadius.sm)
                                .fill(Color.aura.fill)
                                .frame(height: 80)
                                .overlay {
                                    Text("No sessions in this range")
                                        .font(AuraFont.secondary())
                                        .foregroundColor(.aura.text3)
                                }
                        } else {
                            // Charted in display units so the ticks stay "nice"
                            // in whatever unit the user is on.
                            AuraAxisChart(
                                points: values.map(displayValue),
                                xLabels: series.labels,
                                valueFormatter: axisLabel,
                                height: 100
                            )
                            if values.count == 1 {
                                Text("Log more sessions to draw a trend")
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text3)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                    }

                    HStack(spacing: 5) {
                        ForEach(["1m", "3m", "6m", "1y"], id: \.self) { range in
                            Button {
                                trendRange = range
                            } label: {
                                Text(range.uppercased())
                                    .font(AuraFont.jakarta(12, .bold))
                                    .foregroundColor(trendRange == range ? .aura.text : .aura.text3)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(trendRange == range ? Color.aura.surface : Color.clear)
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
            loggedNames: loggedExerciseNames,
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
    /// Exercises the user has actually logged — floated to the top of the
    /// list, since those are the only ones that can draw a trend.
    let loggedNames: [String]
    let selected: String
    let onPick: (String) -> Void

    @StateObject private var db = ExerciseDatabase.shared
    @State private var query = ""
    @State private var category = "All"
    @State private var equipment = "All"

    private let categories = ["All", "Chest", "Back", "Shoulders", "Arms", "Legs", "Core", "Cardio", "Warm-up"]
    private let equipmentOptions = ["All", "Barbell", "Dumbbell", "Cable", "Machine", "Smith Machine", "Bodyweight"]

    /// Full library under the active filters, logged exercises first. Logged
    /// names absent from the library (custom/legacy) survive only while both
    /// filter rows are on "All" — there is nothing to classify them by.
    private var filtered: [String] {
        let libraryNames = db.filtered(
            category: category == "All" ? nil : category,
            equipment: equipment == "All" ? nil : equipment,
            query: query
        ).map(\.name)

        var names = libraryNames
        if category == "All", equipment == "All" {
            let known = Set(libraryNames.map { $0.lowercased() })
            let orphans = loggedNames.filter {
                !known.contains($0.lowercased())
                    && (query.isEmpty || $0.localizedCaseInsensitiveContains(query))
            }
            names.append(contentsOf: orphans)
        }

        // `uniquingKeysWith:` — two logged names can differ only by case.
        let loggedRank = Dictionary(loggedNames.enumerated().map { ($1.lowercased(), $0) },
                                    uniquingKeysWith: min)
        var seen = Set<String>()
        return names
            .filter { seen.insert($0.lowercased()).inserted }
            .sorted { a, b in
                switch (loggedRank[a.lowercased()], loggedRank[b.lowercased()]) {
                case let (l?, r?): return l < r
                case (_?, nil):    return true
                case (nil, _?):    return false
                default:           return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
                }
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Choose Exercise")
                .font(AuraFont.navTitle())
                .foregroundColor(.aura.text)
                .padding(.vertical, AuraSpacing.s2)

            HStack(spacing: AuraSpacing.s2) {
                Image(systemName: "magnifyingglass").foregroundColor(.aura.text3)
                TextField("Search exercises", text: $query)
                    .font(AuraFont.body())
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, AuraSpacing.s2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(categories, id: \.self) { c in
                        AuraChip(label: c, active: category == c) { category = c }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(equipmentOptions, id: \.self) { e in
                        AuraChip(label: e, active: equipment == e) { equipment = e }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s1)
                .padding(.bottom, AuraSpacing.s2)
            }

            if filtered.isEmpty {
                Text(loggedNames.isEmpty && db.entries.isEmpty ? "No logged exercises yet" : "No matches")
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
                                            .font(AuraFont.jakarta(18))
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
