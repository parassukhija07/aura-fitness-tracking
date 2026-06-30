import SwiftUI

struct ConsistencyHeatmapView: View {
    @EnvironmentObject var appState: AppState
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayLabels = ["S","M","T","W","T","F","S"]

    var activeDaysCount: Int {
        calendarDays().compactMap { $0 }.filter { appState.hasLog(for: $0) }.count
    }

    var body: some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                // Header
                HStack {
                    Text("Consistency")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.aura.text)
                    Spacer()
                    HStack(spacing: 6) {
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.aura.accent)
                                .frame(width: 28, height: 28)
                        }
                        Text(displayedMonth.formatted(.dateTime.month(.abbreviated).year()))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.aura.text2)
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.aura.accent)
                                .frame(width: 28, height: 28)
                        }
                    }
                }

                // Day labels
                HStack(spacing: 4) {
                    ForEach(dayLabels, id: \.self) { d in
                        Text(d)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.aura.text3)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Heatmap grid
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(Array(calendarDays().enumerated()), id: \.offset) { _, day in
                        if let day = day {
                            HeatCell(date: day, intensityLevel: intensityLevel(for: day))
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                }

                // Footer: active count + legend
                HStack {
                    Text("\(activeDaysCount) active days")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.aura.text2)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("Less")
                            .font(.system(size: 10))
                            .foregroundColor(.aura.text3)
                        ForEach(0..<5, id: \.self) { level in
                            legendCell(level: level)
                        }
                        Text("More")
                            .font(.system(size: 10))
                            .foregroundColor(.aura.text3)
                    }
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    // 0=empty, 1-4=intensity, -1=rest
    private func intensityLevel(for date: Date) -> Int {
        let isRest = appState.isRestDay(for: date)
        if isRest { return -1 }
        let logs = appState.logs(for: date)
        if logs.isEmpty { return 0 }
        let setCount = logs.flatMap { $0.exercises }.flatMap { $0.sets }.filter { $0.done }.count
        switch setCount {
        case 1...8:   return 1
        case 9...18:  return 2
        case 19...30: return 3
        default:      return 4
        }
    }

    private func legendCell(level: Int) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(legendColor(level: level))
            .frame(width: 11, height: 11)
    }

    private func legendColor(level: Int) -> Color {
        switch level {
        case 0:  return Color.aura.fill
        case 1:  return Color.aura.accent.opacity(0.28)
        case 2:  return Color.aura.accent.opacity(0.52)
        case 3:  return Color.aura.accent.opacity(0.76)
        default: return Color.aura.accent
        }
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
    let intensityLevel: Int  // -1=rest, 0=empty, 1-4=worked

    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { geo in
            let size = geo.size.width
            ZStack {
                if intensityLevel == -1 {
                    // Rest: hatched pattern via Canvas
                    Canvas { ctx, size in
                        let path = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 3)
                        ctx.fill(path, with: .color(Color.aura.fill))
                        // diagonal stripes
                        var x: CGFloat = -size.height
                        while x < size.width + size.height {
                            var stripe = Path()
                            stripe.move(to: CGPoint(x: x, y: 0))
                            stripe.addLine(to: CGPoint(x: x + size.height, y: size.height))
                            ctx.stroke(stripe, with: .color(Color.aura.separator), style: StrokeStyle(lineWidth: 1.2))
                            x += 5
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(cellColor)
                }

                // Today ring
                if calendar.isDateInToday(date) {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.aura.accent, lineWidth: 1.5)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var cellColor: Color {
        switch intensityLevel {
        case 0:  return Color.aura.fill
        case 1:  return Color.aura.accent.opacity(0.28)
        case 2:  return Color.aura.accent.opacity(0.52)
        case 3:  return Color.aura.accent.opacity(0.76)
        default: return Color.aura.accent
        }
    }
}
