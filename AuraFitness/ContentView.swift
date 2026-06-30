import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: AuraTab = .log
    @State private var tabBarCollapsed: Bool = false
    @State private var workoutMinimised: Bool = false
    @State private var showActiveWorkout: Bool = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content
            tabContent
                .ignoresSafeArea(edges: .bottom)

            // Active workout full-screen overlay
            if showActiveWorkout, let session = appState.activeWorkoutSession {
                ActiveWorkoutView()
                    .environmentObject(session)
                    .ignoresSafeArea()
                    .transition(.move(edge: .bottom))
                    .zIndex(100)
            }

            // Bottom chrome: resume banner + tab bar
            VStack(spacing: 6) {
                if workoutMinimised, let session = appState.activeWorkoutSession {
                    ResumeBanner(session: session) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            workoutMinimised = false
                            showActiveWorkout = true
                        }
                    } onDiscard: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            workoutMinimised = false
                            appState.discardWorkout()
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                AuraTabBar(
                    selectedTab: $selectedTab,
                    collapsed: tabBarCollapsed
                ) { action in
                    handleFAB(action)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: workoutMinimised)
            .zIndex(50)
        }
        .preferredColorScheme(appState.darkModePreference.colorScheme)
        .onReceive(appState.$activeWorkoutSession) { session in
            if session != nil, !showActiveWorkout {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showActiveWorkout = true
                    workoutMinimised = false
                }
            }
            if session == nil {
                showActiveWorkout = false
                workoutMinimised = false
            }
        }
        // Collapse tab bar on scroll — tabs emit this via preference
        .onPreferenceChange(TabBarCollapseKey.self) { collapsed in
            withAnimation(.easeInOut(duration: 0.22)) {
                tabBarCollapsed = collapsed
            }
        }
    }

    // MARK: Tab content switcher
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .log:
            LogTabView()
        case .plan:
            PlanTabView()
        case .progress:
            ProgressTabView()
        case .profile:
            ProfileTabView()
        }
    }

    // MARK: FAB handler
    private func handleFAB(_ action: FABAction) {
        switch action {
        case .workout:
            if appState.activeWorkoutSession == nil {
                // Launch empty-mode workout
                let empty = Workout(name: "Quick Workout", primaryMuscles: "", estimatedMinutes: 0, exercises: [])
                appState.startWorkout(empty)
            } else {
                // Resume existing
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    workoutMinimised = false
                    showActiveWorkout = true
                }
            }
        case .measure:
            selectedTab = .progress
        case .photo:
            selectedTab = .progress
        }
    }
}

// MARK: - Scroll-collapse emitter
// Tabs wrap their ScrollView with this modifier to signal collapse direction.
struct CollapseOnScrollModifier: ViewModifier {
    @State private var lastOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: TabBarCollapseKey.self,
                            value: geo.frame(in: .global).minY < lastOffset - 8
                        )
                        .onAppear { lastOffset = geo.frame(in: .global).minY }
                        .onChange(of: geo.frame(in: .global).minY) { newVal in
                            lastOffset = newVal
                        }
                }
            )
    }
}

extension View {
    func collapseTabBarOnScroll() -> some View {
        modifier(CollapseOnScrollModifier())
    }
}
