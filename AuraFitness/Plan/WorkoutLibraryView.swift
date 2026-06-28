import SwiftUI

struct WorkoutLibraryView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var selectedWorkout: Workout? = nil

    let filters = ["All","Push","Pull","Legs","Full Body","Upper","Lower"]
    let allWorkouts = SeedData.programs.flatMap { $0.workouts }

    var filtered: [Workout] {
        allWorkouts.filter { w in
            (searchText.isEmpty || w.name.localizedCaseInsensitiveContains(searchText))
            && (selectedFilter == "All" || w.name.localizedCaseInsensitiveContains(selectedFilter))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AuraSpacing.s2) {
                Image(systemName: "magnifyingglass").foregroundColor(.aura.text3)
                TextField("Search workouts", text: $searchText).font(AuraFont.body())
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(AuraSpacing.screenPad)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(filters, id: \.self) { f in
                        AuraChip(label: f, active: selectedFilter == f) { selectedFilter = f }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
            }

            ScrollView {
                LazyVStack(spacing: AuraSpacing.s3) {
                    ForEach(filtered) { workout in
                        Button { selectedWorkout = workout } label: { workoutCard(workout) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(AuraSpacing.screenPad)
            }
        }
        .background(Color.aura.bgGrouped)
        .navigationDestination(item: $selectedWorkout) { w in
            WorkoutEditorView(workout: w)
        }
    }

    @ViewBuilder
    private func workoutCard(_ workout: Workout) -> some View {
        AuraCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(workout.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.aura.text)
                HStack(spacing: AuraSpacing.s2) {
                    Label("\(workout.exercises.count) exercises", systemImage: "list.bullet")
                    Label("~\(workout.estimatedMinutes) min", systemImage: "clock")
                }
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                Text(workout.primaryMuscles)
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AuraSpacing.s4)
        }
    }
}
