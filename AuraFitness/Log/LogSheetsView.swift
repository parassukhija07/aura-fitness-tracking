import SwiftUI

// MARK: - Log sheet host (mirrors combined/log.jsx sheetEl())

struct LogSheetsView: View {
    @EnvironmentObject var appState: AppState
    let sheet: LogSheet
    @Binding var selected: Date
    @Binding var parentSheet: LogSheet?
    let flash: (String) -> Void

    private let cal = Calendar.current
    private let dowFull = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
    private let dowShort = ["S","M","T","W","T","F","S"]
    private let monShort = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    private let monFull = ["January","February","March","April","May","June","July","August","September","October","November","December"]

    private var info: AppState.DayInfo { appState.dayInfo(for: selected) }
    private var isToday: Bool { cal.isDate(selected, inSameDayAs: cal.startOfDay(for: Date())) }

    // MARK: Build-from-library state
    @StateObject private var exerciseDB = ExerciseDatabase.shared
    @State private var libQuery = ""
    @State private var libCategory = "All"
    @State private var libSelected: [UUID] = []

    /// All assignable workouts from the active program (for pick/switch).
    private var programWorkouts: [Workout] {
        appState.defaultPlan.flatMap { plan in
            ProgramDatabase.shared.programs.first { $0.id == plan.sourceProgramID }?.workouts
        } ?? ProgramDatabase.shared.programs.first?.workouts ?? []
    }

    var body: some View {
        Group {
            switch sheet {
            case .menu:                          menuSheet
            case .switchWorkout(let planId):     switchSheet(planId: planId)
            case .move:                          moveSheet
            case .edit:                          editSheet
            case .add:                           addSheet
            case .logPast(let date, let show):   logPastSheet(date: date, showToday: show)
            case .pick(let mode, let date):      pickSheet(mode: mode, date: date)
            case .buildFromLibrary(let mode, let date): buildFromLibrarySheet(mode: mode, date: date)
            case .calendar(let forLogPast):      calendarSheet(forLogPast: forLogPast)
            case .viewLog:                       viewLogSheet
            case .editLog:                       editLogSheet
            case .logQuick(let iso):             logQuickSheet(iso: iso)
            case .viewWorkout(let iso):          viewWorkoutSheet(iso: iso)
            }
        }
        .id(sheet.id)
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.easeInOut(duration: 0.28), value: sheet.id)
        .presentationDetents(detents)
    }

    /// Per-sheet detents: compact sheets fit their content; tall/scrolling sheets get full height.
    private var detents: Set<PresentationDetent> {
        switch sheet {
        case .menu:
            // Compact bottom sheet — sized to the 5-row menu, not full screen.
            return [.fraction(0.55)]
        case .move, .add:
            return [.medium, .large]
        default:
            return [.large]
        }
    }

    // MARK: Reusable chrome

    private func grabber() -> some View { SheetGrabber() }

    private func sheetHeader(_ title: String, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(AuraFont.navTitle()).foregroundColor(.aura.text)
            if let sub { Text(sub).font(AuraFont.jakarta(12)).foregroundColor(.aura.text2) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AuraSpacing.screenPad)
    }

    private func workoutRow(_ w: Workout, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: AuraRadius.md)
                    .fill(Color.aura.surface2)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "dumbbell.fill").foregroundColor(.aura.text3).font(AuraFont.jakarta(16)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.name).font(AuraFont.jakarta(15, .bold)).foregroundColor(.aura.text)
                    Text("\(w.exercises.count) exercises · \(w.primaryMuscles)")
                        .font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(AuraFont.jakarta(14)).foregroundColor(.aura.text3)
            }
            .padding(13)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func menuRow(icon: String, bg: Color, label: String, sub: String? = nil,
                         danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AuraRadius.xs).fill(bg).frame(width: 30, height: 30)
                    Image(systemName: icon).foregroundColor(.white).font(AuraFont.jakarta(15, .semibold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(AuraFont.jakarta(16, .medium)).foregroundColor(danger ? .aura.red : .aura.text)
                    if let sub { Text(sub).font(AuraFont.jakarta(13)).foregroundColor(.aura.text2) }
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func srcCard(icon: String, bg: Color, color: Color, title: String, sub: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: AuraRadius.md).fill(bg).frame(width: 44, height: 44)
                    Image(systemName: icon).foregroundColor(color).font(AuraFont.jakarta(20))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AuraFont.jakarta(15, .bold)).foregroundColor(.aura.text)
                    Text(sub).font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(AuraFont.jakarta(14)).foregroundColor(.aura.text3)
            }
            .padding(13)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func assign(_ wid: UUID, mode: LogSheet.PickMode, dateIso: String) {
        let kind: DayOverride.Kind
        switch mode {
        case .logpast: kind = .logged
        default:
            // past day → logged, else added/switched
            let di = appState.dayInfo(for: dateFromIso(dateIso))
            kind = di.relation == .past ? .logged : (mode == .switchMode ? .switched : .added)
        }
        appState.setOverride(DayOverride(kind: kind, workoutId: wid), for: dateIso)
        selected = dateFromIso(dateIso)
        parentSheet = nil
        flash(mode == .logpast ? "Past workout logged" : (mode == .switchMode ? "Workout switched" : "Workout added"))
    }

    private func dateFromIso(_ iso: String) -> Date {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.date(from: iso).map { cal.startOfDay(for: $0) } ?? selected
    }

    // MARK: Menu sheet

    private var menuSheet: some View {
        ScrollView {
            VStack(spacing: 0) {
                grabber()
                VStack(spacing: 2) {
                    Text(info.workout?.name ?? "Workout").font(AuraFont.jakarta(15, .bold)).foregroundColor(.aura.text)
                    Text("Planned for today").font(AuraFont.jakarta(12)).foregroundColor(.aura.text2)
                }
                .padding(.vertical, AuraSpacing.s3)

                VStack(spacing: 0) {
                    menuRow(icon: "pencil", bg: .aura.accent, label: "Edit Workout",
                            sub: "Today's session only · won't change your program") { parentSheet = .edit }
                    Divider().padding(.leading, 58)
                    menuRow(icon: "calendar", bg: .aura.purple, label: "Move to Another Day",
                            sub: "Today only · your program stays unchanged") { parentSheet = .move }
                    Divider().padding(.leading, 58)
                    menuRow(icon: "arrow.left.arrow.right", bg: .aura.blue, label: "Switch Workout",
                            sub: "For today only · your program stays unchanged") { parentSheet = .switchWorkout() }
                    Divider().padding(.leading, 58)
                    menuRow(icon: "moon.fill", bg: Color(hex: "#5A6B8C"), label: "Make it a Rest Day") {
                        appState.setOverride(DayOverride(kind: .rest), for: info.iso); parentSheet = nil; flash("Marked as rest day")
                    }
                    Divider().padding(.leading, 58)
                    menuRow(icon: "trash", bg: .aura.red, label: "Remove from Today", danger: true) {
                        // → empty-today ("Nothing planned" dashed card), per 03-log §sh-menu.
                        appState.setOverride(DayOverride(kind: .removed), for: info.iso); parentSheet = nil; flash("Removed from today")
                    }
                }
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.horizontal, AuraSpacing.screenPad)

                Text("All changes apply to today only and won't affect your program.")
                    .font(AuraFont.jakarta(12)).foregroundColor(.aura.text2)
                    .multilineTextAlignment(.center)
                    .padding(.top, AuraSpacing.s3).padding(.horizontal, AuraSpacing.s6)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
    }

    // MARK: Switch sheet (two levels — mirrors log.jsx switch-v2)

    /// The program the active plan is built from (level-1 "Active" section).
    private var activeProgram: Program? {
        guard let pid = appState.defaultPlan?.sourceProgramID else { return ProgramDatabase.shared.programs.first }
        return ProgramDatabase.shared.programs.first { $0.id == pid }
    }
    /// Every other predefined program, surfaced as drill-in "Other Plans" rows.
    private var otherPrograms: [Program] {
        ProgramDatabase.shared.programs.filter { $0.id != activeProgram?.id }
    }

    @ViewBuilder
    private func switchSheet(planId: UUID?) -> some View {
        if let planId, let plan = ProgramDatabase.shared.programs.first(where: { $0.id == planId }) {
            switchLevel2(plan)
        } else {
            switchLevel1
        }
    }

    private var switchLevel1: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber().frame(maxWidth: .infinity)
                sheetHeader("Switch Workout", sub: "For today only · your program stays unchanged")

                // Active program workouts
                AuraSectionLabel(title: (activeProgram?.name ?? "Program") + " (Active)")
                    .padding(.horizontal, AuraSpacing.screenPad)
                VStack(spacing: 10) {
                    ForEach(programWorkouts) { w in
                        workoutRow(w) { assign(w.id, mode: .switchMode, dateIso: info.iso) }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)

                // Other plans → drill into level 2
                if !otherPrograms.isEmpty {
                    AuraSectionLabel(title: "Other Plans")
                        .padding(.horizontal, AuraSpacing.screenPad)
                    VStack(spacing: 0) {
                        ForEach(Array(otherPrograms.enumerated()), id: \.element.id) { idx, prog in
                            Button { parentSheet = .switchWorkout(planId: prog.id) } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: AuraRadius.md).fill(Color.aura.surface2).frame(width: 40, height: 40)
                                        Image(systemName: "square.stack.3d.up.fill").foregroundColor(.aura.text3).font(AuraFont.jakarta(16))
                                    }
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(prog.name).font(AuraFont.jakarta(15, .bold)).foregroundColor(.aura.text)
                                        Text("\(prog.workouts.count) workouts · \(prog.style)").font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(AuraFont.jakarta(14)).foregroundColor(.aura.text3)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)
                            if idx < otherPrograms.count - 1 { Divider().padding(.leading, 68) }
                        }
                    }
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
                    .padding(.horizontal, AuraSpacing.screenPad)
                }

                // Workout Library (stub)
                srcCard(icon: "magnifyingglass", bg: .aura.green.opacity(0.16), color: .aura.green,
                        title: "Workout Library", sub: "Browse all saved & predefined workouts") {
                    flash("Opening workout library…")
                }
                .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
    }

    private func switchLevel2(_ plan: Program) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber().frame(maxWidth: .infinity)
                // Back header
                HStack(spacing: 10) {
                    Button { parentSheet = .switchWorkout() } label: {
                        Image(systemName: "chevron.left").font(AuraFont.jakarta(16, .semibold))
                            .foregroundColor(.aura.text)
                            .frame(width: 34, height: 34)
                            .background(Color.aura.fill.opacity(0.5)).clipShape(Circle())
                    }.buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.name).font(AuraFont.navTitle()).foregroundColor(.aura.text)
                        Text("Pick a workout to use today").font(AuraFont.jakarta(12)).foregroundColor(.aura.text2)
                    }
                    Spacer()
                }
                .padding(.horizontal, AuraSpacing.screenPad)

                VStack(spacing: 10) {
                    ForEach(plan.workouts) { w in
                        workoutRow(w) { assign(w.id, mode: .switchMode, dateIso: info.iso) }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
    }

    // MARK: Move sheet

    private var moveSheet: some View {
        let weekStart: Date = {
            let wd = cal.component(.weekday, from: selected) - 1
            let offset = appState.calendarStartDay == 1 ? ((wd + 6) % 7) : wd
            return cal.date(byAdding: .day, value: -offset, to: selected)!
        }()
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        return ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber().frame(maxWidth: .infinity)
                sheetHeader("Move to Another Day", sub: "Today only · your program stays unchanged")
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.offset) { idx, d in
                        let di = appState.dayInfo(for: d)
                        let isSel = cal.isDate(d, inSameDayAs: selected)
                        Button {
                            appState.setOverride(DayOverride(kind: .removed), for: info.iso)
                            appState.setOverride(DayOverride(kind: .added, workoutId: info.workout?.id), for: di.iso)
                            parentSheet = nil
                            flash("Moved to \(dowFull[di.dowIndex])")
                        } label: {
                            HStack(spacing: 12) {
                                VStack(spacing: 0) {
                                    Text(dowShort[di.dowIndex]).font(AuraFont.jakarta(9, .heavy)).foregroundColor(.aura.text3)
                                    Text("\(cal.component(.day, from: d))").font(AuraFont.jakarta(13, .bold)).foregroundColor(.aura.text)
                                }
                                .frame(width: 38, height: 38)
                                .background(Color.aura.fill).clipShape(RoundedRectangle(cornerRadius: 11))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(dowFull[di.dowIndex] + (isSel ? " (today)" : ""))
                                        .font(AuraFont.jakarta(16, .medium)).foregroundColor(.aura.text)
                                    Text(di.workout?.name ?? "Rest day").font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)
                                }
                                Spacer()
                                if !isSel { Image(systemName: "chevron.right").font(AuraFont.jakarta(14)).foregroundColor(.aura.text3) }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                            .opacity(isSel ? 0.45 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSel)
                        if idx < days.count - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
    }

    // MARK: Edit sheet (today-only set counts)

    @State private var editExercises: [Exercise] = []

    private var editSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber().frame(maxWidth: .infinity)
                sheetHeader("Edit Workout", sub: "Changes apply to today only")
                VStack(spacing: 9) {
                    ForEach(Array(editExercises.enumerated()), id: \.element.id) { i, e in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.name).font(AuraFont.jakarta(14.5, .bold)).foregroundColor(.aura.text)
                                Text("\(e.repRange) reps").font(AuraFont.jakarta(12)).foregroundColor(.aura.text2)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                stepBtn("minus") { if editExercises[i].plannedSets > 1 { editExercises[i].plannedSets -= 1 } }
                                Text("\(e.plannedSets)").font(AuraFont.jakarta(15, .heavy)).foregroundColor(.aura.text)
                                    .frame(minWidth: 20)
                                stepBtn("plus", accent: true) { editExercises[i].plannedSets += 1 }
                                stepBtn("trash", danger: true) { editExercises.remove(at: i) }
                            }
                        }
                        .padding(.horizontal, 13).padding(.vertical, 11)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
                        .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)

                AuraPrimaryButton(label: "Save for Today") {
                    // Reuse the day's existing override type when present (editing a
                    // logged day stays logged; a fresh planned day becomes `edited`),
                    // per 03-log §sh-edit edge. Don't collapse to one type.
                    let existing = appState.dayOverrides[info.iso]?.kind
                    let kind: DayOverride.Kind = (existing == .logged || existing == .added) ? existing! : .edited
                    appState.setOverride(DayOverride(kind: kind, workoutId: info.workout?.id, editedExercises: editExercises), for: info.iso)
                    parentSheet = nil; flash("Workout updated for today")
                }
                .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
        .onAppear { editExercises = info.workout?.exercises ?? [] }
    }

    private func stepBtn(_ icon: String, accent: Bool = false, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(AuraFont.jakarta(14, .semibold))
                .foregroundColor(danger ? .aura.red : (accent ? .aura.accent : .aura.text))
                .frame(width: 30, height: 30)
                .background(accent ? Color.aura.accentSoft : Color.aura.fill.opacity(danger ? 0 : 0.5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Add sheet

    private var addSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber().frame(maxWidth: .infinity)
                sheetHeader("Add a Workout")
                Text("Where should this workout come from?")
                    .font(AuraFont.jakarta(12)).foregroundColor(.aura.text2)
                    .padding(.horizontal, AuraSpacing.screenPad)
                VStack(spacing: 12) {
                    srcCard(icon: "sparkles", bg: .aura.accentSoft, color: .aura.accent,
                            title: "From your programs", sub: "Your active PPL plan & saved programs") {
                        parentSheet = .pick(mode: .add, date: info.iso)
                    }
                    srcCard(icon: "magnifyingglass", bg: .aura.green.opacity(0.16), color: .aura.green,
                            title: "From Workout Library", sub: "Pick exercises from scratch") {
                        parentSheet = .buildFromLibrary(mode: .add, date: info.iso)
                    }
                    srcCard(icon: "plus", bg: .aura.fill, color: .aura.text2,
                            title: "Empty Workout", sub: "Start blank, add as you go") {
                        parentSheet = nil
                        appState.startWorkout(SeedData.emptyWorkout(), emptyMode: true)
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
    }

    // MARK: Log-past sheet

    private func logPastSheet(date: String, showToday: Bool) -> some View {
        let yesterday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let twoAgo = cal.date(byAdding: .day, value: -2, to: cal.startOfDay(for: Date()))!
        return ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber().frame(maxWidth: .infinity)
                sheetHeader("Log a Past Workout")
                Text("WHEN DID YOU TRAIN?")
                    .font(AuraFont.jakarta(11, .bold)).foregroundColor(.aura.text2)
                    .tracking(1).padding(.horizontal, AuraSpacing.screenPad)

                VStack(spacing: 0) {
                    if showToday {
                        Button { parentSheet = .logQuick(iso: info.iso) } label: {
                            dateRow(title: "Log Today's Workout", sub: "Set time · enter your sets",
                                    accent: true, selected: false)
                        }.buttonStyle(.plain)
                        Divider().padding(.leading, 16)
                    }
                    dateOptionRow("Yesterday", date: yesterday, current: date)
                    Divider().padding(.leading, 16)
                    dateOptionRow("2 days ago", date: twoAgo, current: date)
                    Divider().padding(.leading, 16)
                    Button { parentSheet = .calendar(forLogPast: true) } label: {
                        dateRow(title: "Pick a date", sub: nil, accent: false, selected: false, chevron: true)
                    }.buttonStyle(.plain)
                }
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, AuraSpacing.screenPad)

                Text("WHICH WORKOUT?")
                    .font(AuraFont.jakarta(11, .bold)).foregroundColor(.aura.text2)
                    .tracking(1).padding(.horizontal, AuraSpacing.screenPad).padding(.top, AuraSpacing.s2)
                VStack(spacing: 10) {
                    srcCard(icon: "sparkles", bg: .aura.accentSoft, color: .aura.accent,
                            title: "From a Program", sub: "Your active PPL plan & saved programs") {
                        parentSheet = .pick(mode: .logpast, date: date)
                    }
                    srcCard(icon: "dumbbell.fill", bg: .aura.blue.opacity(0.16), color: .aura.blue,
                            title: "A Saved Workout", sub: "Custom & predefined workouts") {
                        parentSheet = .pick(mode: .logpast, date: date)
                    }
                    srcCard(icon: "magnifyingglass", bg: .aura.green.opacity(0.16), color: .aura.green,
                            title: "Build from Library", sub: "Pick exercises from scratch") {
                        parentSheet = .buildFromLibrary(mode: .logpast, date: date)
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
    }

    private func dateOptionRow(_ label: String, date: Date, current: String) -> some View {
        let iso = AppState.iso(date)
        let on = current == iso
        return Button { parentSheet = .logPast(date: iso, showToday: false) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(AuraFont.jakarta(16, .medium)).foregroundColor(.aura.text)
                    Text("\(dowFull[cal.component(.weekday, from: date) - 1].prefix(3)), \(monShort[cal.component(.month, from: date) - 1]) \(cal.component(.day, from: date))")
                        .font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)
                }
                Spacer()
                ZStack {
                    Circle().fill(on ? Color.aura.accent : Color.clear).frame(width: 20, height: 20)
                    Circle().stroke(on ? Color.clear : Color.aura.separator, lineWidth: 1.5).frame(width: 20, height: 20)
                    if on { Image(systemName: "checkmark").font(AuraFont.jakarta(11, .bold)).foregroundColor(.white) }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }.buttonStyle(.plain)
    }

    private func dateRow(title: String, sub: String?, accent: Bool, selected: Bool, chevron: Bool = false) -> some View {
        HStack(spacing: 12) {
            if accent {
                ZStack {
                    RoundedRectangle(cornerRadius: AuraRadius.xs).fill(Color.aura.accentSoft).frame(width: 30, height: 30)
                    Image(systemName: "bolt.fill").foregroundColor(.aura.accent).font(AuraFont.jakarta(15))
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(AuraFont.jakarta(16, accent ? .bold : .medium)).foregroundColor(accent ? .aura.accent : .aura.text)
                if let sub { Text(sub).font(AuraFont.jakarta(13)).foregroundColor(.aura.text2) }
            }
            Spacer()
            if accent || chevron {
                Image(systemName: "chevron.right").font(AuraFont.jakarta(14)).foregroundColor(accent ? .aura.accent : .aura.text3)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(accent ? Color.aura.accent.opacity(0.06) : Color.clear)
    }

    // MARK: Build-from-library sheet (§2.9 from-scratch workout)

    private var libFiltered: [ExerciseEntry] {
        exerciseDB.filtered(category: libCategory == "All" ? nil : libCategory, equipment: nil, query: libQuery)
    }
    private let libCategories = ["All","Chest","Back","Shoulders","Arms","Legs","Core","Cardio","Warm-up"]

    private func buildFromLibrarySheet(mode: LogSheet.PickMode, date: String) -> some View {
        VStack(spacing: 0) {
            grabber().frame(maxWidth: .infinity).padding(.top, AuraSpacing.s2)
            sheetHeader("Build a Workout", sub: "Select exercises, then confirm")
                .padding(.horizontal, AuraSpacing.screenPad)

            HStack(spacing: AuraSpacing.s2) {
                Image(systemName: "magnifyingglass").foregroundColor(.aura.text3)
                TextField("Search exercises", text: $libQuery).font(AuraFont.body())
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(libCategories, id: \.self) { c in
                        AuraChip(label: c, active: libCategory == c) { libCategory = c }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.vertical, AuraSpacing.s2)
            }

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(libFiltered) { entry in
                        libExerciseRow(entry)
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.bottom, AuraSpacing.s6)
            }

            AuraPrimaryButton(label: libSelected.isEmpty ? "Select exercises" : "Add \(libSelected.count) Exercise\(libSelected.count == 1 ? "" : "s")") {
                confirmBuildFromLibrary(mode: mode, date: date)
            }
            .disabled(libSelected.isEmpty)
            .opacity(libSelected.isEmpty ? 0.5 : 1)
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.vertical, AuraSpacing.s3)
        }
        .background(Color.aura.bg)
        .onAppear { libSelected = []; libQuery = ""; libCategory = "All" }
    }

    private func libExerciseRow(_ entry: ExerciseEntry) -> some View {
        let isOn = libSelected.contains(entry.id)
        return Button {
            if isOn { libSelected.removeAll { $0 == entry.id } } else { libSelected.append(entry.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(AuraFont.jakarta(20))
                    .foregroundColor(isOn ? .aura.accent : .aura.text3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).font(AuraFont.jakarta(15, .bold)).foregroundColor(.aura.text)
                    Text("\(entry.category) · \(entry.equipment)").font(AuraFont.jakarta(12)).foregroundColor(.aura.text2)
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .background(isOn ? Color.aura.accentSoft : Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Assembles the picked `ExerciseEntry` rows into an ad-hoc `Workout` and
    /// applies it the same way `assign(_:mode:dateIso:)` does for a program
    /// workout — via a `DayOverride` with `editedExercises` set, since this
    /// workout has no `Program`/`UserPlan` entry for `workoutId` to resolve to
    /// (`dayInfo`'s placeholder-synthesis fallback picks it up from there).
    private func confirmBuildFromLibrary(mode: LogSheet.PickMode, date: String) {
        let picked = libSelected.compactMap { id in exerciseDB.entries.first { $0.id == id } }
        guard !picked.isEmpty else { return }
        let exercises: [Exercise] = picked.map { entry in
            Exercise(name: entry.name, primaryMuscle: entry.category, muscleGroups: entry.musclesTargeted,
                     equipment: entry.equipment, difficulty: entry.difficulty, isCable: entry.isCable,
                     pulley: entry.pulley, repRange: entry.repRange, plannedSets: entry.plannedSets,
                     hint: entry.hint, imageURL: entry.imageURL.isEmpty ? nil : entry.imageURL,
                     youtubeURL: entry.youtubeURL.isEmpty ? nil : entry.youtubeURL)
        }
        let wid = UUID()
        let kind: DayOverride.Kind
        switch mode {
        case .logpast: kind = .logged
        default:
            let di = appState.dayInfo(for: dateFromIso(date))
            kind = di.relation == .past ? .logged : .added
        }
        appState.setOverride(DayOverride(kind: kind, workoutId: wid, editedExercises: exercises), for: date)
        if kind == .logged {
            let quickExs = exercises.map { QuickLogExercise(name: $0.name, sets: []) }
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            appState.quickLogs[date] = QuickLog(time: f.string(from: Date()), exercises: quickExs)
        }
        selected = dateFromIso(date)
        parentSheet = nil
        flash(mode == .logpast ? "Past workout logged" : "Workout added")
    }

    // MARK: Pick sheet

    private func pickSheet(mode: LogSheet.PickMode, date: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber().frame(maxWidth: .infinity)
                sheetHeader("Pick a Workout", sub: pickSub(mode: mode, date: date))
                VStack(spacing: 10) {
                    ForEach(programWorkouts) { w in
                        workoutRow(w) { assign(w.id, mode: mode, dateIso: date) }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
    }

    private func pickSub(mode: LogSheet.PickMode, date: String) -> String {
        if mode == .logpast {
            let d = dateFromIso(date)
            return "Logging to \(dowFull[cal.component(.weekday, from: d) - 1].prefix(3)), \(monShort[cal.component(.month, from: d) - 1]) \(cal.component(.day, from: d))"
        }
        return "Added to \(isToday ? "today" : dowFull[cal.component(.weekday, from: selected) - 1])"
    }

    // MARK: Calendar sheet

    @State private var calMonth = Date()

    private func calendarSheet(forLogPast: Bool) -> some View {
        let comps = cal.dateComponents([.year, .month], from: calMonth)
        let first = cal.date(from: comps)!
        let startPad = cal.component(.weekday, from: first) - 1
        let dim = cal.range(of: .day, in: .month, for: first)!.count
        var cells: [Date?] = Array(repeating: nil, count: startPad)
        for d in 1...dim { cells.append(cal.date(byAdding: .day, value: d - 1, to: first)) }
        let today = cal.startOfDay(for: Date())
        let canNext = (cal.component(.year, from: calMonth) < cal.component(.year, from: today)) ||
            (cal.component(.year, from: calMonth) == cal.component(.year, from: today) &&
             cal.component(.month, from: calMonth) < cal.component(.month, from: today))

        return ScrollView {
            VStack(spacing: AuraSpacing.s3) {
                grabber()
                HStack {
                    Text("\(monFull[cal.component(.month, from: calMonth) - 1]) \(cal.component(.year, from: calMonth))")
                        .font(AuraFont.navTitle()).foregroundColor(.aura.text)
                    Spacer()
                    HStack(spacing: 6) {
                        calNavBtn("chevron.left", enabled: true) {
                            calMonth = cal.date(byAdding: .month, value: -1, to: calMonth)!
                        }
                        calNavBtn("chevron.right", enabled: canNext) {
                            if canNext { calMonth = cal.date(byAdding: .month, value: 1, to: calMonth)! }
                        }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)

                HStack(spacing: 0) {
                    ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { _, d in
                        Text(d).font(AuraFont.jakarta(12, .bold)).foregroundColor(.aura.text3).frame(maxWidth: .infinity)
                    }
                }.padding(.horizontal, AuraSpacing.screenPad)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, d in
                        calCell(d, today: today, forLogPast: forLogPast)
                    }
                }.padding(.horizontal, AuraSpacing.screenPad)

                HStack(spacing: 16) {
                    legend(.aura.green, "Completed")
                    legend(.aura.accent, "Planned")
                    legend(.aura.text3, "Rest")
                }.font(AuraFont.jakarta(12)).padding(.top, AuraSpacing.s2)

                if !forLogPast {
                    AuraPrimaryButton(label: "Go to Today") {
                        selected = today; parentSheet = nil
                    }.padding(.horizontal, AuraSpacing.screenPad)
                }
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
        .onAppear { calMonth = cal.date(from: cal.dateComponents([.year, .month], from: selected))! }
    }

    @ViewBuilder
    private func calCell(_ d: Date?, today: Date, forLogPast: Bool) -> some View {
        if let d {
            let di = appState.dayInfo(for: d)
            let isToday = cal.isDate(d, inSameDayAs: today)
            let sel = cal.isDate(d, inSameDayAs: selected)
            let isFuture = d > today
            Button {
                if isFuture { return }
                if forLogPast { parentSheet = .logPast(date: di.iso, showToday: false) }
                else { selected = d; parentSheet = nil }
            } label: {
                VStack(spacing: 2) {
                    Text("\(cal.component(.day, from: d))")
                        .font(AuraFont.jakarta(15, .semibold))
                        .foregroundColor(isToday ? .white : .aura.text)
                    Circle().fill(calDot(di.state)).frame(width: 5, height: 5)
                        .opacity(isFuture ? 0 : 1)
                }
                .frame(maxWidth: .infinity).frame(height: 40)
                .background(isToday ? Color.aura.accent : Color.clear)
                .clipShape(Circle())
                .overlay(sel && !isToday ? Circle().stroke(Color.aura.accent, lineWidth: 2) : nil)
                .opacity(isFuture && !isToday ? 0.28 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isFuture)
        } else {
            Color.clear.frame(height: 40)
        }
    }

    private func calDot(_ state: DayState) -> Color {
        switch state {
        case .done: return .aura.green
        case .today, .future: return .aura.accent
        case .rest, .restToday: return .aura.text3
        case .missed: return .aura.red.opacity(0.75)
        default: return .clear
        }
    }

    private func calNavBtn(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(AuraFont.jakarta(16)).foregroundColor(.aura.text)
                .frame(width: 34, height: 34).background(Color.aura.fill.opacity(0.5)).clipShape(Circle())
                .opacity(enabled ? 1 : 0.28)
        }.buttonStyle(.plain).disabled(!enabled)
    }

    private func legend(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).foregroundColor(.aura.text2)
        }
    }

    // MARK: View-log sheet

    private var viewLogSheet: some View {
        let log = appState.quickLogs[info.iso]
        let exs: [QuickLogExercise] = log?.exercises ?? (info.workout?.exercises ?? []).map {
            QuickLogExercise(name: $0.name, sets: (0..<$0.plannedSets).map { _ in QuickLogSet(weight: "—", reps: "") })
        }
        return ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber().frame(maxWidth: .infinity)
                sheetHeader("Workout Log", sub: (info.workout?.name ?? "")
                    + (log != nil ? "  ·  \(log!.time)" : "")
                    + (log.map { $0.durationMinutes > 0 ? "  ·  \($0.durationMinutes) min" : "" } ?? ""))
                VStack(spacing: 12) {
                    ForEach(exs) { ex in
                        logExerciseCard(ex, editable: false)
                    }
                }.padding(.horizontal, AuraSpacing.screenPad)
                AuraGrayButton(label: "Edit Log", icon: "pencil") {
                    withAnimation(.easeInOut(duration: 0.28)) { parentSheet = .editLog }
                }
                    .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
    }

    private func logExerciseCard(_ ex: QuickLogExercise, editable: Bool) -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(ex.name).font(AuraFont.jakarta(14.5, .bold)).foregroundColor(.aura.text)
                    .padding(.bottom, 10)
                HStack {
                    Text("SET").frame(width: 28, alignment: .leading)
                    Text("WEIGHT").frame(maxWidth: .infinity, alignment: .leading)
                    Text("REPS").frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(AuraFont.jakarta(11, .bold)).foregroundColor(.aura.text3).tracking(0.5)
                ForEach(Array(ex.sets.enumerated()), id: \.element.id) { j, s in
                    HStack {
                        Text("\(j + 1)").font(AuraFont.jakarta(13, .bold)).foregroundColor(.aura.text3).frame(width: 28, alignment: .leading)
                        Text(s.weight.isEmpty ? "—" : s.weight).frame(maxWidth: .infinity, alignment: .leading)
                        Text(s.reps.isEmpty ? "—" : s.reps).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(AuraFont.jakarta(15, .semibold)).foregroundColor(.aura.text)
                    .padding(.vertical, 7)
                    .overlay(Divider(), alignment: .top)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    // MARK: View-workout sheet (read-only future-day preview, §2.11)

    private func viewWorkoutSheet(iso: String) -> some View {
        let workout = info.workout
        return ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber().frame(maxWidth: .infinity)
                sheetHeader(workout?.name ?? "Workout", sub: "Planned · read-only")
                VStack(spacing: 12) {
                    ForEach(workout?.exercises ?? []) { ex in
                        plannedExerciseCard(ex)
                    }
                }.padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
    }

    private func plannedExerciseCard(_ ex: Exercise) -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(ex.name).font(AuraFont.jakarta(14.5, .bold)).foregroundColor(.aura.text)
                Text("\(ex.plannedSets) sets")
                    .font(AuraFont.jakarta(13, .semibold))
                    .foregroundColor(.aura.text3)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Edit-log + Log-quick (editable forms)

    @State private var formExercises: [QuickLogExercise] = []
    @State private var formTime: String = ""
    @State private var formDurationMinutes: Int = 0

    private var editLogSheet: some View {
        quickLogForm(title: "Edit Log", sub: info.workout?.name ?? "", showTime: false, iso: info.iso, saveLabel: "Save Log")
    }

    private func logQuickSheet(iso: String) -> some View {
        quickLogForm(title: "Log Workout", sub: info.workout?.name ?? "", showTime: true, iso: iso, saveLabel: "Save Workout")
    }

    private func quickLogForm(title: String, sub: String, showTime: Bool, iso: String, saveLabel: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                grabber().frame(maxWidth: .infinity)
                sheetHeader(title, sub: sub)
                if showTime {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(Color.aura.accentSoft).frame(width: 36, height: 36)
                            Image(systemName: "clock").foregroundColor(.aura.accent).font(AuraFont.jakarta(18))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WORKOUT TIME").font(AuraFont.jakarta(11, .bold)).foregroundColor(.aura.text3).tracking(0.5)
                            Text("When did you train?").font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)
                        }
                        Spacer()
                        TextField("HH:mm", text: $formTime)
                            .multilineTextAlignment(.center).frame(width: 70)
                            .font(AuraFont.jakarta(16, .bold)).foregroundColor(.aura.text)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.aura.fill.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(13).background(Color.aura.surface).clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
                    .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
                    .padding(.horizontal, AuraSpacing.screenPad)
                }
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.aura.accentSoft).frame(width: 36, height: 36)
                        Image(systemName: "stopwatch").foregroundColor(.aura.accent).font(AuraFont.jakarta(18))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DURATION").font(AuraFont.jakarta(11, .bold)).foregroundColor(.aura.text3).tracking(0.5)
                        Text("How long did it take?").font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)
                    }
                    Spacer()
                    TextField("min", value: $formDurationMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center).frame(width: 60)
                        .font(AuraFont.jakarta(16, .bold)).foregroundColor(.aura.text)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.aura.fill.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("min").font(AuraFont.jakarta(13, .semibold)).foregroundColor(.aura.text3)
                }
                .padding(13).background(Color.aura.surface).clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
                .overlay(RoundedRectangle(cornerRadius: AuraRadius.lg).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, AuraSpacing.screenPad)
                VStack(spacing: 14) {
                    ForEach(Array(formExercises.enumerated()), id: \.element.id) { i, ex in
                        editableLogCard(i: i, ex: ex)
                    }
                }.padding(.horizontal, AuraSpacing.screenPad)

                AuraPrimaryButton(label: saveLabel) { saveQuickLog(iso: iso) }
                    .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .background(Color.aura.bg)
        .onAppear { loadForm(iso: iso) }
    }

    private func editableLogCard(i: Int, ex: QuickLogExercise) -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: 0) {
                Text(ex.name).font(AuraFont.jakarta(14.5, .bold)).foregroundColor(.aura.text).padding(.bottom, 10)
                HStack {
                    Text("SET").frame(width: 28, alignment: .leading)
                    Text("WEIGHT").frame(maxWidth: .infinity)
                    Text("REPS").frame(maxWidth: .infinity)
                    Spacer().frame(width: 28)
                }.font(AuraFont.jakarta(11, .bold)).foregroundColor(.aura.text3).tracking(0.5)
                ForEach(Array(ex.sets.enumerated()), id: \.element.id) { j, _ in
                    HStack(spacing: 8) {
                        Text("\(j + 1)").font(AuraFont.jakarta(12, .bold)).foregroundColor(.aura.text3).frame(width: 28, alignment: .leading)
                        TextField(appState.weightUnit, text: bindingWeight(i, j)).logFieldStyle()
                        TextField("reps", text: bindingReps(i, j)).logFieldStyle()
                        Button { formExercises[i].sets.remove(at: j) } label: {
                            Image(systemName: "minus.circle.fill").foregroundColor(.aura.red).font(AuraFont.jakarta(15))
                        }.buttonStyle(.plain).frame(width: 28)
                    }
                    .padding(.vertical, 5).overlay(Divider(), alignment: .top)
                }
                Button { formExercises[i].sets.append(QuickLogSet()) } label: {
                    HStack(spacing: 5) { Image(systemName: "plus"); Text("Add Set") }
                        .font(AuraFont.jakarta(13, .bold)).foregroundColor(.aura.accent)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Color.aura.accentSoft).clipShape(RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain).padding(.top, 10)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
    }

    private func bindingWeight(_ i: Int, _ j: Int) -> Binding<String> {
        Binding(get: { formExercises[i].sets[j].weight }, set: { formExercises[i].sets[j].weight = $0 })
    }
    private func bindingReps(_ i: Int, _ j: Int) -> Binding<String> {
        Binding(get: { formExercises[i].sets[j].reps }, set: { formExercises[i].sets[j].reps = $0 })
    }

    private func loadForm(iso: String) {
        if let log = appState.quickLogs[iso] {
            formExercises = log.exercises
            formTime = log.time
            formDurationMinutes = log.durationMinutes
        } else {
            formExercises = (info.workout?.exercises ?? []).map {
                QuickLogExercise(name: $0.name, sets: (0..<$0.plannedSets).map { _ in QuickLogSet() })
            }
            let f = DateFormatter(); f.dateFormat = "HH:mm"
            formTime = f.string(from: Date())
            formDurationMinutes = 0
        }
    }

    private func saveQuickLog(iso: String) {
        appState.quickLogs[iso] = QuickLog(time: formTime.isEmpty ? "—" : formTime, exercises: formExercises, durationMinutes: formDurationMinutes)
        let wid = appState.dayOverrides[iso]?.workoutId ?? info.workout?.id
        appState.setOverride(DayOverride(kind: .logged, workoutId: wid), for: iso)
        parentSheet = nil
        flash("Workout logged!")
    }
}

// MARK: - Field style helper

private extension View {
    func logFieldStyle() -> some View {
        self.multilineTextAlignment(.center)
            .font(AuraFont.jakarta(15, .bold))
            .foregroundColor(.aura.text)
            .keyboardType(.numbersAndPunctuation)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.aura.fill.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity)
    }
}
