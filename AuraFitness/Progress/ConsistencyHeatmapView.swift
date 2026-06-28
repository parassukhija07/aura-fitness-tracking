import SwiftUI

struct ConsistencyHeatmapView: View {
    @EnvironmentObject var appState: AppState
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)

    var body: some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                HStack {
                    Text("Consistency")
                        .sectionLabelStyle()
                    Spacer()
                    HStack(spacing: AuraSpacing.s2) {
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.aura.accent)
                        }
                        Text(displayedMonth.formatted(.dateTime.month(.abbreviated).year()))
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.aura.accent)
                        }
                    }
                }

                // Day labels
                HStack(spacing: 3) {
                    ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                        Text(d)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.aura.text3)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Grid
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(calendarDays(), id: \.self) { day in
                        if let day = day {
                            heatCell(date: day)
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.clear)
                                .frame(height: 20)
                        }
                    }
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    @ViewBuilder
    private func heatCell(date: Date) -> some View {
        let hasLog = appState.hasLog(for: date)
        let isRest = appState.isRestDay(for: date)
        let isToday = calendar.isDateInToday(date)

        let bg: Color = hasLog ? .aura.green : .aura.fill
        let opacity: Double = hasLog ? 1.0 : 0.4

        RoundedRectangle(cornerRadius: 3)
            .fill(bg.opacity(opacity))
            .frame(height: 20)
            .overlay {
                // Rest days are hatched (per design), distinguishing them from empty days.
                if isRest && !hasLog {
                    HatchPattern()
                        .stroke(Color.aura.text3.opacity(0.35), lineWidth: 1)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .overlay(
                isToday ? RoundedRectangle(cornerRadius: 3).stroke(Color.aura.accent, lineWidth: 1.5) : nil
            )
    }

    private func calendarDays() -> [Date?] {
        var comps = calendar.dateComponents([.year, .month], from: displayedMonth)
        comps.day = 1
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay)
        else { return [] }

        let weekdayOffset = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: weekdayOffset)
        for d in range {
            days.append(calendar.date(byAdding: .day, value: d - 1, to: firstDay))
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}

// MARK: - Diagonal hatch fill for rest-day heatmap cells
private struct HatchPattern: Shape {
    var spacing: CGFloat = 4
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = -rect.height
        while x < rect.width {
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + rect.height, y: 0))
            x += spacing
        }
        return path
    }
}
