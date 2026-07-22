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

// MARK: - FAB quick action model (retained for deep-link routing; the design's
// Log screen has no FAB, so the flat tab bar no longer renders these. Kept so
// ContentView's existing quick-action routing continues to compile.)

enum AuraQuickAction: Identifiable {
    case startWorkout, logMeasurement, progressPhoto
    var id: String { label }

    var label: String {
        switch self {
        case .startWorkout:   return "Start Workout"
        case .logMeasurement: return "Log Measurements"
        case .progressPhoto:  return "Progress Photo"
        }
    }
}

// MARK: - Scroll-direction preference

/// Posted by tab content scroll views. The design's flat bar does not collapse,
/// so this is currently inert, but the symbol stays defined for AuraScreenScroll.
extension Notification.Name {
    static let auraScroll = Notification.Name("aura:scroll")
}

// MARK: - Flat bottom tab bar (matches aura.css `.tabbar` / screens/Log.html)

/// The design's Log/Plan/Progress/Profile bar: flat, transparent, four equal
/// tabs pinned to the bottom. No pill, no glass, no FAB. Inactive tabs use
/// `--text-3`; the active tab is `--accent` with an accent drop-shadow glow on
/// its icon.
///
/// The design's `.home-indicator` bar is deliberately NOT ported. In the HTML
/// prototype that capsule stood in for iOS chrome the browser could not draw;
/// on device the system draws the real home indicator in the same place, so
/// rendering it ourselves put a second black bar under the first. Do not
/// re-add it — the safe-area inset below the tab row is where the system one
/// goes.
struct AuraTabBar: View {
    @Binding var selection: AuraTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AuraTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(Color.clear)
    }

    private func tabButton(_ tab: AuraTab) -> some View {
        let active = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                AuraTabIcon(tab: tab)
                    .stroke(active ? Color.aura.accent : Color.aura.text3,
                            style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    .frame(width: 25, height: 25)
                    // .tab.active svg { filter: drop-shadow(0 0 6px accent 55%) }
                    .shadow(color: active ? Color.aura.accent.opacity(0.55) : .clear,
                            radius: active ? 6 : 0)
                Text(tab.title)
                    .font(AuraFont.jakarta(10, .semibold))
                    .tracking(0.1) // letter-spacing: 0.01em × 10
                    .foregroundColor(active ? .aura.accent : .aura.text3)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: active) // .tab { transition: color .15s }
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
