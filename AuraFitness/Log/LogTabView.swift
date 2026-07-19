import SwiftUI

// MARK: - Sheet routing for the Log tab (mirrors combined/log.jsx `sheet`)

enum LogSheet: Identifiable {
    case menu
    /// Switch today's workout. `planId == nil` = level 1 (active program + other
    /// plans + library); non-nil = level 2 (drilled into that program's workouts).
    case switchWorkout(planId: UUID? = nil)
    case move
    case edit
    case add
    case logPast(date: String, showToday: Bool)
    case pick(mode: PickMode, date: String)
    /// Multi-select exercise picker over the full Exercise Library, assembles
    /// a from-scratch workout (§2.9 "Build from Library" / "From Workout Library").
    case buildFromLibrary(mode: PickMode, date: String)
    case calendar(forLogPast: Bool)
    case viewLog
    case editLog
    case logQuick(iso: String)
    /// Read-only preview of a future planned workout's exercise list (§2.11).
    case viewWorkout(iso: String)

    enum PickMode { case add, logpast, switchMode }

    var id: String {
        switch self {
        case .menu: return "menu"
        case .switchWorkout(let planId): return "switch-\(planId?.uuidString ?? "root")"
        case .move: return "move"
        case .edit: return "edit"
        case .add: return "add"
        case .logPast: return "logpast"
        case .pick: return "pick"
        case .calendar: return "cal"
        case .viewLog: return "viewlog"
        case .editLog: return "editlog"
        case .logQuick: return "logquick"
        case .viewWorkout(let iso): return "viewworkout-\(iso)"
        case .buildFromLibrary(let mode, let date): return "buildlib-\(mode)-\(date)"
        }
    }
}

struct LogTabView: View {
    @EnvironmentObject var appState: AppState

    @State private var selected: Date = Calendar.current.startOfDay(for: Date())
    @State private var sheet: LogSheet?
    @State private var toast: String?

    private let cal = Calendar.current
    private let dowShort = ["S", "M", "T", "W", "T", "F", "S"]
    private let dowFull = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private let monShort = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

    // MARK: Derived

    private var today: Date { cal.startOfDay(for: Date()) }
    private var info: AppState.DayInfo { appState.dayInfo(for: selected) }
    private var isToday: Bool { cal.isDate(selected, inSameDayAs: today) }

    private var calStartMon: Bool { appState.calendarStartDay == 1 }

    private var weekStart: Date {
        let wd = cal.component(.weekday, from: selected) - 1   // 0=Sun
        let offset = calStartMon ? ((wd + 6) % 7) : wd
        return cal.date(byAdding: .day, value: -offset, to: selected)!
    }
    private var weekDays: [Date] {
        (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
    }
    private var todayWeekStart: Date {
        let wd = cal.component(.weekday, from: today) - 1
        let offset = calStartMon ? ((wd + 6) % 7) : wd
        return cal.date(byAdding: .day, value: -offset, to: today)!
    }
    private var isCurrentWeek: Bool { cal.isDate(weekStart, inSameDayAs: todayWeekStart) }

    private var rangeLabel: String {
        let end = cal.date(byAdding: .day, value: 6, to: weekStart)!
        let sM = cal.component(.month, from: weekStart) - 1
        let eM = cal.component(.month, from: end) - 1
        let sD = cal.component(.day, from: weekStart)
        let eD = cal.component(.day, from: end)
        let endPart = sM == eM ? "\(eD)" : "\(monShort[eM]) \(eD)"
        return "\(monShort[sM]) \(sD) – \(endPart)"
    }

    private var navTitle: String { isToday ? "Today" : dowFull[cal.component(.weekday, from: selected) - 1] }
    private var navSub: String {
        let dow = dowFull[cal.component(.weekday, from: selected) - 1].uppercased()
        let mon = monShort[cal.component(.month, from: selected) - 1].uppercased()
        return "\(dow), \(mon) \(cal.component(.day, from: selected))"
    }

    //MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                navbar
                weekBar
                AuraScreenScroll {
                    dayBody
                        .padding(.horizontal, AuraSpacing.screenPad)
                        .padding(.top, AuraSpacing.s2)
                }
            }
            .background(Color.aura.bg)

            // Resume banner (shell · resume): accent pill above the flat tab bar,
            // sides 14 per combined/log.jsx. The bar is now in-flow (a bottom row
            // in ContentView), so the banner sits just above the content edge.
            if appState.workoutInProgress {
                ResumeBanner {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        appState.resumeWorkout()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let toast {
                toastView(toast)
            }
        }
        .sheet(item: $sheet) { logSheet($0) }
        // FAB "Start Workout" deep link → open the add-workout source sheet.
        .onChange(of: appState.requestLogAddSheet) { _, want in
            if want { sheet = .add; appState.requestLogAddSheet = false }
        }
        .onAppear {
            if appState.requestLogAddSheet { sheet = .add; appState.requestLogAddSheet = false }
        }
    }

    // MARK: Navbar

    private var navbar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(navSub)
                    .font(AuraFont.jakarta(12, .bold))
                    .foregroundColor(.aura.text2)
                Text(navTitle)
                    .font(AuraFont.largeTitleStyle())
                    .foregroundColor(.aura.text)
            }
            Spacer()
            Button { sheet = .calendar(forLogPast: false) } label: {
                // Design nav button uses the custom `calendar-day` glyph (calendar
                // outline + filled inner day square), drawn as a Path to match
                // icons.js exactly rather than SF Symbols.
                CalendarDayIcon(color: .aura.text)
                    .frame(width: 19, height: 19)
                    .frame(width: 34, height: 34)
                    .background(Color.aura.fill.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.top, AuraSpacing.s1)
        .padding(.bottom, AuraSpacing.s2)
    }

    // MARK: Week bar

    private var weekBar: some View {
        VStack(spacing: 8) {
            // aura.css `.between`: range label on the left, one contextual text
            // button on the right (‹ This week / ‹ Prev week / Today ›). No
            // circular arrows — week nav is a horizontal swipe on the strip.
            HStack {
                Text(rangeLabel)
                    .font(AuraFont.jakarta(14, .bold))
                    .foregroundColor(.aura.text)
                Spacer()
                if !(isCurrentWeek && isToday) {
                    Button { selected = today } label: {
                        Text(weekButtonLabel)
                            .font(AuraFont.jakarta(12, .bold))
                            .foregroundColor(.aura.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 6)

            HStack(spacing: 6) {
                ForEach(weekDays, id: \.self) { d in
                    dayCell(d)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 12)
        // Swipe the strip left/right to page weeks (replaces the circular arrows).
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { v in
                    if v.translation.width < -24 { if !isCurrentWeek { shiftWeek(7) } }
                    else if v.translation.width > 24 { shiftWeek(-7) }
                }
        )
    }

    /// Right-hand contextual button label, matching the design's four variants.
    private var weekButtonLabel: String {
        if weekStart < todayWeekStart { return "‹ Prev week" }   // viewing a past week
        if weekStart > todayWeekStart { return "‹ This week" }   // viewing a future week
        return "Today ›"                                          // current week, off today
    }

    @ViewBuilder
    private func dayCell(_ d: Date) -> some View {
        let di = appState.dayInfo(for: d)
        let sel = cal.isDate(d, inSameDayAs: selected)
        let dowIdx = cal.component(.weekday, from: d) - 1
        let dayNum = cal.component(.day, from: d)

        Button { selected = d } label: {
            VStack(spacing: 3) {
                Text(dowShort[dowIdx])
                    .font(AuraFont.jakarta(11, .bold))
                    .foregroundColor(sel ? .white : .aura.text3)
                Text("\(dayNum)")
                    .font(AuraFont.jakarta(16, .bold))
                    .foregroundColor(sel ? .white : .aura.text)
                Circle()
                    .fill(dotColor(di.state, selected: sel))
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(sel ? Color.aura.accent : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.md)
                    .strokeBorder(Color.aura.separator.opacity(0.5), lineWidth: 1)
                    .opacity(sel ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dotColor(_ state: DayState, selected: Bool) -> Color {
        if selected {
            switch state {
            case .rest, .restToday, .emptyToday, .restPlanned: return .white.opacity(0.6)
            default: return .white
            }
        }
        switch state {
        case .done: return .aura.green
        case .today, .future: return .aura.accent
        case .missed: return .aura.red.opacity(0.75)
        case .rest, .restToday: return .aura.text3
        default: return .clear
        }
    }

    private func shiftWeek(_ days: Int) {
        if let d = cal.date(byAdding: .day, value: days, to: selected) { selected = d }
    }

    // MARK: Day body (7 states)

    @ViewBuilder
    private var dayBody: some View {
        switch info.state {
        case .rest, .restToday, .emptyToday, .restPlanned:
            restOrEmptyBody
        case .today, .done, .missed, .future:
            cardBody
        }
    }

    // MARK: Rest / empty body

    private var restOrEmptyBody: some View {
        let empty = info.state == .emptyToday
        return VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            VStack(spacing: AuraSpacing.s3) {
                ZStack {
                    Circle()
                        .fill(empty ? Color.aura.accentSoft : Color.aura.fill)
                        .frame(width: 64, height: 64)
                    Image(systemName: empty ? "plus" : "moon.fill")
                        .font(AuraFont.jakarta(28, .medium))
                        .foregroundColor(empty ? .aura.accent : .aura.text2)
                }
                Text(empty ? "Nothing planned" : "Rest Day")
                    .font(AuraFont.jakarta(22, .heavy))
                    .foregroundColor(.aura.text)
                Text(empty
                     ? "No workout scheduled. Start something fresh or log a session you already did."
                     : "Recovery is where the gains happen. Nothing scheduled\(isToday ? " today" : "").")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 250)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 38)
            .padding(.horizontal, AuraSpacing.s6)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.xl)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: empty ? [6] : []))
                    .foregroundColor(.aura.separator.opacity(empty ? 1 : 0.5))
            )

            if info.relation != .future {
                AuraSectionLabel(title: empty ? " " : "Did you train\(isToday ? "" : " that day") anyway?")
                VStack(spacing: AuraSpacing.s2) {
                    AuraTintedButton(label: isToday ? "Add a Workout" : "Log a Workout", icon: "plus") {
                        if isToday { sheet = .add }
                        else { sheet = .pick(mode: .logpast, date: info.iso) }
                    }
                    if isToday {
                        AuraGrayButton(label: "Log a Past Workout", icon: "clock") {
                            sheet = .logPast(date: AppState.iso(cal.date(byAdding: .day, value: -1, to: today)!), showToday: false)
                        }
                    }
                }
            } else {
                infoCard(text: "Scheduled rest day. Enjoy the recovery — your next session is just around the corner.",
                         tint: false)
            }
        }
    }

    // MARK: Card body (today / done / missed / future)

    private var cardBody: some View {
        let workout = info.workout
        return VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            // Badges
            HStack(spacing: AuraSpacing.s2) {
                badge(icon: "sparkles", text: appState.defaultPlan?.name ?? "Program", color: .aura.accent)
                switch info.state {
                case .done:   badge(icon: "checkmark", text: "Completed", color: .aura.green)
                case .missed: badge(icon: "xmark", text: "Missed", color: .aura.red)
                default: EmptyView()
                }
            }
            .padding(.top, AuraSpacing.s1)

            // Workout card
            AuraCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout?.name ?? "")
                                .font(AuraFont.jakarta(22, .heavy))
                                .foregroundColor(.aura.text)
                            Text("\(workout?.exercises.count ?? 0) exercises · \(workout?.primaryMuscles ?? "")")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                        Spacer()
                        cardRightAccessory
                    }
                    Divider().padding(.vertical, 14)
                    exerciseRows(workout?.exercises ?? [],
                                 dim: info.state == .missed || info.state == .future)
                }
                .padding(AuraSpacing.s4)
            }

            // Action buttons per state
            cardActions
        }
    }

    @ViewBuilder
    private var cardRightAccessory: some View {
        switch info.state {
        case .today:
            Button { sheet = .menu } label: {
                Image(systemName: "ellipsis")
                    .font(AuraFont.jakarta(20, .semibold))
                    .foregroundColor(.aura.text)
                    .frame(width: 32, height: 32)
                    .background(Color.aura.fill.opacity(0.5))
                    .clipShape(Circle())
            }
        case .done:
            stateGlyph("checkmark.circle.fill", color: .aura.green)
        case .missed:
            stateGlyph("xmark.circle.fill", color: .aura.red)
        case .future:
            Text("View only")
                .font(AuraFont.jakarta(11, .bold))
                .foregroundColor(.aura.text3)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Color.aura.fill).clipShape(Capsule())
        default: EmptyView()
        }
    }

    private func stateGlyph(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(AuraFont.jakarta(22))
            .foregroundColor(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.13))
            .clipShape(Circle())
    }

    @ViewBuilder
    private var cardActions: some View {
        switch info.state {
        case .today:
            VStack(spacing: AuraSpacing.s2) {
                AuraPrimaryButton(label: "Start Workout", icon: "play.fill") {
                    if let w = info.workout { appState.startWorkout(w) }
                }
                HStack(spacing: AuraSpacing.s3) {
                    AuraGrayButton(label: "Log past", icon: "clock") {
                        sheet = .logPast(date: AppState.iso(cal.date(byAdding: .day, value: -1, to: today)!), showToday: true)
                    }
                    AuraGrayButton(label: "Switch", icon: "arrow.left.arrow.right") {
                        sheet = .switchWorkout()
                    }
                }
            }
        case .done:
            VStack(spacing: AuraSpacing.s2) {
                AuraPrimaryButton(label: "View Log", icon: "doc.text") { sheet = .viewLog }
                AuraGrayButton(label: "Edit Log", icon: "pencil") { sheet = .editLog }
            }
        case .missed:
            VStack(spacing: AuraSpacing.s2) {
                AuraPrimaryButton(label: "Log Workout", icon: "clock") {
                    sheet = .pick(mode: .logpast, date: info.iso)
                }
                AuraGrayButton(label: "Mark as Rest Day", icon: "moon.fill") {
                    appState.setOverride(DayOverride(kind: .rest), for: info.iso)
                    flash("Marked as rest day")
                }
            }
        case .future:
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                AuraGrayButton(label: "View Workout", icon: "doc.text") { sheet = .viewWorkout(iso: info.iso) }
                futureNotice
            }
        default: EmptyView()
        }
    }

    private var futureNotice: some View {
        HStack(alignment: .top, spacing: AuraSpacing.s3) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.aura.accent)
                .font(AuraFont.jakarta(18))
            VStack(alignment: .leading, spacing: 3) {
                Text("Future workouts are read-only")
                    .font(AuraFont.jakarta(14, .bold))
                    .foregroundColor(.aura.text)
                Text("To change this workout, edit your program in the Plans tab.")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
            }
        }
        .padding(AuraSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aura.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.md)
                .stroke(Color.aura.accent.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: Shared pieces

    private func badge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(AuraFont.jakarta(11, .bold))
            Text(text).font(AuraFont.jakarta(12, .bold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(color.opacity(0.13))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func exerciseRows(_ exercises: [Exercise], dim: Bool) -> some View {
        // Show ~3 rows; scroll for the rest (mirrors log.jsx ExRows maxHeight: 168).
        let capHeight: CGFloat = 168
        let scrollable = exercises.count > 3

        ScrollView(.vertical, showsIndicators: scrollable) {
            VStack(spacing: 11) {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { i, e in
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(AuraFont.jakarta(12, .bold))
                            .foregroundColor(.aura.text2)
                            .frame(width: 22, height: 22)
                            .background(Color.aura.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(e.name)
                                .font(AuraFont.jakarta(15, .semibold))
                                .foregroundColor(.aura.text)
                            Text("\(e.plannedSets) sets · \(e.repRange) reps")
                                .font(AuraFont.jakarta(12.5))
                                .foregroundColor(.aura.text2)
                        }
                        Spacer()
                    }
                }
            }
            .padding(.trailing, 2) // matches paddingRight: 2 in ExRows so the scrollbar doesn't overlap text
        }
        .frame(maxHeight: scrollable ? capHeight : nil)
        .scrollBounceBehavior(.basedOnSize)
        .opacity(dim ? 0.55 : 1)
    }

    private func infoCard(text: String, tint: Bool) -> some View {
        HStack(alignment: .top, spacing: AuraSpacing.s3) {
            Image(systemName: "info.circle")
                .foregroundColor(.aura.text2)
                .font(AuraFont.jakarta(18))
            Text(text)
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
        }
        .padding(AuraSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.md)
                .stroke(Color.aura.separator.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: Toast

    private func toastView(_ msg: String) -> some View {
        Text(msg)
            .font(AuraFont.jakarta(13, .semibold))
            .foregroundColor(.aura.bg)
            .padding(.horizontal, 16).padding(.vertical, 9)
            .background(Color.aura.text)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 8)
            .padding(.bottom, AuraSpacing.tabBarClearance + 6)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    func flash(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) {
            withAnimation { if toast == msg { toast = nil } }
        }
    }

    // MARK: Sheet builder

    @ViewBuilder
    private func logSheet(_ s: LogSheet) -> some View {
        LogSheetsView(sheet: s, selected: $selected, parentSheet: $sheet, flash: flash)
            .environmentObject(appState)
            .presentationDragIndicator(.visible)
    }
}

// MARK: - calendar-day glyph (exact port of icons.js 'calendar-day')

/// The design's nav calendar icon: a rounded calendar outline with top ticks and
/// header line, plus a *filled* inner day square — drawn in the 24×24 SVG space
/// from `styles/icons.js` so it matches the prototype rather than an SF Symbol.
///
/// icons.js: rect(3.5,4.5,17,16,r3) · M8 2v4 · M16 2v4 · M3.5 9h17 · rect(7,12,4,4,r1) filled
struct CalendarDayIcon: View {
    var color: Color

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height) / 24.0
            let ox = (geo.size.width - 24 * s) / 2
            let oy = (geo.size.height - 24 * s) / 2
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }

            ZStack {
                // stroked outline
                Path { p in
                    p.addRoundedRect(in: CGRect(x: ox + 3.5 * s, y: oy + 4.5 * s,
                                                width: 17 * s, height: 16 * s),
                                     cornerSize: CGSize(width: 3 * s, height: 3 * s))
                    p.move(to: P(8, 2));  p.addLine(to: P(8, 6))
                    p.move(to: P(16, 2)); p.addLine(to: P(16, 6))
                    p.move(to: P(3.5, 9)); p.addLine(to: P(20.5, 9))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))

                // filled inner day square
                Path { p in
                    p.addRoundedRect(in: CGRect(x: ox + 7 * s, y: oy + 12 * s,
                                                width: 4 * s, height: 4 * s),
                                     cornerSize: CGSize(width: 1 * s, height: 1 * s))
                }
                .fill(color)
            }
        }
    }
}
