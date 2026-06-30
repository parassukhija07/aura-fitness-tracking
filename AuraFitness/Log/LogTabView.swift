import SwiftUI

// MARK: - DayInfo (dayInfo() output)
struct DayInfo {
    let iso: String
    let date: Date
    let kind: DayKind
    let workoutID: UUID?
    let override: DayOverride?
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var isFuture: Bool { date > Calendar.current.startOfDay(for: Date()) }
    var isPast: Bool   { date < Calendar.current.startOfDay(for: Date()) }
}

// MARK: - LogTabView
struct LogTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var activeSheet: LogSheet? = nil
    @State private var toastMessage: String? = nil

    // MARK: dayInfo
    func dayInfo(_ date: Date) -> DayInfo {
        let iso = isoString(date)
        let ov = appState.override(for: iso)
        let today = Calendar.current.startOfDay(for: Date())
        let day = Calendar.current.startOfDay(for: date)

        // Resolve workoutID from plan, then apply override
        var wid: UUID? = appState.defaultPlan.flatMap { plan in
            let dow = Calendar.current.component(.weekday, from: date) - 1
            guard let entry = plan.weekSchedule[dow] else { return nil }
            return entry
        }
        if let ov {
            switch ov.type {
            case .switched, .added, .logged, .edit:
                wid = ov.workoutID ?? wid
            case .rest, .removed:
                wid = nil
            }
        }

        let rel: Int = day < today ? -1 : day > today ? 1 : 0

        let kind: DayKind
        if wid == nil {
            if rel == 0 {
                kind = (ov?.type == .removed) ? .emptyToday : .restToday
            } else {
                kind = .rest
            }
        } else {
            switch rel {
            case 0:  kind = .today
            case 1:  kind = .future
            default:
                let hasLog = appState.workoutLogs.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
                let wasLogged = ov?.type == .logged
                kind = (hasLog || wasLogged) ? .done : .missed
            }
        }

        return DayInfo(iso: iso, date: date, kind: kind, workoutID: wid, override: ov)
    }

    // MARK: Helpers
    func isoString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    func resolvedWorkout(for info: DayInfo) -> Workout? {
        guard let wid = info.workoutID else { return nil }
        if let ov = info.override, ov.type == .switched || ov.type == .added {
            if let wid2 = ov.workoutID {
                return findWorkout(id: wid2)
            }
        }
        return findWorkout(id: wid)
    }

    func findWorkout(id: UUID) -> Workout? {
        for plan in appState.userPlans {
            if let w = plan.customWorkouts.first(where: { $0.id == id }) { return w }
        }
        return ProgramDatabase.shared.workout(id: id)
    }

    // MARK: Week navigation
    var weekStart: Date {
        let today = Calendar.current.startOfDay(for: selectedDate)
        let dow = Calendar.current.component(.weekday, from: today) - 1
        let offset = appState.calendarStartDay == 1 ? (dow == 0 ? -6 : -(dow - 1)) : -dow
        return Calendar.current.date(byAdding: .day, value: offset, to: today)!
    }

    var weekDays: [Date] {
        (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: weekStart)! }
    }

    var rangeLabel: String {
        let end = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
        let mf = DateFormatter(); mf.dateFormat = "MMM"
        let df = DateFormatter(); mf.dateFormat = "d"
        let sm = mf.string(from: weekStart), em = mf.string(from: end)
        let sd = Calendar.current.component(.day, from: weekStart)
        let ed = Calendar.current.component(.day, from: end)
        let ssm = shortMonth(weekStart), sem = shortMonth(end)
        return ssm == sem ? "\(ssm) \(sd) – \(ed)" : "\(ssm) \(sd) – \(sem) \(ed)"
    }

    func shortMonth(_ d: Date) -> String {
        ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][Calendar.current.component(.month, from: d) - 1]
    }

    var isCurrentWeek: Bool {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let dow = Calendar.current.component(.weekday, from: todayStart) - 1
        let offset = appState.calendarStartDay == 1 ? (dow == 0 ? -6 : -(dow - 1)) : -dow
        let thisWeek = Calendar.current.date(byAdding: .day, value: offset, to: todayStart)!
        return weekStart == thisWeek
    }

    var navTitle: String {
        Calendar.current.isDateInToday(selectedDate) ? "Today" : selectedDate.formatted(.dateTime.weekday(.wide))
    }

    var navSub: String {
        selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()).uppercased()
    }

    // MARK: Flash toast
    func flash(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation { if toastMessage == msg { toastMessage = nil } }
        }
    }

    // MARK: Body
    var body: some View {
        let info = dayInfo(selectedDate)
        let workout = resolvedWorkout(for: info)

        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Nav bar
                logNavBar(info: info)

                // Week bar
                WeekBarView(
                    selectedDate: $selectedDate,
                    weekDays: weekDays,
                    rangeLabel: rangeLabel,
                    isCurrentWeek: isCurrentWeek,
                    dayInfoFn: dayInfo,
                    onPrevWeek: {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate)!
                    },
                    onNextWeek: {
                        if !isCurrentWeek {
                            selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate)!
                        }
                    },
                    onToday: { selectedDate = Calendar.current.startOfDay(for: Date()) }
                )

                // Day body
                ScrollView {
                    VStack(spacing: 0) {
                        dayBody(info: info, workout: workout)
                    }
                    .padding(.bottom, 120)
                }
                .background(Color.aura.bgGrouped)
            }
            .background(Color.aura.bgGrouped)

            // Toast
            if let msg = toastMessage {
                Text(msg)
                    .font(AuraFont.secondary())
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIColor.systemBackground))
                    .padding(.horizontal, AuraSpacing.s4)
                    .padding(.vertical, AuraSpacing.s3)
                    .background(Color.aura.text)
                    .clipShape(Capsule())
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(90)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            sheetView(sheet, info: info, workout: workout)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Nav bar
    @ViewBuilder
    private func logNavBar(info: DayInfo) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text(navSub)
                    .font(AuraFont.tiny())
                    .fontWeight(.bold)
                    .foregroundColor(.aura.text2)
                    .tracking(0.5)
                Text(navTitle)
                    .font(AuraFont.largeTitleStyle())
                    .foregroundColor(.aura.text)
            }
            Spacer()
            Button {
                activeSheet = .calendar(forLogPast: false)
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.aura.accent)
                    .frame(width: 34, height: 34)
                    .background(Color.aura.fill2)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.top, AuraSpacing.s2)
        .padding(.bottom, AuraSpacing.s3)
    }

    // MARK: Day body by kind
    @ViewBuilder
    private func dayBody(info: DayInfo, workout: Workout?) -> some View {
        switch info.kind {
        case .restToday, .rest, .emptyToday:
            restOrEmptyBody(info: info)
        case .today:
            if let w = workout { todayBody(info: info, workout: w) }
        case .done:
            if let w = workout { doneBody(info: info, workout: w) }
        case .missed:
            if let w = workout { missedBody(info: info, workout: w) }
        case .future:
            if let w = workout { futureBody(info: info, workout: w) }
        }
    }

    // MARK: Rest / Empty body
    @ViewBuilder
    private func restOrEmptyBody(info: DayInfo) -> some View {
        let isEmpty = info.kind == .emptyToday
        VStack(spacing: AuraSpacing.s4) {
            AuraCard {
                VStack(spacing: AuraSpacing.s4) {
                    ZStack {
                        Circle()
                            .fill(isEmpty ? Color.aura.accentSoft : Color.aura.fill)
                            .frame(width: 64, height: 64)
                        Image(systemName: isEmpty ? "plus" : "moon.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(isEmpty ? .aura.accent : .aura.text2)
                    }
                    Text(isEmpty ? "Nothing planned" : "Rest Day")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.aura.text)
                    Text(isEmpty
                         ? "No workout scheduled. Start something fresh or log a session you already did."
                         : "Recovery is where the gains happen. Nothing scheduled\(info.isToday ? " today" : "").")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AuraSpacing.s4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AuraSpacing.s10)
            }
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.xl)
                    .stroke(style: isEmpty ? StrokeStyle(lineWidth: 1.5, dash: [6]) : StrokeStyle(lineWidth: 1))
                    .foregroundColor(Color.aura.separator)
            )

            if !info.isFuture {
                AuraTintedButton(
                    label: info.isToday ? "Add a Workout" : "Log a Workout",
                    icon: "plus"
                ) {
                    activeSheet = info.isToday ? .addWorkout : .pickWorkout(mode: .logPast, dateISO: info.iso)
                }

                if info.isToday {
                    AuraGrayButton(label: "Log a Past Workout", icon: "clock") {
                        activeSheet = .logPast(dateISO: isoString(Calendar.current.date(byAdding: .day, value: -1, to: Date())!), showTodayOption: false)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: AuraSpacing.s3) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.aura.text2)
                    Text("Scheduled rest day. Enjoy the recovery — your next session is just around the corner.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(AuraSpacing.s4)
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.top, AuraSpacing.s2)
    }

    // MARK: Today body
    @ViewBuilder
    private func todayBody(info: DayInfo, workout: Workout) -> some View {
        VStack(spacing: AuraSpacing.s4) {
            programBadges(info: info, extra: [])

            workoutCard(workout: workout, info: info, dim: false) {
                Button {
                    activeSheet = .manageToday(info: info)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.aura.text)
                        .frame(width: 34, height: 34)
                        .background(Color.aura.fill)
                        .clipShape(Circle())
                }
            }

            AuraPrimaryButton(label: "Start Workout", icon: "play.fill") {
                appState.startWorkout(workout)
            }

            HStack(spacing: AuraSpacing.s3) {
                AuraGrayButton(label: "Log past", icon: "clock") {
                    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
                    activeSheet = .logPast(dateISO: isoString(yesterday), showTodayOption: true)
                }
                AuraGrayButton(label: "Switch", icon: "arrow.left.arrow.right") {
                    activeSheet = .switchWorkout(info: info)
                }
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.top, AuraSpacing.s2)
    }

    // MARK: Done body
    @ViewBuilder
    private func doneBody(info: DayInfo, workout: Workout) -> some View {
        VStack(spacing: AuraSpacing.s4) {
            programBadges(info: info, extra: [(.green, "checkmark", "Completed")])

            workoutCard(workout: workout, info: info, dim: false) {
                ZStack {
                    Circle()
                        .fill(Color.aura.green.opacity(0.14))
                        .frame(width: 32, height: 32)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.aura.green)
                }
            }

            AuraPrimaryButton(label: "View Log", icon: "note.text") {
                activeSheet = .viewLog(info: info, workout: workout)
            }
            AuraGrayButton(label: "Edit Log", icon: "pencil") {
                let exs = loggedExercises(info: info, workout: workout)
                activeSheet = .editLog(info: info, workout: workout, exercises: exs)
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.top, AuraSpacing.s2)
    }

    // MARK: Missed body
    @ViewBuilder
    private func missedBody(info: DayInfo, workout: Workout) -> some View {
        VStack(spacing: AuraSpacing.s4) {
            programBadges(info: info, extra: [(.red, "xmark", "Missed")])

            workoutCard(workout: workout, info: info, dim: true) {
                ZStack {
                    Circle()
                        .fill(Color.aura.red.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.aura.red)
                }
            }

            AuraPrimaryButton(label: "Log Workout", icon: "clock") {
                activeSheet = .pickWorkout(mode: .logPast, dateISO: info.iso)
            }
            AuraGrayButton(label: "Mark as Rest Day", icon: "moon.fill") {
                appState.setOverride(info.iso, DayOverride(type: .rest, workoutID: nil))
                flash("Marked as rest day")
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.top, AuraSpacing.s2)
    }

    // MARK: Future body
    @ViewBuilder
    private func futureBody(info: DayInfo, workout: Workout) -> some View {
        VStack(spacing: AuraSpacing.s4) {
            programBadges(info: info, extra: [])

            workoutCard(workout: workout, info: info, dim: true) {
                Text("View only")
                    .font(AuraFont.tiny())
                    .fontWeight(.bold)
                    .foregroundColor(.aura.text3)
                    .padding(.horizontal, AuraSpacing.s3)
                    .padding(.vertical, 5)
                    .background(Color.aura.fill)
                    .clipShape(Capsule())
            }

            AuraGrayButton(label: "View Workout", icon: "eye") { }

            HStack(alignment: .top, spacing: AuraSpacing.s3) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.aura.accent)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Future workouts are read-only")
                        .font(AuraFont.secondary())
                        .fontWeight(.bold)
                        .foregroundColor(.aura.text)
                    Text("To change this workout, edit your program in the Plans tab.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
            }
            .padding(AuraSpacing.s4)
            .background(Color.aura.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.accent.opacity(0.22), lineWidth: 1))
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.top, AuraSpacing.s2)
    }

    // MARK: Shared sub-views
    @ViewBuilder
    private func programBadges(info: DayInfo, extra: [(Color, String, String)]) -> some View {
        let planName = appState.defaultPlan?.name ?? "No Plan"
        FlowLayout(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                Text(planName)
                    .font(AuraFont.tiny())
                    .fontWeight(.bold)
            }
            .foregroundColor(.aura.accent)
            .padding(.horizontal, AuraSpacing.s3)
            .padding(.vertical, 5)
            .background(Color.aura.accentSoft)
            .clipShape(Capsule())

            ForEach(extra, id: \.2) { color, icon, label in
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(label)
                        .font(AuraFont.tiny())
                        .fontWeight(.bold)
                }
                .foregroundColor(color)
                .padding(.horizontal, AuraSpacing.s3)
                .padding(.vertical, 5)
                .background(color.opacity(0.13))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func workoutCard(workout: Workout, info: DayInfo, dim: Bool, @ViewBuilder trailing: () -> some View) -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.name)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundColor(.aura.text)
                        HStack(spacing: 4) {
                            Text("\(workout.exercises.count) exercises")
                            Text("·")
                            Text(workout.primaryMuscles)
                        }
                        .font(AuraFont.tiny())
                        .foregroundColor(.aura.text2)
                    }
                    Spacer()
                    trailing()
                }

                Divider().foregroundColor(.aura.separator2)

                exercisePreviewList(exercises: workout.exercises, dim: dim)
            }
            .padding(AuraSpacing.s4)
        }
        .opacity(dim ? 0.7 : 1)
    }

    @ViewBuilder
    private func exercisePreviewList(exercises: [Exercise], dim: Bool) -> some View {
        let preview = Array(exercises.prefix(5))
        VStack(spacing: AuraSpacing.s3) {
            ForEach(Array(preview.enumerated()), id: \.offset) { i, ex in
                HStack(spacing: AuraSpacing.s3) {
                    Text("\(i + 1)")
                        .font(AuraFont.tiny())
                        .fontWeight(.bold)
                        .foregroundColor(.aura.text2)
                        .frame(width: 22, height: 22)
                        .background(Color.aura.fill)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(ex.name)
                            .font(AuraFont.bodySmall())
                            .fontWeight(.semibold)
                            .foregroundColor(.aura.text)
                        Text("\(ex.plannedSets) sets · \(ex.repRange) reps")
                            .font(AuraFont.tiny())
                            .foregroundColor(.aura.text2)
                    }
                }
            }
            if exercises.count > 5 {
                Text("+\(exercises.count - 5) more exercises")
                    .font(AuraFont.tiny())
                    .foregroundColor(.aura.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 34)
            }
        }
        .opacity(dim ? 0.6 : 1)
    }

    // MARK: Logged exercise helper
    private func loggedExercises(info: DayInfo, workout: Workout) -> [LoggedExercise] {
        if let ovEx = info.override?.exercises { return ovEx }
        return workout.exercises.map { ex in
            LoggedExercise(name: ex.name, sets: (0..<ex.plannedSets).map { _ in LoggedSet() })
        }
    }

    // MARK: Sheet dispatcher
    @ViewBuilder
    private func sheetView(_ sheet: LogSheet, info: DayInfo, workout: Workout?) -> some View {
        switch sheet {
        case .calendar(let forLogPast):
            LogCalendarSheet(
                selectedDate: $selectedDate,
                forLogPast: forLogPast,
                dayInfoFn: dayInfo
            ) { iso in
                if forLogPast {
                    activeSheet = .logPast(dateISO: iso, showTodayOption: false)
                } else {
                    activeSheet = nil
                }
            }
            .presentationDetents([.fraction(0.72)])

        case .addWorkout:
            AddWorkoutSourceSheet(onStartEmpty: {
                let w = Workout(name: "My Workout", primaryMuscles: "Full Body", estimatedMinutes: 0, exercises: [])
                appState.startWorkout(w)
                activeSheet = nil
            }, onFromProgram: {
                activeSheet = .pickWorkout(mode: .add, dateISO: info.iso)
            })
            .presentationDetents([.fraction(0.55)])

        case .pickWorkout(let mode, let dateISO):
            WorkoutPickerSheet(mode: mode, dateISO: dateISO ?? info.iso) { wid in
                let overrideType: DayOverrideType = mode == .logPast ? .logged : (info.isPast ? .logged : .added)
                appState.setOverride(dateISO ?? info.iso, DayOverride(type: overrideType, workoutID: wid))
                activeSheet = nil
                flash(mode == .logPast ? "Past workout logged" : "Workout added")
            }
            .presentationDetents([.large])

        case .manageToday(let info):
            ManageTodaySheet(info: info, workoutName: workout?.name ?? "") { action in
                handleManageAction(action, info: info)
            }
            .presentationDetents([.fraction(0.62)])

        case .switchWorkout(let info):
            SwitchWorkoutSheet(info: info) { wid in
                appState.setOverride(info.iso, DayOverride(type: .switched, workoutID: wid))
                activeSheet = nil
                flash("Switched workout")
            }
            .presentationDetents([.large])

        case .moveToDay(let info):
            MoveToDaySheet(weekDays: weekDays, currentInfo: info, dayInfoFn: dayInfo) { fromISO, toISO in
                appState.setOverride(fromISO, DayOverride(type: .removed, workoutID: nil))
                appState.setOverride(toISO, DayOverride(type: .added, workoutID: info.workoutID))
                activeSheet = nil
                flash("Workout moved")
            }
            .presentationDetents([.fraction(0.65)])

        case .editTodayWorkout(let info, let exercises):
            EditTodayWorkoutSheet(exercises: exercises) { updated in
                var ov = info.override ?? DayOverride(type: .edit, workoutID: info.workoutID)
                ov.type = .edit
                ov.exercises = updated
                appState.setOverride(info.iso, ov)
                activeSheet = nil
                flash("Workout updated for today")
            }
            .presentationDetents([.large])

        case .logPast(let dateISO, let showTodayOption):
            LogPastWorkoutSheet(
                dateISO: dateISO,
                showTodayOption: showTodayOption,
                onPickDate: { iso in activeSheet = .calendar(forLogPast: true) },
                onPickWorkout: { iso in activeSheet = .pickWorkout(mode: .logPast, dateISO: iso) }
            )
            .presentationDetents([.fraction(0.72)])

        case .viewLog(let info, let workout):
            ViewLogSheet(info: info, workout: workout, loggedExsFn: { loggedExercises(info: info, workout: workout) }) {
                let exs = loggedExercises(info: info, workout: workout)
                activeSheet = .editLog(info: info, workout: workout, exercises: exs)
            }
            .presentationDetents([.large])

        case .editLog(let info, let workout, let exercises):
            EditLogSheet(info: info, workoutName: workout.name, exercises: exercises) { updated in
                var ov = info.override ?? DayOverride(type: .logged, workoutID: info.workoutID)
                ov.type = .logged
                ov.exercises = updated
                appState.setOverride(info.iso, ov)
                activeSheet = nil
                flash("Log saved")
            }
            .presentationDetents([.large])

        case .quickLog(let iso, let exercises):
            QuickLogSheet(iso: iso, workoutName: workout?.name ?? "", exercises: exercises) { iso, logged in
                var ov = appState.override(for: iso) ?? DayOverride(type: .logged, workoutID: info.workoutID)
                ov.type = .logged
                ov.exercises = logged
                appState.setOverride(iso, ov)
                activeSheet = nil
                flash("Workout logged!")
            }
            .presentationDetents([.large])
        }
    }

    // MARK: Manage today action handler
    private func handleManageAction(_ action: ManageTodayAction, info: DayInfo) {
        activeSheet = nil
        switch action {
        case .edit:
            let exs = info.override?.exercises ?? resolvedWorkout(for: info).map { w in
                w.exercises.map { ex in LoggedExercise(name: ex.name, sets: (0..<ex.plannedSets).map { _ in LoggedSet() }) }
            } ?? []
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                activeSheet = .editTodayWorkout(info: info, exercises: exs)
            }
        case .move:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                activeSheet = .moveToDay(info: info)
            }
        case .switch_:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                activeSheet = .switchWorkout(info: info)
            }
        case .rest:
            appState.setOverride(info.iso, DayOverride(type: .rest, workoutID: nil))
            flash("Marked as rest day")
        case .remove:
            appState.setOverride(info.iso, DayOverride(type: .removed, workoutID: nil))
            flash("Removed from today")
        }
    }
}

// MARK: - LogSheet enum
enum LogSheet: Identifiable {
    case calendar(forLogPast: Bool)
    case addWorkout
    case pickWorkout(mode: WorkoutPickMode, dateISO: String?)
    case manageToday(info: DayInfo)
    case switchWorkout(info: DayInfo)
    case moveToDay(info: DayInfo)
    case editTodayWorkout(info: DayInfo, exercises: [LoggedExercise])
    case logPast(dateISO: String, showTodayOption: Bool)
    case viewLog(info: DayInfo, workout: Workout)
    case editLog(info: DayInfo, workout: Workout, exercises: [LoggedExercise])
    case quickLog(iso: String, exercises: [LoggedExercise])

    var id: String {
        switch self {
        case .calendar:        return "calendar"
        case .addWorkout:      return "addWorkout"
        case .pickWorkout:     return "pickWorkout"
        case .manageToday:     return "manageToday"
        case .switchWorkout:   return "switchWorkout"
        case .moveToDay:       return "moveToDay"
        case .editTodayWorkout: return "editTodayWorkout"
        case .logPast:         return "logPast"
        case .viewLog:         return "viewLog"
        case .editLog:         return "editLog"
        case .quickLog:        return "quickLog"
        }
    }
}

enum WorkoutPickMode { case add, logPast }
enum ManageTodayAction { case edit, move, switch_, rest, remove }

// MARK: - FlowLayout (badge wrap)
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        for (idx, frame) in result.frames.enumerated() {
            subviews[idx].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxW = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxW, x > 0 {
                x = 0; y += rowH + spacing; rowH = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return (CGSize(width: maxW, height: y + rowH), frames)
    }
}
