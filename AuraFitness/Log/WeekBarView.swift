import SwiftUI

struct WeekBarView: View {
    @Binding var selectedDate: Date
    let weekDays: [Date]
    let rangeLabel: String
    let isCurrentWeek: Bool
    let dayInfoFn: (Date) -> DayInfo
    let onPrevWeek: () -> Void
    let onNextWeek: () -> Void
    let onToday: () -> Void

    private let dayLetters = ["S","M","T","W","T","F","S"]

    var body: some View {
        VStack(spacing: 0) {
            // Range header
            HStack {
                HStack(spacing: 4) {
                    Button(action: onPrevWeek) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.aura.text)
                            .frame(width: 28, height: 28)
                            .background(Color.aura.fill)
                            .clipShape(Circle())
                    }
                    Text(rangeLabel)
                        .font(AuraFont.secondary())
                        .fontWeight(.bold)
                        .foregroundColor(.aura.text)
                    Button(action: onNextWeek) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.aura.text)
                            .opacity(isCurrentWeek ? 0.28 : 1)
                            .frame(width: 28, height: 28)
                            .background(Color.aura.fill)
                            .clipShape(Circle())
                    }
                    .disabled(isCurrentWeek)
                }

                Spacer()

                let isTodaySelected = Calendar.current.isDateInToday(selectedDate)
                if !isCurrentWeek || !isTodaySelected {
                    Button("Today ›", action: onToday)
                        .font(AuraFont.tiny())
                        .fontWeight(.bold)
                        .foregroundColor(.aura.accent)
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, AuraSpacing.s2)

            // Day cells
            HStack(spacing: 4) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { i, date in
                    let info = dayInfoFn(date)
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    dayCell(date: date, info: info, selected: isSelected)
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
        }
        .padding(.vertical, AuraSpacing.s2)
    }

    @ViewBuilder
    private func dayCell(date: Date, info: DayInfo, selected: Bool) -> some View {
        let dow = Calendar.current.component(.weekday, from: date) - 1
        let letter = dayLetters[dow]
        let dayNum = Calendar.current.component(.day, from: date)

        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = Calendar.current.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 3) {
                Text(letter)
                    .font(AuraFont.tiny())
                    .fontWeight(.bold)
                    .foregroundColor(selected ? .white.opacity(0.85) : .aura.text3)

                Text("\(dayNum)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(selected ? .white : .aura.text)

                dotView(kind: info.kind, selected: selected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AuraSpacing.s2)
            .background(selected ? Color.aura.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dotView(kind: DayKind, selected: Bool) -> some View {
        let dotColor: Color? = {
            switch kind {
            case .done:                return selected ? .white : .aura.green
            case .today, .future:      return selected ? .white : .aura.accent
            case .missed:              return selected ? .white : .aura.red
            case .rest, .restToday:    return selected ? .white.opacity(0.5) : .aura.text3
            case .emptyToday:          return nil
            }
        }()

        Circle()
            .fill(dotColor ?? Color.clear)
            .frame(width: 5, height: 5)
    }
}
