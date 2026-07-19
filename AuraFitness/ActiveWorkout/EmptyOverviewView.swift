import SwiftUI

/// The build-your-workout screen shown when an active workout has 0 exercises.
/// Mirrors emptyOverview() in workout/app.jsx.
struct EmptyOverviewView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: WorkoutSessionState
    @Binding var showEndSheet: Bool
    let onAdd: () -> Void

    @State private var activeMuscle: String? = nil
    @State private var activeEquip = "All"

    private var activeGroup: MuscleGroupOption? {
        ActiveWorkoutData.muscleGroups.first { $0.label == activeMuscle }
    }

    private var filteredGroupExercises: [WorkoutExerciseOption] {
        guard let g = activeGroup else { return [] }
        return g.exercises.filter { activeEquip == "All" || $0.equipment == activeEquip }
    }

    private var filteredSuggestions: [WorkoutExerciseOption] {
        ActiveWorkoutData.suggestions.filter { activeEquip == "All" || $0.equipment == activeEquip }
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    searchBar
                    AuraSectionLabel(title: "Quick add by muscle")
                    muscleChips
                    AuraSectionLabel(title: "Filter by equipment")
                    equipmentChips
                    catalog
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.bottom, 120)
            }
        }
        .background(Color.aura.bg)
    }

    private var navBar: some View {
        HStack {
            Button { showEndSheet = true } label: {
                Text("End").font(AuraFont.body()).foregroundColor(.aura.red)
            }
            Spacer()
            VStack(spacing: 1) {
                Text(session.workout.name).font(AuraFont.jakarta(12, .bold)).foregroundColor(.aura.text2)
                Text(session.elapsedFormatted)
                    .font(AuraFont.statNum(size: 19)).foregroundColor(.aura.accent).monospacedDigit()
            }
            Spacer()
            Button { appState.minimizeWorkout() } label: {
                Image(systemName: "minus").font(AuraFont.jakarta(22, .medium)).foregroundColor(.aura.text)
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var hero: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(Color.aura.accentSoft).frame(width: 72, height: 72)
                Image(systemName: "dumbbell.fill").font(AuraFont.jakarta(30)).foregroundColor(.aura.accent)
            }
            .padding(.bottom, 8)
            Text("Build your workout").font(AuraFont.jakarta(22, .heavy)).foregroundColor(.aura.text)
            Text("Add exercises as you go — everything is saved automatically.")
                .font(AuraFont.jakarta(14)).foregroundColor(.aura.text2)
                .multilineTextAlignment(.center).frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30).padding(.bottom, 24)
    }

    private var searchBar: some View {
        Button { onAdd() } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(AuraFont.jakarta(16)).foregroundColor(.aura.text3)
                Text("Search exercise library…").font(AuraFont.jakarta(15)).foregroundColor(.aura.text3)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Color.aura.fill.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        }
        .buttonStyle(.plain)
    }

    private var muscleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActiveWorkoutData.muscleGroups) { mg in
                    let on = activeMuscle == mg.label
                    Button { activeMuscle = on ? nil : mg.label } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(on ? Color.white.opacity(0.6) : mg.color)
                                .frame(width: 7, height: 7)
                            Text(mg.label).font(AuraFont.jakarta(13, .bold))
                        }
                        .foregroundColor(on ? .white : .aura.text)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(on ? mg.color : Color.aura.fill)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var equipmentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActiveWorkoutData.equipmentFilters, id: \.self) { eq in
                    let on = activeEquip == eq
                    Button { activeEquip = on ? "All" : eq } label: {
                        Text(eq).font(AuraFont.jakarta(13, .bold))
                            .foregroundColor(on ? .aura.bg : .aura.text)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(on ? Color.aura.text : Color.aura.fill)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var catalog: some View {
        let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        if let g = activeGroup {
            VStack(alignment: .leading, spacing: 8) {
                AuraSectionLabel(title: g.label)
                if filteredGroupExercises.isEmpty {
                    Text("No \(g.label) exercises for this equipment.")
                        .font(AuraFont.jakarta(13)).foregroundColor(.aura.text3)
                        .padding(.vertical, 12)
                } else {
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(filteredGroupExercises) { catCard($0) }
                    }
                }
            }
            .padding(.top, 16)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                AuraSectionLabel(title: "Suggested")
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(filteredSuggestions) { catCard($0) }
                }
            }
            .padding(.top, 16)
        }
    }

    private func catCard(_ opt: WorkoutExerciseOption) -> some View {
        Button { addAndStart(opt) } label: {
            VStack(alignment: .leading, spacing: 7) {
                RoundedRectangle(cornerRadius: AuraRadius.sm)
                    .fill(ActiveWorkoutData.muscleColor(opt.muscle).opacity(0.18))
                    .aspectRatio(4.0/3.0, contentMode: .fit)
                    .overlay(
                        Text(opt.muscle.uppercased())
                            .font(AuraFont.jakarta(11, .heavy))
                            .tracking(1)
                            .foregroundColor(ActiveWorkoutData.muscleColor(opt.muscle))
                    )
                Text(opt.name).font(AuraFont.jakarta(13, .bold)).foregroundColor(.aura.text)
                    .lineLimit(1)
                Text("\(opt.muscle) · \(opt.equipment)").font(AuraFont.jakarta(11)).foregroundColor(.aura.text3)
                    .lineLimit(1)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func addAndStart(_ opt: WorkoutExerciseOption) {
        let newIdx = session.workout.exercises.count
        session.addExercise(opt.makeExercise())
        session.activeView = .exercise(index: newIdx)
    }
}
