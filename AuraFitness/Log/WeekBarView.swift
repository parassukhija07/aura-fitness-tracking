import SwiftUI

struct WeekBarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedDate: Date

    private let calendar = Calendar.current
    private let dayLetters = ["S","M","T","W","T","F","S"]

    var weekDates: [Date] {
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) - 1  // 0=Sun
        let startOffset = appState.calendarStartDay == 1
            ? (weekday == 0 ? -6 : -(weekday - 1))
            : -weekday
        return (0..<7).compactMap { i in
            calendar.date(byAdding: .day, value: startOffset + i, to: today)
        }
    }

    var dayLetterArray: [String] {
        if appState.calendarStartDay == 1 {
            return ["M","T","W","T","F","S","S"]
        }
        return dayLetters
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { i, date in
                    dayCell(date: date, letter: dayLetterArray[i])
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
        }
    }

    @ViewBuilder
    private func dayCell(date: Date, letter: String) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasLog = appState.hasLog(for: date)
        let dayNum = calendar.component(.day, from: date)

        let isRestDay: Bool = {
            guard let plan = appState.defaultPlan else { return false }
            let idx = calendar.component(.weekday, from: date) - 1
            if let entry = plan.weekSchedule[idx] { return entry == nil }
            return false
        }()

        Button {
            selectedDate = date
        } label: {
            VStack(spacing: 4) {
                Text(letter)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isSelected ? .white : .aura.text2)

                Text("\(dayNum)")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(isSelected ? .white : (isToday ? .aura.accent : .aura.text))

                // Status dot
                Circle()
                    .fill(dotColor(hasLog: hasLog, isRestDay: isRestDay))
                    .frame(width: 5, height: 5)
                    .opacity(dotColor(hasLog: hasLog, isRestDay: isRestDay) == .clear ? 0 : 1)
            }
            .frame(width: 44, height: 62)
            .background(isSelected ? Color.aura.accent : Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.md)
                    .stroke(isSelected ? Color.clear : Color.aura.separator.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dotColor(hasLog: Bool, isRestDay: Bool) -> Color {
        if hasLog { return .aura.green }
        if isRestDay { return .aura.text3 }
        return .aura.accent
    }
}
