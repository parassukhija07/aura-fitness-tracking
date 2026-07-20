import SwiftUI

// MARK: - Day outcome (single source of truth for cell colour + legend)
//
// Five intensity levels derived from real session outcomes. Raw Int value
// doubles as the "best" ordering when a day has several logs (higher wins).

enum DayOutcome: Int, CaseIterable {
    case rest = 0, partial, swapped, completed, prDay

    var label: String {
        switch self {
        case .rest:      return "Rest"
        case .partial:   return "Partial"
        case .swapped:   return "Swapped"
        case .completed: return "Completed"
        case .prDay:     return "PR day"
        }
    }

    var color: Color {
        switch self {
        case .rest:      return Color.aura.text3.opacity(0.15)
        case .partial:   return Color.aura.accent.opacity(0.35)
        case .swapped:   return Color.aura.blue.opacity(0.6)
        case .completed: return Color.aura.accent.opacity(0.75)
        case .prDay:     return Color.aura.accent
        }
    }
}

struct ConsistencyHeatmapView: View {
    @EnvironmentObject var appState: AppState
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    // MARK: Derived

    /// The earliest month that has any log (nav lower bound); current month when
    /// there are no logs at all.
    private var earliestMonth: Date {
        let months = appState.workoutLogs.map { monthStart(of: $0.date) }
        return months.min() ?? monthStart(of: Date())
    }
    private var currentMonth: Date { monthStart(of: Date()) }

    private var canGoBack: Bool { monthStart(of: displayedMonth) > earliestMonth }
    private var canGoForward: Bool { monthStart(of: displayedMonth) < currentMonth }

    /// One pass over logs/PRs → per-day outcome for the visible month, so cells
    /// don't each re-scan `workoutLogs`/`personalRecords` (~35 lookups/render).
    private var monthOutcomes: [String: DayOutcome] {
        // Only past/today cells participate — future days stay empty/rest and
        // out of the active count even if a future-dated log/PR somehow exists.
        let today = calendar.startOfDay(for: Date())
        let visible = Set(calendarDays().compactMap { day -> String? in
            guard let day, calendar.startOfDay(for: day) <= today else { return nil }
            return AppState.iso(day)
        })
        var map: [String: DayOutcome] = [:]

        // PRs → prDay (rule 1, outranks everything).
        for pr in appState.personalRecords {
            let iso = AppState.iso(pr.date)
            guard visible.contains(iso) else { continue }
            map[iso] = .prDay
        }

        // Logs → swapped / completed / partial (best outcome wins per day).
        for log in appState.workoutLogs {
            let iso = AppState.iso(log.date)
            guard visible.contains(iso) else { continue }
            if map[iso] == .prDay { continue }   // PR already claimed this day

            let outcome: DayOutcome
            if appState.dayOverrides[iso]?.kind == .switched {
                outcome = .swapped
            } else if logFullyCompleted(log) {
                outcome = .completed
            } else {
                outcome = .partial
            }
            // Multiple logs on one day: keep the highest-value outcome.
            if let existing = map[iso], existing.rawValue >= outcome.rawValue { continue }
            map[iso] = outcome
        }

        return map
    }

    var activeDaysCount: Int {
        monthOutcomes.values.filter { $0 != .rest }.count
    }

    var body: some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                header
                dayHeaderRow
                grid
                legend
                footer
            }
            .padding(AuraSpacing.s4)
        }
    }

    // MARK: Header + month nav (clamped)

    private var header: some View {
        HStack {
            Text("Consistency")
                .font(AuraFont.jakarta(16, .bold))
                .foregroundColor(.aura.text)
            Spacer()
            HStack(spacing: 6) {
                navButton("chevron.left", enabled: canGoBack) {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                }
                Text(displayedMonth.formatted(.dateTime.month(.abbreviated).year()))
                    .font(AuraFont.jakarta(12, .bold))
                    .foregroundColor(.aura.text2)
                navButton("chevron.right", enabled: canGoForward) {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                }
            }
        }
    }

    private func navButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { if enabled { action() } }) {
            Image(systemName: icon)
                .font(AuraFont.jakarta(12, .semibold))
                .foregroundColor(enabled ? .aura.accent : .aura.text3)
                .frame(width: 28, height: 28)
        }
        .disabled(!enabled)
    }

    // MARK: Day-label header row (id: \.offset — repeated letters need stable ids)

    private var dayHeaderRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(dayLabels.enumerated()), id: \.offset) { _, d in
                Text(d)
                    .font(AuraFont.jakarta(9, .bold))
                    .foregroundColor(.aura.text3)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Grid

    private var grid: some View {
        let outcomes = monthOutcomes
        let today = calendar.startOfDay(for: Date())
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(calendarDays().enumerated()), id: \.offset) { _, day in
                if let day = day {
                    let isFuture = calendar.startOfDay(for: day) > today
                    HeatCell(
                        date: day,
                        outcome: outcomes[AppState.iso(day)] ?? .rest,
                        isFuture: isFuture,
                        isToday: calendar.isDateInToday(day)
                    )
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    // MARK: Legend (iterates DayOutcome.allCases — no parallel list)

    private var legend: some View {
        HStack(spacing: 10) {
            ForEach(DayOutcome.allCases, id: \.rawValue) { outcome in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(outcome.color)
                        .frame(width: 11, height: 11)
                    Text(outcome.label)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        Text("\(activeDaysCount) active days")
            .font(AuraFont.jakarta(11, .semibold))
            .foregroundColor(.aura.text2)
    }

    // MARK: Outcome derivation

    /// A log counts as fully completed when it has exercises and every one is
    /// done — an exercise being `completed`, having all its `sets` done, or (when
    /// only completed sets are stored) at least `plannedSets` done sets.
    private func logFullyCompleted(_ log: WorkoutLog) -> Bool {
        guard !log.exercises.isEmpty else { return false }
        return log.exercises.allSatisfy { ex in
            if ex.completed { return true }
            let done = ex.sets.filter { $0.done }.count
            if !ex.sets.isEmpty && done == ex.sets.count { return true }
            return ex.plannedSets > 0 && done >= ex.plannedSets
        }
    }

    // MARK: Calendar geometry

    private func monthStart(of date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func calendarDays() -> [Date?] {
        var comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        comps.day = 1
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }
        let offset = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: offset)
        for d in range {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

// MARK: - HeatCell

private struct HeatCell: View {
    let date: Date
    let outcome: DayOutcome
    let isFuture: Bool
    let isToday: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(outcome.color)
            // Future days render as a dim empty/rest cell.
            .opacity(isFuture ? 0.3 : 1)
            .overlay(
                isToday
                    ? RoundedRectangle(cornerRadius: 3).stroke(Color.aura.accent, lineWidth: 1.5)
                    : nil
            )
            .aspectRatio(1, contentMode: .fit)
    }
}
