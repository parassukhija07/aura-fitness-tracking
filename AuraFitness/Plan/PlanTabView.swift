import SwiftUI

struct PlanTabView: View {
    @State private var selectedTab = "My Plans"
    private let tabs = ["My Plans", "Programs", "Workouts", "Exercises"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sub-tab pill picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AuraSpacing.s2) {
                        ForEach(tabs, id: \.self) { tab in
                            AuraChip(label: tab, active: selectedTab == tab) {
                                selectedTab = tab
                            }
                        }
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.vertical, AuraSpacing.s2)
                }

                Divider()

                // Tab content
                Group {
                    switch selectedTab {
                    case "My Plans":    MyPlansView()
                    case "Programs":    ProgramLibraryView()
                    case "Workouts":    WorkoutLibraryView()
                    case "Exercises":   ExerciseLibraryTabView()
                    default:            MyPlansView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
