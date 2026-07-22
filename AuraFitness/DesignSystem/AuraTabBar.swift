import SwiftUI

// MARK: - Tab model

enum AuraTab: Int, CaseIterable, Identifiable {
    case log, plan, progress, profile
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .log:      return "Log"
        case .plan:     return "Plan"
        case .progress: return "Progress"
        case .profile:  return "Profile"
        }
    }
}

// MARK: - FAB quick action model (mirrors ui.jsx ACTIONS)

enum AuraQuickAction: Identifiable, CaseIterable {
    case startWorkout, logMeasurement, progressPhoto
    var id: String { label }

    var label: String {
        switch self {
        case .startWorkout:   return "Start Workout"
        case .logMeasurement: return "Log Measurements"
        case .progressPhoto:  return "Progress Photo"
        }
    }

    var icon: String {
        switch self {
        case .startWorkout:   return "play.circle.fill"
        case .logMeasurement: return "square.and.pencil"
        case .progressPhoto:  return "medal.fill"
        }
    }

    /// Chip accent per 02-shell-nav "The three actions".
    var color: Color {
        switch self {
        case .startWorkout:   return .aura.accent
        case .logMeasurement: return .aura.blue
        case .progressPhoto:  return .aura.green
        }
    }
}

// MARK: - Scroll-direction preference

/// Posted by `AuraScreenScroll` so the floating bar can collapse on downward
/// scroll and re-expand on upward scroll (design: `aura:scroll`).
extension Notification.Name {
    static let auraScroll = Notification.Name("aura:scroll")
}

// MARK: - Floating glass tab bar + FAB
//
// Ports `combined/ui.jsx` TabBarEl as specified in handoff chapter
// 02-shell-nav: a floating glass pill holding the four tabs with ONE accent
// indicator sliding beneath them, plus a separate circular FAB to its right
// that fans out three quick-action chips.
//
// An earlier pass replaced all of this with a flat in-flow four-icon row, on
// the grounds that `screens/Log.html` draws a plain bar. That prototype screen
// is a static mock of the Log body; chapter 2 is the authority on the shell,
// and it specifies the pill, the sliding indicator, the collapse-on-scroll and
// the FAB. Do not flatten it again.
//
// The design's `.home-indicator` capsule is still deliberately NOT ported: on
// device the system draws the real one in the same place, and drawing our own
// put a second bar under the first. The bottom padding below is where it goes.
struct AuraTabBar: View {
    @Binding var selection: AuraTab
    var collapsed: Bool = false
    let onQuickAction: (AuraQuickAction) -> Void

    @State private var fabOpen = false
    /// Live swipe offset in tab units, −1…1. Lets the indicator preview the
    /// destination under the finger instead of only settling after release.
    @State private var swipeProgress: CGFloat = 0
    @State private var dragging = false

    private var barHeight: CGFloat { collapsed ? 66 : 96 }
    private var pillHeight: CGFloat { collapsed ? 50 : 62 }
    private var fabSize: CGFloat { collapsed ? 34 : 46 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Invisible full-screen catcher: any outside tap closes the menu.
            // Below the chips in z-order so the chips stay tappable.
            if fabOpen {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { closeFab() }
            }

            if fabOpen {
                VStack(alignment: .trailing, spacing: 10) {
                    ForEach(Array(AuraQuickAction.allCases.enumerated()), id: \.element.id) { idx, action in
                        quickActionChip(action)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            // Staggered so the stack cascades rather than
                            // arriving as one block (design: 0.06 + i × 0.05).
                            .animation(.spring(response: 0.3, dampingFraction: 0.72)
                                .delay(0.06 + Double(idx) * 0.05), value: fabOpen)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, AuraSpacing.s4)
                .padding(.bottom, barHeight + 10)
                .zIndex(90)
            }

            HStack(spacing: collapsed ? 6 : 10) {
                glassPill
                fab
            }
            // Collapsed shrinks the pill toward the design's 72% width by
            // widening the gutters; the FAB stays put on the right.
            .padding(.horizontal, collapsed ? 40 : 10)
            .padding(.bottom, collapsed ? 30 : 38)
        }
        .animation(.easeInOut(duration: 0.25), value: collapsed)
    }

    // MARK: Glass pill

    private var glassPill: some View {
        GeometryReader { geo in
            let count = CGFloat(AuraTab.allCases.count)
            let inset: CGFloat = 4
            let slot = (geo.size.width - inset * 2) / count
            // Follows the finger mid-swipe, so the pill previews where you are
            // heading rather than jumping only once the gesture commits.
            let target = min(max(CGFloat(selection.rawValue) + swipeProgress, 0), count - 1)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AuraRadius.pill)
                    .fill(Color.aura.accent)
                    .frame(width: slot, height: geo.size.height - inset * 2)
                    .shadow(color: Color.aura.accent.opacity(0.5), radius: 7, x: 0, y: 2)
                    .offset(x: inset + target * slot, y: inset)
                    // No animation while dragging: the indicator has to track
                    // the finger 1:1 or it visibly lags the gesture.
                    .animation(dragging ? nil : .timingCurve(0.4, 0, 0.2, 1, duration: 0.32),
                               value: target)

                HStack(spacing: 0) {
                    ForEach(AuraTab.allCases) { tab in
                        tabButton(tab, height: geo.size.height)
                    }
                }
            }
        }
        .frame(height: pillHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AuraRadius.pill))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.pill)
                .stroke(Color.aura.text.opacity(0.11), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.pill))
        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 4)
        .gesture(swipeGesture)
    }

    private func tabButton(_ tab: AuraTab, height: CGFloat) -> some View {
        let active = selection == tab
        return Button {
            // Tapping a tab also dismisses an open FAB menu.
            if fabOpen { closeFab() }
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                AuraTabIcon(tab: tab)
                    .stroke(active ? Color.white : Color.aura.text3,
                            style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    .frame(width: 22, height: 22)
                if !collapsed {
                    Text(tab.title)
                        .font(AuraFont.jakarta(10, .semibold))
                        .tracking(0.1) // letter-spacing: 0.01em × 10
                        .foregroundColor(active ? .white : .aura.text3)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: active)
    }

    // MARK: FAB

    private var fab: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { fabOpen.toggle() }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: collapsed ? 15 : 22, weight: .semibold))
                .foregroundColor(fabOpen ? .aura.text : .white)
                // + becomes × while the menu is open.
                .rotationEffect(.degrees(fabOpen ? 45 : 0))
                .frame(width: fabSize, height: fabSize)
                .background {
                    if fabOpen {
                        Circle().fill(.ultraThinMaterial)
                    } else {
                        Circle().fill(Color.aura.accent)
                    }
                }
                .overlay(Circle().stroke(Color.aura.text.opacity(0.12), lineWidth: 1))
                .shadow(color: fabOpen ? .black.opacity(0.14) : Color.aura.accent.opacity(0.55),
                        radius: fabOpen ? 8 : 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fabOpen ? "Close quick actions" : "Quick actions")
    }

    private func quickActionChip(_ action: AuraQuickAction) -> some View {
        Button {
            closeFab()
            onQuickAction(action)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(action.color).frame(width: 32, height: 32)
                    Image(systemName: action.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(action.label)
                    .font(AuraFont.jakarta(14, .bold))
                    .foregroundColor(.aura.text)
            }
            .padding(.leading, 12)
            .padding(.trailing, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.aura.text.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func closeFab() {
        withAnimation(.easeOut(duration: 0.18)) { fabOpen = false }
    }

    // MARK: Swipe between tabs

    /// Horizontal drag on the bar moves one tab over, previewing the
    /// destination live. Guarded at both ends so you can never swipe past Log
    /// or Profile — and so the indicator shows no drift when you try.
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                dragging = true
                let idx = selection.rawValue
                // ~70pt of travel is one tab's worth, matching the design's
                // "quarter of the pill width" on a phone-width bar.
                let progress = max(min(value.translation.width / 70, 1), -1)
                let canGoNext = progress < 0 && idx < AuraTab.allCases.count - 1
                let canGoPrev = progress > 0 && idx > 0
                swipeProgress = (canGoNext || canGoPrev) ? -progress : 0
            }
            .onEnded { value in
                dragging = false
                withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)) { swipeProgress = 0 }

                let dx = value.translation.width
                guard abs(dx) >= 35 else { return }   // below threshold: snap back
                let idx = selection.rawValue
                withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.32)) {
                    if dx < 0, idx < AuraTab.allCases.count - 1 {
                        selection = AuraTab(rawValue: idx + 1) ?? selection
                    } else if dx > 0, idx > 0 {
                        selection = AuraTab(rawValue: idx - 1) ?? selection
                    }
                }
            }
    }
}

// MARK: - Exact tab glyphs (ported from styles/icons.js path data, 24×24 space)

/// Draws the design's custom tab-bar SVG icons as SwiftUI `Path`s so they match
/// `icons.js` exactly rather than approximating with SF Symbols. All paths are
/// authored in the 24×24 SVG coordinate space and scaled to the target rect.
struct AuraTabIcon: Shape {
    let tab: AuraTab

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24.0
        let ox = rect.minX + (rect.width  - 24 * s) / 2
        let oy = rect.minY + (rect.height - 24 * s) / 2
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }

        var p = Path()
        switch tab {
        case .log:
            // icons.js 'log':
            // M8 2v3 M16 2v3 M3.5 9h17  rect(3.5,4.5,17,16,r3)  M7.5 13.5h3 M7.5 17h3 M14 13.5h2.5
            p.move(to: P(8, 2));  p.addLine(to: P(8, 5))
            p.move(to: P(16, 2)); p.addLine(to: P(16, 5))
            addRoundedRect(&p, x: 3.5, y: 4.5, w: 17, h: 16, r: 3, s: s, ox: ox, oy: oy)
            p.move(to: P(3.5, 9)); p.addLine(to: P(20.5, 9))
            p.move(to: P(7.5, 13.5)); p.addLine(to: P(10.5, 13.5))
            p.move(to: P(7.5, 17));   p.addLine(to: P(10.5, 17))
            p.move(to: P(14, 13.5));  p.addLine(to: P(16.5, 13.5))

        case .plan:
            // icons.js 'dumbbell':
            // M6.5 6.5l11 11 M4 9l-1.5 1.5a2 2 0 0 0 0 2.8L4 14.8 M9 4l-1.2 1.2
            // M20 15l1.5-1.5a2 2 0 0 0 0-2.8L20 9.2 M15 20l1.2-1.2
            p.move(to: P(6.5, 6.5)); p.addLine(to: P(17.5, 17.5))
            p.move(to: P(4, 9)); p.addLine(to: P(2.5, 10.5))
            p.addCurve(to: P(2.5, 13.3), control1: P(1.95, 11.05), control2: P(1.95, 12.75))
            p.addLine(to: P(4, 14.8))
            p.move(to: P(9, 4)); p.addLine(to: P(7.8, 5.2))
            p.move(to: P(20, 15)); p.addLine(to: P(21.5, 13.5))
            p.addCurve(to: P(21.5, 10.7), control1: P(22.05, 12.95), control2: P(22.05, 11.25))
            p.addLine(to: P(20, 9.2))
            p.move(to: P(15, 20)); p.addLine(to: P(16.2, 18.8))

        case .progress:
            // icons.js 'chart': M4 20V10 M10 20V4 M16 20v-7 M22 20H2
            p.move(to: P(4, 20));  p.addLine(to: P(4, 10))
            p.move(to: P(10, 20)); p.addLine(to: P(10, 4))
            p.move(to: P(16, 20)); p.addLine(to: P(16, 13))
            p.move(to: P(22, 20)); p.addLine(to: P(2, 20))

        case .profile:
            // icons.js 'person': circle(12,8,r4)  M4 21c0-4 3.5-7 8-7s8 3 8 7
            p.addEllipse(in: CGRect(x: ox + 8 * s, y: oy + 4 * s, width: 8 * s, height: 8 * s))
            p.move(to: P(4, 21))
            p.addCurve(to: P(12, 14), control1: P(4, 17), control2: P(7.5, 14))
            p.addCurve(to: P(20, 21), control1: P(16.5, 14), control2: P(20, 17))
        }
        return p
    }

    private func addRoundedRect(_ p: inout Path, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                                r: CGFloat, s: CGFloat, ox: CGFloat, oy: CGFloat) {
        let rect = CGRect(x: ox + x * s, y: oy + y * s, width: w * s, height: h * s)
        p.addRoundedRect(in: rect, cornerSize: CGSize(width: r * s, height: r * s))
    }
}
