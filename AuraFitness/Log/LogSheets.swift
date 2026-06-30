import SwiftUI

// MARK: - LogCalendarSheet
struct LogCalendarSheet: View {
    @Binding var selectedDate: Date
    let forLogPast: Bool
    let dayInfoFn: (Date) -> DayInfo
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var displayMonth: Date = {
        let c = Calendar.current; return c.date(from: c.dateComponents([.year, .month], from: Date()))!
    }()

    private let monthNames = ["January","February","March","April","May","June","July","August","September","October","November","December"]
    private let shortMonths = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            // Header
            HStack {
                Text(monthNames[Calendar.current.component(.month, from: displayMonth) - 1] + " \(Calendar.current.component(.year, from: displayMonth))")
                    .font(AuraFont.navTitle())
                    .foregroundColor(.aura.text)
                Spacer()
                HStack(spacing: 6) {
                    Button { shiftMonth(-1) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.aura.accent).frame(width: 34, height: 34)
                            .background(Color.aura.fill).clipShape(Circle())
                    }
                    Button { if canGoNext { shiftMonth(1) } } label: {
                        Image(systemName: "chevron.right").font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.aura.accent).opacity(canGoNext ? 1 : 0.28)
                            .frame(width: 34, height: 34).background(Color.aura.fill).clipShape(Circle())
                    }
                    .disabled(!canGoNext)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.aura.text).frame(width: 34, height: 34)
                            .background(Color.aura.fill).clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.vertical, AuraSpacing.s3)

            // Day-of-week header
            HStack {
                ForEach(["S","M","T","W","T","F","S"], id: \.self) { d in
                    Text(d).font(AuraFont.tiny()).fontWeight(.bold).foregroundColor(.aura.text3)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, 6)

            // Calendar grid
            let cells = calendarCells()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let d = date {
                        calCell(d)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fill)
                    }
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)

            // Legend
            HStack(spacing: AuraSpacing.s4) {
                legendItem(color: .aura.green, label: "Completed")
                legendItem(color: .aura.accent, label: "Planned")
                legendItem(color: .aura.text3, label: "Rest")
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s4)

            if !forLogPast {
                AuraPrimaryButton(label: "Go to Today") {
                    selectedDate = Calendar.current.startOfDay(for: Date())
                    dismiss()
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s3)
            }

            Spacer()
        }
        .background(Color.aura.bg)
    }

    var canGoNext: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        let cur = Calendar.current.dateComponents([.year, .month], from: displayMonth)
        return cur.year! < now.year! || (cur.year! == now.year! && cur.month! < now.month!)
    }

    func shiftMonth(_ v: Int) {
        displayMonth = Calendar.current.date(byAdding: .month, value: v, to: displayMonth)!
    }

    func calendarCells() -> [Date?] {
        let cal = Calendar.current
        let first = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth))!
        let startPad = cal.component(.weekday, from: first) - 1
        let days = cal.range(of: .day, in: .month, for: displayMonth)!.count
        var cells: [Date?] = Array(repeating: nil, count: startPad)
        for d in 1...days {
            cells.append(cal.date(byAdding: .day, value: d - 1, to: first))
        }
        return cells
    }

    @ViewBuilder
    func calCell(_ date: Date) -> some View {
        let info = dayInfoFn(date)
        let isToday = Calendar.current.isDateInToday(date)
        let isSel = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isFuture = info.isFuture
        let dayNum = Calendar.current.component(.day, from: date)
        let dotColor = calDotColor(kind: info.kind)

        Button {
            guard !isFuture else { return }
            let iso = info.iso
            withAnimation(.easeInOut(duration: 0.15)) { selectedDate = Calendar.current.startOfDay(for: date) }
            if forLogPast { onSelect(iso) } else { dismiss() }
        } label: {
            VStack(spacing: 2) {
                Text("\(dayNum)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isToday ? .white : (isFuture ? Color.aura.text3.opacity(0.4) : .aura.text))
                if let c = dotColor {
                    Circle().fill(isToday ? Color.white : c).frame(width: 5, height: 5)
                } else {
                    Circle().fill(Color.clear).frame(width: 5, height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .background(
                Group {
                    if isToday { Circle().fill(Color.aura.accent) }
                    else if isSel && !isToday { Circle().stroke(Color.aura.accent, lineWidth: 2) }
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    func calDotColor(kind: DayKind) -> Color? {
        switch kind {
        case .done:            return .aura.green
        case .today, .future:  return .aura.accent
        case .rest, .restToday: return .aura.text3
        case .missed:          return .aura.red
        case .emptyToday:      return nil
        }
    }

    @ViewBuilder
    func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(AuraFont.tiny()).foregroundColor(.aura.text2)
        }
    }
}

// MARK: - AddWorkoutSourceSheet
struct AddWorkoutSourceSheet: View {
    let onStartEmpty: () -> Void
    let onFromProgram: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            Text("Add a Workout")
                .font(AuraFont.navTitle())
                .foregroundColor(.aura.text)
                .padding(.vertical, AuraSpacing.s3)

            VStack(spacing: AuraSpacing.s3) {
                Text("Where should this workout come from?")
                    .font(AuraFont.tiny())
                    .foregroundColor(.aura.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                srcCard(icon: "sparkles", bg: Color.aura.accentSoft, fg: Color.aura.accent,
                        title: "From your programs", sub: "Your active plan & saved programs",
                        action: { onFromProgram() })
                srcCard(icon: "magnifyingglass", bg: Color.aura.green.opacity(0.15), fg: Color.aura.green,
                        title: "From Workout Library", sub: "Pick exercises from scratch",
                        action: { onFromProgram() })
                srcCard(icon: "plus", bg: Color.aura.fill, fg: Color.aura.text2,
                        title: "Empty Workout", sub: "Start blank, add as you go",
                        action: { onStartEmpty() })
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
    }

    @ViewBuilder
    func srcCard(icon: String, bg: Color, fg: Color, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: AuraRadius.md).fill(bg).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundColor(fg)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AuraFont.bodySmall()).fontWeight(.bold).foregroundColor(.aura.text)
                    Text(sub).font(AuraFont.tiny()).foregroundColor(.aura.text2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(.aura.text3)
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WorkoutPickerSheet
struct WorkoutPickerSheet: View {
    @EnvironmentObject var appState: AppState
    let mode: WorkoutPickMode
    let dateISO: String
    let onPick: (UUID) -> Void
    @Environment(\.dismiss) var dismiss

    var allWorkouts: [Workout] {
        ProgramDatabase.shared.allWorkouts
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s3) {
                    ForEach(ProgramDatabase.shared.programs) { prog in
                        VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                            Text(prog.name)
                                .sectionLabelStyle()
                                .padding(.horizontal, AuraSpacing.screenPad)
                            ForEach(prog.workouts) { w in
                                workoutRow(w)
                            }
                        }
                    }
                }
                .padding(.vertical, AuraSpacing.s3)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle(mode == .logPast ? "Pick a Workout" : "Add Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    func workoutRow(_ workout: Workout) -> some View {
        Button {
            onPick(workout.id)
            dismiss()
        } label: {
            HStack(spacing: AuraSpacing.s3) {
                RoundedRectangle(cornerRadius: AuraRadius.md)
                    .fill(Color.aura.fill)
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name).font(AuraFont.bodySmall()).fontWeight(.bold).foregroundColor(.aura.text)
                    Text("\(workout.exercises.count) exercises · \(workout.primaryMuscles)")
                        .font(AuraFont.tiny()).foregroundColor(.aura.text2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(.aura.text3)
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator2, lineWidth: 1))
            .padding(.horizontal, AuraSpacing.screenPad)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ManageTodaySheet
struct ManageTodaySheet: View {
    let info: DayInfo
    let workoutName: String
    let onAction: (ManageTodayAction) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            VStack(spacing: 2) {
                Text(workoutName).font(AuraFont.navTitle()).foregroundColor(.aura.text)
                Text("Planned for today").font(AuraFont.tiny()).foregroundColor(.aura.text2)
            }
            .padding(.vertical, AuraSpacing.s3)

            VStack(spacing: 0) {
                row(icon: "pencil", bg: Color.aura.accent, label: "Edit Workout",
                    sub: "Today's session only · won't change your program") {
                    dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onAction(.edit) }
                }
                divider()
                row(icon: "arrow.left.arrow.right.circle", bg: Color.aura.purple, label: "Move to Another Day",
                    sub: "Today only · your program stays unchanged") {
                    dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onAction(.move) }
                }
                divider()
                row(icon: "arrow.left.arrow.right", bg: Color.aura.blue, label: "Switch Workout",
                    sub: "For today only · your program stays unchanged") {
                    dismiss(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onAction(.switch_) }
                }
                divider()
                row(icon: "moon.fill", bg: Color(red: 0.32, green: 0.32, blue: 0.62), label: "Make it a Rest Day",
                    sub: nil) {
                    dismiss(); onAction(.rest)
                }
                divider()
                row(icon: "trash", bg: Color.aura.red, label: "Remove from Today",
                    sub: nil, danger: true) {
                    dismiss(); onAction(.remove)
                }
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
            .padding(.horizontal, AuraSpacing.screenPad)

            AuraGrayButton(label: "Cancel") { dismiss() }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s3)

            Text("All changes apply to today only and won't affect your program.")
                .font(AuraFont.tiny())
                .foregroundColor(.aura.text3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AuraSpacing.s8)
                .padding(.top, AuraSpacing.s3)
                .padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
    }

    @ViewBuilder
    func row(icon: String, bg: Color, label: String, sub: String?, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(bg).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(AuraFont.bodySmall()).fontWeight(.semibold)
                        .foregroundColor(danger ? .aura.red : .aura.text)
                    if let s = sub {
                        Text(s).font(AuraFont.tiny()).foregroundColor(.aura.text2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(.aura.text3)
            }
            .padding(AuraSpacing.s4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func divider() -> some View {
        Divider().padding(.leading, 56)
    }
}

// MARK: - SwitchWorkoutSheet
struct SwitchWorkoutSheet: View {
    @EnvironmentObject var appState: AppState
    let info: DayInfo
    let onPick: (UUID) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var subPlanID: String? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Active plan workouts
                    if let plan = appState.defaultPlan {
                        Text(plan.name + " (Active)")
                            .sectionLabelStyle()
                            .padding(.horizontal, AuraSpacing.screenPad)
                            .padding(.top, AuraSpacing.s4)

                        ForEach(ProgramDatabase.shared.allWorkouts) { w in
                            workoutRow(w)
                        }
                    }

                    // Other plans
                    Text("Other Plans")
                        .sectionLabelStyle()
                        .padding(.horizontal, AuraSpacing.screenPad)
                        .padding(.top, AuraSpacing.s4)

                    ForEach(ProgramDatabase.shared.programs.filter { prog in !appState.userPlans.contains { $0.sourceProgramID == prog.id } }) { prog in
                        Button {
                            // drill into program
                        } label: {
                            HStack(spacing: AuraSpacing.s3) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: AuraRadius.md).fill(Color.aura.fill).frame(width: 44, height: 44)
                                    Image(systemName: "dumbbell").font(.system(size: 18)).foregroundColor(.aura.text2)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(prog.name).font(AuraFont.bodySmall()).fontWeight(.bold).foregroundColor(.aura.text)
                                    Text("\(prog.workouts.count) workouts").font(AuraFont.tiny()).foregroundColor(.aura.text2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.aura.text3)
                            }
                            .padding(AuraSpacing.s3)
                            .background(Color.aura.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
                            .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator2, lineWidth: 1))
                            .padding(.horizontal, AuraSpacing.screenPad)
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, AuraSpacing.s2)
                    }
                }
                .padding(.bottom, AuraSpacing.s5)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Switch Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    @ViewBuilder
    func workoutRow(_ w: Workout) -> some View {
        Button { onPick(w.id); dismiss() } label: {
            HStack(spacing: AuraSpacing.s3) {
                RoundedRectangle(cornerRadius: AuraRadius.md).fill(Color.aura.fill).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.name).font(AuraFont.bodySmall()).fontWeight(.bold).foregroundColor(.aura.text)
                    Text("\(w.exercises.count) exercises · \(w.primaryMuscles)").font(AuraFont.tiny()).foregroundColor(.aura.text2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.aura.text3)
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator2, lineWidth: 1))
            .padding(.horizontal, AuraSpacing.screenPad)
        }
        .buttonStyle(.plain)
        .padding(.bottom, AuraSpacing.s2)
    }
}

// MARK: - MoveToDaySheet
struct MoveToDaySheet: View {
    let weekDays: [Date]
    let currentInfo: DayInfo
    let dayInfoFn: (Date) -> DayInfo
    let onMove: (String, String) -> Void
    @Environment(\.dismiss) var dismiss

    private let dowFull = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    private let dowShort = ["S","M","T","W","T","F","S"]

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            HStack {
                Text("Move to Another Day")
                    .font(AuraFont.navTitle()).foregroundColor(.aura.text)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.aura.text).frame(width: 34, height: 34)
                        .background(Color.aura.fill).clipShape(Circle())
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.vertical, AuraSpacing.s3)

            Text("Today only · your program stays unchanged")
                .font(AuraFont.tiny()).foregroundColor(.aura.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.bottom, AuraSpacing.s3)

            VStack(spacing: 0) {
                ForEach(Array(weekDays.enumerated()), id: \.offset) { i, date in
                    let info = dayInfoFn(date)
                    let isCurrent = info.iso == currentInfo.iso
                    let dow = Calendar.current.component(.weekday, from: date) - 1
                    let dayNum = Calendar.current.component(.day, from: date)

                    Button {
                        guard !isCurrent else { return }
                        onMove(currentInfo.iso, info.iso)
                        dismiss()
                    } label: {
                        HStack(spacing: AuraSpacing.s3) {
                            VStack(spacing: 1) {
                                Text(dowShort[dow]).font(AuraFont.tiny()).fontWeight(.heavy).foregroundColor(.aura.text3)
                                Text("\(dayNum)").font(.system(size: 13, weight: .bold)).foregroundColor(.aura.text)
                            }
                            .frame(width: 38, height: 38)
                            .background(Color.aura.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 11))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(dowFull[dow] + (isCurrent ? " (today)" : ""))
                                    .font(AuraFont.bodySmall()).fontWeight(.semibold)
                                    .foregroundColor(isCurrent ? .aura.text2 : .aura.text)
                                Text(info.workoutID != nil ? "Has a workout" : "Rest day")
                                    .font(AuraFont.tiny()).foregroundColor(.aura.text2)
                            }
                            Spacer()
                            if !isCurrent {
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.aura.text3)
                            }
                        }
                        .padding(AuraSpacing.s4)
                        .opacity(isCurrent ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCurrent)

                    if i < weekDays.count - 1 { Divider().padding(.leading, 60) }
                }
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
            .padding(.horizontal, AuraSpacing.screenPad)

            AuraGrayButton(label: "Cancel") { dismiss() }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s3)
                .padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
    }
}

// MARK: - EditTodayWorkoutSheet
struct EditTodayWorkoutSheet: View {
    @State var exercises: [LoggedExercise]
    let onSave: ([LoggedExercise]) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s3) {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { i, ex in
                        HStack(spacing: AuraSpacing.s3) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name).font(AuraFont.secondary()).fontWeight(.bold).foregroundColor(.aura.text)
                                Text("\(ex.sets.count) sets").font(AuraFont.tiny()).foregroundColor(.aura.text2)
                            }
                            Spacer()
                            HStack(spacing: AuraSpacing.s2) {
                                Button {
                                    if exercises[i].sets.count > 1 {
                                        exercises[i].sets.removeLast()
                                    }
                                } label: {
                                    Image(systemName: "minus").font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.aura.text).frame(width: 30, height: 30)
                                        .background(Color.aura.fill).clipShape(Circle())
                                }
                                Text("\(exercises[i].sets.count)").font(AuraFont.statNum(size: 15))
                                    .foregroundColor(.aura.text).frame(minWidth: 28, alignment: .center)
                                Text("set").font(AuraFont.tiny()).foregroundColor(.aura.text2)
                                Button {
                                    exercises[i].sets.append(LoggedSet())
                                } label: {
                                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.aura.accent).frame(width: 30, height: 30)
                                        .background(Color.aura.accentSoft).clipShape(Circle())
                                }
                                Button {
                                    exercises.remove(at: i)
                                } label: {
                                    Image(systemName: "trash").font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.aura.red).frame(width: 30, height: 30)
                                        .background(Color.aura.red.opacity(0.1)).clipShape(Circle())
                                }
                            }
                        }
                        .padding(AuraSpacing.s4)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                    }
                }
                .padding(AuraSpacing.screenPad)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save for Today") { onSave(exercises); dismiss() }
                        .fontWeight(.bold).foregroundColor(.aura.accent)
                }
            }
        }
    }
}

// MARK: - LogPastWorkoutSheet
struct LogPastWorkoutSheet: View {
    let dateISO: String
    let showTodayOption: Bool
    let onPickDate: (String) -> Void
    let onPickWorkout: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedISO: String

    init(dateISO: String, showTodayOption: Bool, onPickDate: @escaping (String) -> Void, onPickWorkout: @escaping (String) -> Void) {
        self.dateISO = dateISO
        self.showTodayOption = showTodayOption
        self.onPickDate = onPickDate
        self.onPickWorkout = onPickWorkout
        self._selectedISO = State(initialValue: dateISO)
    }

    var yesterday: String {
        let d = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let c = Calendar.current.dateComponents([.year,.month,.day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    var twoDaysAgo: String {
        let d = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let c = Calendar.current.dateComponents([.year,.month,.day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            HStack {
                Text("Log a Past Workout").font(AuraFont.navTitle()).foregroundColor(.aura.text)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.aura.text).frame(width: 34, height: 34)
                        .background(Color.aura.fill).clipShape(Circle())
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.vertical, AuraSpacing.s3)

            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                    Text("WHEN DID YOU TRAIN?")
                        .font(AuraFont.tiny()).fontWeight(.bold).foregroundColor(.aura.text3).tracking(1)

                    VStack(spacing: 0) {
                        if showTodayOption {
                            dateRow(iso: todayISO(), label: "Log Today's Workout", sub: "Set time · enter your sets", accent: true)
                            Divider().padding(.leading, AuraSpacing.s4)
                        }
                        dateRow(iso: yesterday, label: "Yesterday", sub: relativeDayLabel(yesterday))
                        Divider().padding(.leading, AuraSpacing.s4)
                        dateRow(iso: twoDaysAgo, label: "2 days ago", sub: relativeDayLabel(twoDaysAgo))
                        Divider().padding(.leading, AuraSpacing.s4)
                        Button { onPickDate(selectedISO) } label: {
                            HStack {
                                Text("Pick a date").font(AuraFont.bodySmall()).fontWeight(.semibold).foregroundColor(.aura.text)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.aura.text3)
                            }
                            .padding(AuraSpacing.s4)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))

                    Text("WHICH WORKOUT?")
                        .font(AuraFont.tiny()).fontWeight(.bold).foregroundColor(.aura.text3).tracking(1)

                    VStack(spacing: AuraSpacing.s3) {
                        srcCard(icon: "sparkles", bg: Color.aura.accentSoft, fg: Color.aura.accent,
                                title: "From a Program", sub: "Your active plan & saved programs") { onPickWorkout(selectedISO) }
                        srcCard(icon: "dumbbell", bg: Color.aura.blue.opacity(0.15), fg: Color.aura.blue,
                                title: "A Saved Workout", sub: "Custom & predefined workouts") { onPickWorkout(selectedISO) }
                        srcCard(icon: "magnifyingglass", bg: Color.aura.green.opacity(0.15), fg: Color.aura.green,
                                title: "Build from Library", sub: "Pick exercises from scratch") { onPickWorkout(selectedISO) }
                    }
                }
                .padding(AuraSpacing.screenPad)
            }
        }
        .background(Color.aura.bg)
    }

    func todayISO() -> String {
        let c = Calendar.current.dateComponents([.year,.month,.day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    func relativeDayLabel(_ iso: String) -> String {
        guard let d = isoToDate(iso) else { return iso }
        let fmt = DateFormatter(); fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: d)
    }

    func isoToDate(_ iso: String) -> Date? {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: iso)
    }

    @ViewBuilder
    func dateRow(iso: String, label: String, sub: String, accent: Bool = false) -> some View {
        Button {
            selectedISO = iso
        } label: {
            HStack(spacing: AuraSpacing.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(AuraFont.bodySmall()).fontWeight(.semibold)
                        .foregroundColor(accent ? .aura.accent : .aura.text)
                    Text(sub).font(AuraFont.tiny()).foregroundColor(.aura.text2)
                }
                Spacer()
                if selectedISO == iso {
                    Circle().fill(Color.aura.accent).frame(width: 20, height: 20)
                        .overlay(Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white))
                } else {
                    Circle().stroke(Color.aura.separator, lineWidth: 1.5).frame(width: 20, height: 20)
                }
            }
            .padding(AuraSpacing.s4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func srcCard(icon: String, bg: Color, fg: Color, title: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: AuraRadius.md).fill(bg).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundColor(fg)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AuraFont.bodySmall()).fontWeight(.bold).foregroundColor(.aura.text)
                    Text(sub).font(AuraFont.tiny()).foregroundColor(.aura.text2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.aura.text3)
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ViewLogSheet
struct ViewLogSheet: View {
    let info: DayInfo
    let workout: Workout
    let loggedExsFn: () -> [LoggedExercise]
    let onEdit: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s3) {
                    ForEach(loggedExsFn()) { ex in
                        VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                            Text(ex.name).font(AuraFont.secondary()).fontWeight(.bold).foregroundColor(.aura.text)

                            // Column headers
                            HStack {
                                Text("Set").frame(width: 28, alignment: .leading)
                                Text("Weight").frame(maxWidth: .infinity, alignment: .leading)
                                Text("Reps").frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(AuraFont.tiny()).fontWeight(.bold).foregroundColor(.aura.text3)
                            .textCase(.uppercase).tracking(0.5)

                            ForEach(Array(ex.sets.enumerated()), id: \.element.id) { j, s in
                                HStack {
                                    Text("\(j + 1)").font(AuraFont.tiny()).fontWeight(.bold)
                                        .foregroundColor(.aura.text3).frame(width: 28, alignment: .leading)
                                    Text(s.weight.isEmpty ? "—" : s.weight).font(AuraFont.bodySmall()).fontWeight(.semibold)
                                        .foregroundColor(.aura.text).frame(maxWidth: .infinity, alignment: .leading)
                                    Text(s.reps.isEmpty ? "—" : s.reps).font(AuraFont.bodySmall()).fontWeight(.semibold)
                                        .foregroundColor(.aura.text).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 6)
                                if j < ex.sets.count - 1 { Divider() }
                            }
                        }
                        .padding(AuraSpacing.s4)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                    }

                    AuraGrayButton(label: "Edit Log", icon: "pencil") { onEdit(); dismiss() }
                    AuraGrayButton(label: "Close") { dismiss() }
                }
                .padding(AuraSpacing.screenPad)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Workout Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }
}

// MARK: - EditLogSheet
struct EditLogSheet: View {
    let info: DayInfo
    let workoutName: String
    @State var exercises: [LoggedExercise]
    let onSave: ([LoggedExercise]) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { i, ex in
                        VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                            Text(ex.name).font(AuraFont.secondary()).fontWeight(.bold).foregroundColor(.aura.text)

                            HStack {
                                Text("Set").frame(width: 28, alignment: .leading)
                                Text("Weight").frame(maxWidth: .infinity, alignment: .center)
                                Text("Reps").frame(maxWidth: .infinity, alignment: .center)
                                Spacer().frame(width: 32)
                            }
                            .font(AuraFont.tiny()).fontWeight(.bold).foregroundColor(.aura.text3)
                            .textCase(.uppercase).tracking(0.5)

                            ForEach(Array(exercises[i].sets.enumerated()), id: \.element.id) { j, _ in
                                HStack(spacing: AuraSpacing.s2) {
                                    Text("\(j + 1)").font(AuraFont.tiny()).fontWeight(.bold)
                                        .foregroundColor(.aura.text3).frame(width: 28, alignment: .leading)
                                    TextField("kg", text: Binding(
                                        get: { exercises[i].sets[j].weight },
                                        set: { exercises[i].sets[j].weight = $0 }))
                                    .font(AuraFont.bodySmall()).fontWeight(.bold).foregroundColor(.aura.text)
                                    .multilineTextAlignment(.center).keyboardType(.decimalPad)
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(Color.aura.fill).clipShape(RoundedRectangle(cornerRadius: 8))

                                    TextField("reps", text: Binding(
                                        get: { exercises[i].sets[j].reps },
                                        set: { exercises[i].sets[j].reps = $0 }))
                                    .font(AuraFont.bodySmall()).fontWeight(.bold).foregroundColor(.aura.text)
                                    .multilineTextAlignment(.center).keyboardType(.numberPad)
                                    .frame(maxWidth: .infinity).frame(height: 44)
                                    .background(Color.aura.fill).clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button { exercises[i].sets.remove(at: j) } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 22)).foregroundColor(.aura.red).frame(width: 32, height: 32)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }

                            Button {
                                exercises[i].sets.append(LoggedSet())
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                                    Text("Add Set").font(AuraFont.tiny()).fontWeight(.bold)
                                }
                                .foregroundColor(.aura.accent)
                                .padding(.horizontal, AuraSpacing.s3)
                                .padding(.vertical, 7)
                                .background(Color.aura.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                        .padding(AuraSpacing.s4)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                    }
                }
                .padding(AuraSpacing.screenPad)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Edit Log")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Log") { onSave(exercises) }
                        .fontWeight(.bold).foregroundColor(.aura.accent)
                }
            }
        }
    }
}

// MARK: - QuickLogSheet
struct QuickLogSheet: View {
    let iso: String
    let workoutName: String
    @State var exercises: [LoggedExercise]
    @State var timeString: String = ""
    let onSave: (String, [LoggedExercise]) -> Void
    @Environment(\.dismiss) var dismiss

    init(iso: String, workoutName: String, exercises: [LoggedExercise], onSave: @escaping (String, [LoggedExercise]) -> Void) {
        self.iso = iso
        self.workoutName = workoutName
        self.onSave = onSave
        self._exercises = State(initialValue: exercises)
        let fmt = DateFormatter(); fmt.dateFormat = "HH:mm"
        self._timeString = State(initialValue: fmt.string(from: Date()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    // Time row
                    HStack(spacing: AuraSpacing.s3) {
                        ZStack {
                            Circle().fill(Color.aura.accentSoft).frame(width: 36, height: 36)
                            Image(systemName: "clock").font(.system(size: 17)).foregroundColor(.aura.accent)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("WORKOUT TIME").font(AuraFont.tiny()).fontWeight(.bold).foregroundColor(.aura.text3).tracking(0.5)
                            Text("When did you train?").font(AuraFont.tiny()).foregroundColor(.aura.text2)
                        }
                        Spacer()
                        TextField("HH:mm", text: $timeString)
                            .font(AuraFont.body()).fontWeight(.bold).foregroundColor(.aura.text)
                            .multilineTextAlignment(.center)
                            .frame(width: 72).padding(.horizontal, AuraSpacing.s3).padding(.vertical, AuraSpacing.s2)
                            .background(Color.aura.fill).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(AuraSpacing.s4)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))

                    ForEach(Array(exercises.enumerated()), id: \.element.id) { i, ex in
                        VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                            Text(ex.name).font(AuraFont.secondary()).fontWeight(.bold).foregroundColor(.aura.text)

                            HStack {
                                Text("Set").frame(width: 28, alignment: .leading)
                                Text("Weight").frame(maxWidth: .infinity, alignment: .center)
                                Text("Reps").frame(maxWidth: .infinity, alignment: .center)
                                Spacer().frame(width: 32)
                            }
                            .font(AuraFont.tiny()).fontWeight(.bold).foregroundColor(.aura.text3).textCase(.uppercase).tracking(0.5)

                            ForEach(Array(exercises[i].sets.enumerated()), id: \.element.id) { j, _ in
                                HStack(spacing: AuraSpacing.s2) {
                                    Text("\(j + 1)").font(AuraFont.tiny()).fontWeight(.bold)
                                        .foregroundColor(.aura.text3).frame(width: 28, alignment: .leading)
                                    TextField("kg", text: Binding(
                                        get: { exercises[i].sets[j].weight },
                                        set: { exercises[i].sets[j].weight = $0 }))
                                    .font(AuraFont.bodySmall()).fontWeight(.bold).multilineTextAlignment(.center)
                                    .keyboardType(.decimalPad).frame(maxWidth: .infinity).frame(height: 44)
                                    .background(Color.aura.fill).clipShape(RoundedRectangle(cornerRadius: 8))

                                    TextField("reps", text: Binding(
                                        get: { exercises[i].sets[j].reps },
                                        set: { exercises[i].sets[j].reps = $0 }))
                                    .font(AuraFont.bodySmall()).fontWeight(.bold).multilineTextAlignment(.center)
                                    .keyboardType(.numberPad).frame(maxWidth: .infinity).frame(height: 44)
                                    .background(Color.aura.fill).clipShape(RoundedRectangle(cornerRadius: 8))

                                    Button { exercises[i].sets.remove(at: j) } label: {
                                        Image(systemName: "minus.circle.fill").font(.system(size: 22))
                                            .foregroundColor(.aura.red).frame(width: 32, height: 32)
                                    }.buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                            }

                            Button { exercises[i].sets.append(LoggedSet()) } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                                    Text("Add Set").font(AuraFont.tiny()).fontWeight(.bold)
                                }
                                .foregroundColor(.aura.accent).padding(.horizontal, AuraSpacing.s3)
                                .padding(.vertical, 7).background(Color.aura.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }.buttonStyle(.plain).padding(.top, 4)
                        }
                        .padding(AuraSpacing.s4)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                    }
                }
                .padding(AuraSpacing.screenPad)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Log Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Workout") { onSave(iso, exercises) }
                        .fontWeight(.bold).foregroundColor(.aura.accent)
                }
            }
        }
    }
}
