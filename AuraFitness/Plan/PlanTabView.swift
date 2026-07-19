import SwiftUI

// MARK: - Plan tab
//
// Faithful native port of `.design-import-v9/plan/app.jsx` (Phase 4 · 04-plan.html).
// Five pieces of state act like a tiny router, checked in priority order:
//   viewingEx → editingWk → editingProg → viewingProg → (sub-tab shell)
// Whichever is set wins and replaces the entire tab (hard swap, no push animation).

struct PlanTabView: View {
    @EnvironmentObject var appState: AppState

    private enum Subtab: String, CaseIterable {
        case myplans, programs, workouts, exercises
        var label: String {
            switch self { case .myplans: return "My Plans"; case .programs: return "Programs"
            case .workouts: return "Workouts"; case .exercises: return "Exercises" }
        }
    }

    @State private var subtab: Subtab = .myplans

    var body: some View {
        VStack(spacing: 0) {
            navbar
            Group {
                switch subtab {
                case .myplans:   MyPlansView()
                case .programs:  ProgramLibraryView()
                case .workouts:  NavigationStack { WorkoutLibraryView() }
                case .exercises: NavigationStack { ExerciseLibraryTabView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.aura.bg)
    }

    private var navbar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Plan").font(AuraFont.largeTitleStyle()).tracking(AuraFont.largeTitleTracking)
                    .foregroundColor(.aura.text)
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Subtab.allCases, id: \.self) { st in
                        PlanFilterChip(label: st.label, active: subtab == st) { subtab = st }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, AuraSpacing.s1)
        .padding(.bottom, AuraSpacing.s2)
    }
}
