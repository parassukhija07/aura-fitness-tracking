import SwiftUI

// MARK: - WeekStrip
//
// Shared 7-day tile strip extracted from MyPlansView so the Program editor can
// reuse it rather than re-implement the tile art. Data-source-agnostic: the
// caller resolves the workout for a given weekday (0=Sun … 6=Sat) and handles
// taps. Day order honours the calendar-start preference.

struct WeekStripView: View {
    /// 0=Sun, 1=Mon — pass `appState.calendarStartDay`.
    let calendarStartDay: Int
    /// Resolve the workout scheduled on a weekday index (nil = rest / unplanned).
    let workoutForDay: (Int) -> Workout?
    /// Fired when a day tile is tapped, carrying the weekday index.
    let onTapDay: (Int) -> Void

    private static let labels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    /// weekSchedule keys: 0=Sun … 6=Sat; order honours the calendar-start pref.
    private var order: [Int] {
        calendarStartDay == 0 ? [0, 1, 2, 3, 4, 5, 6] : [1, 2, 3, 4, 5, 6, 0]
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(order, id: \.self) { day in
                WeekStripDayTile(
                    label: Self.labels[day],
                    workout: workoutForDay(day),
                    action: { onTapDay(day) }
                )
            }
        }
    }
}

/// Single day tile (label · icon chip · short workout name), tinted by the
/// workout keyword or shown as a moon-glyph rest tile.
struct WeekStripDayTile: View {
    let label: String
    let workout: Workout?
    let action: () -> Void

    var body: some View {
        let isRest = workout == nil
        let c = planWkStyle(workout?.name)
        let shortName = workout.map {
            $0.name.replacingOccurrences(of: "workout", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
                .components(separatedBy: " ").first ?? ""
        } ?? "Rest"

        Button(action: action) {
            VStack(spacing: 6) {
                Text(label.uppercased())
                    .font(AuraFont.jakarta(9, .bold))
                    .tracking(0.6)
                    .foregroundColor(isRest ? .aura.text3 : c.tint)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isRest ? Color.aura.fill : c.bg)
                        .frame(width: 34, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isRest ? Color.aura.separator2 : c.border.opacity(0.45), lineWidth: 1.5)
                        )
                    Image(systemName: isRest ? "moon.fill" : planWkIcon(workout?.name))
                        .font(AuraFont.jakarta(isRest ? 14 : 16))
                        .foregroundColor(isRest ? .aura.text3 : c.tint)
                }
                Text(shortName)
                    .font(AuraFont.jakarta(8, .bold))
                    .foregroundColor(isRest ? .aura.text3 : c.tint)
                    .lineLimit(1)
                    .frame(maxWidth: 34)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 2)
            .background(isRest ? Color.clear : c.bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRest ? Color.aura.separator2 : c.border.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
