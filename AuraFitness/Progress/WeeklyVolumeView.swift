import SwiftUI

struct WeeklyVolumeView: View {
    @EnvironmentObject var appState: AppState
    @State private var metric = "Volume"   // "Volume" | "Sets"
    @State private var weekOffset = 0      // 0 = current week, -1 = last week…

    private let calendar = Calendar.current

    // MARK: - Data

    struct WeekPoint: Identifiable {
        let id: Int
        let label: String
        let value: Double
    }

    private func weekPoints() -> [WeekPoint] {
        (0..<6).reversed().enumerated().map { idx, ago in
            let weekAgo = ago + (weekOffset == 0 ? 0 : abs(weekOffset))
            guard let sunday = calendar.date(
                byAdding: .weekOfYear, value: -(weekAgo), to: startOfThisWeek()
            ) else { return WeekPoint(id: idx, label: "W\(idx+1)", value: 0) }

            let logs = appState.workoutLogs.filter {
                calendar.isDate($0.date, equalTo: sunday, toGranularity: .weekOfYear)
            }
            let value: Double
            if metric == "Volume" {
                value = logs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }
                    .reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
            } else {
                value = Double(logs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }.count)
            }
            let weekNum = calendar.component(.weekOfYear, from: sunday)
            return WeekPoint(id: idx, label: "W\(weekNum)", value: value)
        }
    }

    private func startOfThisWeek() -> Date {
        calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
    }

    private func currentWeekLogs() -> [WorkoutLog] {
        appState.workoutLogs.filter {
            calendar.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }
    }

    private var currentWeekVolume: Double {
        currentWeekLogs().flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }
            .reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
    }

    private var currentWeekSets: Int {
        currentWeekLogs().flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }.count
    }

    private var weekOverWeekPct: Double? {
        let pts = weekPoints()
        guard pts.count >= 2 else { return nil }
        let prev = pts[pts.count - 2].value
        let curr = pts[pts.count - 1].value
        guard prev > 0 else { return nil }
        return (curr - prev) / prev * 100
    }

    private var topMuscleThisWeek: (name: String, sets: Int, volume: Double)? {
        let exercises = currentWeekLogs().flatMap { $0.exercises }
        var muscleSets: [String: Int] = [:]
        var muscleVolume: [String: Double] = [:]
        for ex in exercises {
            let done = ex.sets.filter { $0.done }
            for m in ex.muscleGroups {
                muscleSets[m, default: 0] += done.count
                muscleVolume[m, default: 0] += done.reduce(0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
            }
        }
        guard let top = muscleSets.max(by: { $0.value < $1.value }) else { return nil }
        return (top.key, top.value, muscleVolume[top.key] ?? 0)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: AuraSpacing.s4) {
                // Stat + toggle row
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(metric == "Volume"
                             ? formatVolume(currentWeekVolume)
                             : "\(currentWeekSets)")
                            .font(AuraFont.statNum(size: 30))
                            .foregroundColor(.aura.text)
                        HStack(spacing: 6) {
                            Text(metric == "Volume" ? "kg this week" : "sets this week")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                            if let pct = weekOverWeekPct {
                                let up = pct >= 0
                                Text("\(up ? "▲" : "▼") \(String(format: "%.0f", abs(pct)))%")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(up ? .aura.green : .aura.red)
                            }
                        }
                    }
                    Spacer()
                    AuraSegmentedPicker(options: ["Volume","Sets"], selection: $metric)
                        .frame(width: 140)
                }
                .padding(.top, AuraSpacing.s2)

                // Line chart
                let pts = weekPoints()
                let values = pts.map { $0.value }
                AuraCard {
                    VStack(spacing: AuraSpacing.s2) {
                        AuraLineChart(data: values.isEmpty ? [0] : values, height: 140)
                            .padding(.top, AuraSpacing.s2)
                        HStack {
                            ForEach(pts) { pt in
                                Text(pt.label)
                                    .font(.system(size: 10))
                                    .foregroundColor(.aura.text3)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(AuraSpacing.s3)
                }

                // Top muscle card
                if let top = topMuscleThisWeek {
                    AuraSectionLabel(title: "Top Muscle This Week")
                    AuraCard {
                        HStack(spacing: AuraSpacing.s3) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.aura.accent)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "target")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(top.name)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.aura.text)
                                Text("\(top.sets) sets · \(formatVolume(top.volume)) kg")
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                            }
                            Spacer()
                            AuraBadge(label: "Most trained", color: .aura.green)
                        }
                        .padding(AuraSpacing.s4)
                    }
                }

                // Weekly session tiles
                AuraSectionLabel(title: "This Week")
                HStack(spacing: AuraSpacing.s3) {
                    StatTile(value: "\(currentWeekLogs().count)", label: "Workouts", color: .aura.accent)
                    StatTile(
                        value: formatDuration(currentWeekLogs().reduce(0) { $0 + $1.durationSeconds }),
                        label: "Time under bar",
                        color: .aura.blue
                    )
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
        }
        .background(Color.aura.bgGrouped)
        .navigationTitle("Weekly Volume")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Util
    private func formatVolume(_ v: Double) -> String {
        v >= 1_000_000 ? String(format: "%.1fM", v / 1_000_000)
            : v >= 1_000 ? String(format: "%.0fk", v / 1_000)
            : String(format: "%.0f", v)
    }

    private func formatDuration(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
