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

    /// SF Symbol mapped from the design's custom icon set (README "Assets").
    var icon: String {
        switch self {
        case .log:      return "calendar"
        case .plan:     return "dumbbell"
        case .progress: return "chart.bar"
        case .profile:  return "person"
        }
    }
}

// MARK: - FAB quick action model (mirrors ui.jsx ACTIONS)

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
    var icon: String {
        switch self {
        case .startWorkout:   return "play.circle.fill"
        case .logMeasurement: return "square.and.pencil"
        case .progressPhoto:  return "medal.fill"
        }
    }
    var color: Color {
        switch self {
        case .startWorkout:   return .aura.accent
        case .logMeasurement: return .aura.blue
        case .progressPhoto:  return .aura.green
        }
    }
}

// MARK: - Scroll-direction preference (drives collapse)

/// Notification posted by tab content scroll views so the floating bar can collapse.
extension Notification.Name {
    static let auraScroll = Notification.Name("aura:scroll")
}

// MARK: - Glass pill tab bar + FAB

/// Floating translucent tab bar matching the design's `ui.jsx` TabBarEl:
/// a glass pill with a sliding accent indicator + a separate FAB that fans out
/// quick actions. Supports swipe-between-tabs and scroll-collapse.
struct AuraTabBar: View {
    @Binding var selection: AuraTab
    var collapsed: Bool = false
    let onQuickAction: (AuraQuickAction) -> Void

    @State private var fabOpen = false
    @State private var dragOffset: CGFloat = 0

    private let actions: [AuraQuickAction] = [.startWorkout, .logMeasurement, .progressPhoto]

    private var barHeight: CGFloat { collapsed ? 66 : 96 }
    private var fabSize: CGFloat { collapsed ? 34 : 46 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Quick-action fan-out menu
            if fabOpen {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { fabOpen = false } }

                VStack(alignment: .trailing, spacing: 10) {
                    ForEach(Array(actions.enumerated()), id: \.element.id) { idx, action in
                        quickActionButton(action)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.3, dampingFraction: 0.7)
                                .delay(Double(idx) * 0.05), value: fabOpen)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, AuraSpacing.s4)
                .padding(.bottom, barHeight + 10)
            }

            HStack(spacing: collapsed ? 6 : 10) {
                glassPill
                fab
            }
            .padding(.horizontal, collapsed ? 8 : 10)
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
            let indicatorX = inset + CGFloat(selection.rawValue) * slot + dragOffset

            ZStack(alignment: .leading) {
                // Sliding accent indicator
                RoundedRectangle(cornerRadius: AuraRadius.pill)
                    .fill(Color.aura.accent)
                    .frame(width: slot, height: geo.size.height - inset * 2)
                    .offset(x: max(inset, min(indicatorX, inset + (count - 1) * slot)),
                            y: inset)
                    .shadow(color: Color.aura.accent.opacity(0.5), radius: 7, x: 0, y: 2)
                    .animation(.spring(response: 0.32, dampingFraction: 0.8), value: selection)

                HStack(spacing: 0) {
                    ForEach(AuraTab.allCases) { tab in
                        Button {
                            withAnimation { selection = tab }
                            if fabOpen { withAnimation { fabOpen = false } }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 21, weight: .medium))
                                if !collapsed {
                                    Text(tab.title)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                            }
                            .foregroundColor(selection == tab ? .white : .aura.text3)
                            .frame(maxWidth: .infinity)
                            .frame(height: geo.size.height)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: collapsed ? 50 : 62)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AuraRadius.pill))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.pill)
                .stroke(Color.aura.text.opacity(0.11), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.pill))
        .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 4)
        .gesture(swipeGesture)
    }

    // MARK: FAB

    private var fab: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { fabOpen.toggle() }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: collapsed ? 15 : 22, weight: .semibold))
                .foregroundColor(fabOpen ? .aura.text : .white)
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
    }

    private func quickActionButton(_ action: AuraQuickAction) -> some View {
        Button {
            withAnimation { fabOpen = false }
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
                    .font(.system(size: 14, weight: .bold))
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

    // MARK: Swipe-between-tabs

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // Light rubber-band follow of the indicator while dragging.
                dragOffset = value.translation.width / 8
            }
            .onEnded { value in
                dragOffset = 0
                let dx = value.translation.width
                guard abs(dx) > 35 else { return }
                let idx = selection.rawValue
                if dx < 0, idx < AuraTab.allCases.count - 1 {
                    withAnimation { selection = AuraTab(rawValue: idx + 1)! }
                } else if dx > 0, idx > 0 {
                    withAnimation { selection = AuraTab(rawValue: idx - 1)! }
                }
            }
    }
}
