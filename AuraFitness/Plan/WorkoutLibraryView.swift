import SwiftUI

struct WorkoutLibraryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var programDB = ProgramDatabase.shared
    @State private var searchText = ""
    @State private var selectedFilter = "All"
    @State private var selectedWorkout: Workout? = nil
    @State private var showCreateWorkout = false

    let filters = ["All","Push","Pull","Legs","Full Body","Upper","Lower"]

    var filtered: [Workout] {
        programDB.allWorkouts.filter { w in
            (searchText.isEmpty || w.name.localizedCaseInsensitiveContains(searchText))
            && (selectedFilter == "All" || w.name.localizedCaseInsensitiveContains(selectedFilter)
                || w.primaryMuscles.localizedCaseInsensitiveContains(selectedFilter))
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
                .padding(.bottom, AuraSpacing.s2)
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreateWorkout = true } label: {
                    Image(systemName: "plus")
                }
                .foregroundColor(.aura.accent)
            }
        }
        .navigationDestination(item: $selectedWorkout) { w in
            WorkoutEditorView(workout: w, context: .view)
        }
        .sheet(isPresented: $showCreateWorkout) {
            WorkoutEditorView(workout: Workout(name: "", primaryMuscles: "", estimatedMinutes: 45, exercises: []), context: .createStandalone)
        }
    }

    @ViewBuilder
    private func workoutCard(_ workout: Workout) -> some View {
        AuraCard {
            HStack(spacing: AuraSpacing.s3) {
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
                    if !workout.primaryMuscles.isEmpty {
                        Text(workout.primaryMuscles)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text3)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundColor(.aura.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AuraSpacing.s4)
        }
    }
}
