import SwiftUI

struct CalendarSheetView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedDate: Date
    @State private var displayedMonth: Date = Date()
    @Environment(\.dismiss) var dismiss

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month navigation
                HStack {
                    Button {
                        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.aura.accent)
                    }

                    Spacer()

                    Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                        .font(AuraFont.navTitle())
                        .foregroundColor(.aura.text)

                    Spacer()

                    Button {
                        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.aura.accent)
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.vertical, AuraSpacing.s3)

                // Day header
                HStack {
                    ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                        Text(d)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text3)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.bottom, AuraSpacing.s2)

                // Calendar grid
                let days = calendarDays()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        dayCell(day: day)
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)

                Spacer()

                Button {
                    selectedDate = Date()
                    displayedMonth = Date()
                    dismiss()
                } label: {
                    Text("Go to Today")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.accent)
                }
                .padding(.bottom, AuraSpacing.s5)
            }
            .background(Color.aura.bg)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: Date?) -> some View {
        if let day = day {
            let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
            let isToday = calendar.isDateInToday(day)
            let hasLog = appState.hasLog(for: day)
            let dayNum = calendar.component(.day, from: day)

            Button {
                selectedDate = day
                dismiss()
            } label: {
                VStack(spacing: 3) {
                    Text("\(dayNum)")
                        .font(.system(size: 14, weight: isToday ? .heavy : .medium))
                        .foregroundColor(isSelected ? .white : (isToday ? .aura.accent : .aura.text))

                    if hasLog {
                        Circle()
                            .fill(Color.aura.green)
                            .frame(width: 4, height: 4)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(width: 38, height: 38)
                .background(isSelected ? Color.aura.accent : Color.clear)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
        } else {
            Color.clear
                .frame(width: 38, height: 38)
        }
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
        // Pad to complete grid
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }
}
