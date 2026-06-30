import SwiftUI

// MARK: - Tab definition
enum AuraTab: Int, CaseIterable {
    case log, plan, progress, profile

    var label: String {
        switch self {
        case .log:      return "Log"
        case .plan:     return "Plan"
        case .progress: return "Progress"
        case .profile:  return "Profile"
        }
    }

    var icon: String {
        switch self {
        case .log:      return "calendar"
        case .plan:     return "dumbbell"
        case .progress: return "chart.bar"
        case .profile:  return "person"
        }
    }
}

// MARK: - Scroll collapse preference key
struct TabBarCollapseKey: PreferenceKey {
    static var defaultValue: Bool = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

// MARK: - FAB action
enum FABAction: String, CaseIterable {
    case workout = "workout"
    case measure = "measure"
    case photo   = "photo"

    var icon: String {
        switch self {
        case .workout: return "play.fill"
        case .measure: return "calendar.badge.plus"
        case .photo:   return "camera.fill"
        }
    }

    var label: String {
        switch self {
        case .workout: return "Start Workout"
        case .measure: return "Log Measurements"
        case .photo:   return "Progress Photo"
        }
    }

    var color: Color {
        switch self {
        case .workout: return .aura.accent
        case .measure: return .aura.blue
        case .photo:   return .aura.green
        }
    }
}

// MARK: - AuraTabBar
struct AuraTabBar: View {
    @Binding var selectedTab: AuraTab
    var collapsed: Bool = false
    var onFABAction: ((FABAction) -> Void)? = nil

    @State private var fabOpen: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @GestureState private var dragState: CGFloat = 0

    private let barHeight: CGFloat = 96
    private let collapsedHeight: CGFloat = 66

    var body: some View {
        let h = collapsed ? collapsedHeight : barHeight

        ZStack(alignment: .bottom) {
            // FAB scrim + items
            if fabOpen {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { fabOpen = false } }
                    .ignoresSafeArea()

                VStack(alignment: .trailing, spacing: 10) {
                    ForEach(Array(FABAction.allCases.enumerated()), id: \.element.rawValue) { idx, action in
                        fabItem(action: action, delay: Double(idx) * 0.05)
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, h + 10)
                .transition(.opacity)
            }

            // Bar row
            HStack(alignment: .center, spacing: collapsed ? 6 : 10) {
                glassPill
                fabButton
            }
            .padding(.horizontal, collapsed ? 8 : 10)
            .padding(.bottom, collapsed ? 30 : 38)
            .frame(height: h)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: collapsed)
        }
    }

    // MARK: Glass pill
    private var glassPill: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Sliding accent indicator
                let tabW = (geo.size.width - 8) / CGFloat(AuraTab.allCases.count)
                let idx = CGFloat(selectedTab.rawValue)
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.aura.accent)
                    .frame(width: tabW, height: geo.size.height - 8)
                    .offset(x: 4 + idx * tabW)
                    .shadow(color: Color.aura.accent.opacity(0.5), radius: 7)
                    .animation(isDragging ? nil : .spring(response: 0.32, dampingFraction: 0.78), value: selectedTab)

                // Tab buttons
                HStack(spacing: 0) {
                    ForEach(AuraTab.allCases, id: \.rawValue) { tab in
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                                fabOpen = false
                                selectedTab = tab
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 22, weight: .medium))
                                if !collapsed {
                                    Text(tab.label)
                                        .font(AuraFont.tiny())
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .transition(.opacity)
                                }
                            }
                            .foregroundColor(selectedTab == tab ? .white : Color.aura.text3)
                            .frame(maxWidth: .infinity)
                            .frame(height: geo.size.height)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: collapsed ? 42 : 54)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(Color.primary.opacity(0.11), lineWidth: 1))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 4)
        )
        // Swipe left/right to change tab
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { _ in isDragging = true }
                .onEnded { val in
                    isDragging = false
                    let dx = val.translation.width
                    guard abs(dx) > 35 else { return }
                    let newRaw = selectedTab.rawValue + (dx < 0 ? 1 : -1)
                    if let next = AuraTab(rawValue: max(0, min(AuraTab.allCases.count - 1, newRaw))) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            selectedTab = next
                        }
                    }
                }
        )
    }

    // MARK: FAB button
    private var fabButton: some View {
        let size: CGFloat = collapsed ? 34 : 46
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { fabOpen.toggle() }
        } label: {
            ZStack {
                Circle()
                    .fill(fabOpen ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.aura.accent))
                    .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 1))
                    .shadow(
                        color: fabOpen ? .black.opacity(0.1) : Color.aura.accent.opacity(0.55),
                        radius: fabOpen ? 4 : 10, y: 2
                    )
                Image(systemName: "plus")
                    .font(.system(size: collapsed ? 15 : 22, weight: .semibold))
                    .foregroundColor(fabOpen ? .aura.text : .white)
                    .rotationEffect(.degrees(fabOpen ? 45 : 0))
                    .animation(.spring(response: 0.25), value: fabOpen)
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }

    // MARK: FAB item row
    private func fabItem(_ action: FABAction, delay: Double) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) { fabOpen = false }
            onFABAction?(action)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(action.color).frame(width: 32, height: 32)
                    Image(systemName: action.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(action.label)
                    .font(AuraFont.secondary())
                    .fontWeight(.bold)
                    .foregroundColor(.aura.text)
            }
            .padding(.trailing, 18)
            .padding(.leading, 10)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(Color.primary.opacity(0.14), lineWidth: 1))
                    .shadow(color: .black.opacity(0.22), radius: 16, y: 4)
            )
        }
        .buttonStyle(.plain)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }
}
