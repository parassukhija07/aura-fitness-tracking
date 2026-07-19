import SwiftUI

// MARK: - ExerciseEntryDetailView (library-based, 3-tab)
struct ExerciseEntryDetailView: View {
    let entry: ExerciseEntry
    @StateObject private var db = ExerciseDatabase.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = "Overview"
    @State private var showAddToWorkout = false
    @State private var showEdit = false

    private let tabs = ["Overview", "Tips", "Warmup"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Hero
                heroSection

                // Sub-tabs
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                        } label: {
                            VStack(spacing: 6) {
                                Text(tab)
                                    .font(AuraFont.jakarta(14, selectedTab == tab ? .bold : .medium))
                                    .foregroundColor(selectedTab == tab ? .aura.accent : .aura.text2)
                                Rectangle()
                                    .fill(selectedTab == tab ? Color.aura.accent : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .background(Color.aura.surface)

                Divider()

                // Tab content
                ScrollView {
                    switch selectedTab {
                    case "Overview": overviewTab
                    case "Tips":     tipsTab
                    case "Warmup":   warmupTab
                    default:         overviewTab
                    }
                }
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if entry.isCustom {
                        Button("Edit") { showEdit = true }
                            .foregroundColor(.aura.accent)
                    } else {
                        Button {
                            db.toggleFavorite(id: entry.id)
                        } label: {
                            Image(systemName: currentEntry?.isFavorite == true ? "heart.fill" : "heart")
                                .foregroundColor(currentEntry?.isFavorite == true ? .aura.red : .aura.text2)
                        }
                    }
                }
            }
            .sheet(isPresented: $showEdit) {
                CreateExerciseView()  // future: pass entry for editing
            }
        }
    }

    private var currentEntry: ExerciseEntry? {
        db.entry(id: entry.id)
    }

    // MARK: Hero
    private var heroSection: some View {
        ZStack {
            Color.aura.surface
                .frame(height: 180)
            VStack(spacing: 10) {
                if let url = URL(string: entry.youtubeURL), !entry.youtubeURL.isEmpty {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 56, height: 56)
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .font(AuraFont.jakarta(22))
                    }
                    Text("Watch Demo")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text3)
                } else {
                    ZStack {
                        Circle()
                            .fill(categoryColor(entry.category).opacity(0.15))
                            .frame(width: 64, height: 64)
                        Text(entry.category.prefix(2).uppercased())
                            .font(AuraFont.jakarta(26, .heavy))
                            .foregroundColor(categoryColor(entry.category))
                    }
                }
            }
        }
    }

    // MARK: Overview tab
    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            // Info strip
            HStack(spacing: 0) {
                infoCell(label: entry.equipment, icon: "dumbbell")
                Divider()
                infoCell(label: entry.category, icon: "figure.strengthtraining.traditional")
                Divider()
                infoCell(label: entry.difficulty, icon: "star.fill")
                Divider()
                infoCell(label: entry.type, icon: "bolt.fill")
            }
            .frame(height: 60)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))

            // Muscle activation
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    Text("Muscles Targeted")
                        .sectionLabelStyle()
                    ForEach(entry.musclesTargeted, id: \.self) { muscle in
                        HStack {
                            Text(muscle)
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text)
                                .frame(width: 140, alignment: .leading)
                            AuraProgressBar(value: muscle == entry.musclesTargeted.first ? 1.0 : 0.45)
                        }
                    }
                }
                .padding(AuraSpacing.s4)
            }

            // Rep & set defaults
            AuraCard {
                HStack(spacing: AuraSpacing.s4) {
                    statCell(label: "Rep Range", value: entry.repRange)
                    Divider()
                    statCell(label: "Default Sets", value: "\(entry.plannedSets)")
                    if entry.isCable {
                        Divider()
                        statCell(label: "Pulley", value: entry.pulley.capitalized)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(AuraSpacing.s4)
            }

            // Actions
            AuraPrimaryButton(label: "Add to Today's Workout", icon: "plus") {
                showAddToWorkout = true
            }
            AuraTintedButton(label: "Add to a Plan") {
                showAddToWorkout = true
            }
        }
        .padding(AuraSpacing.screenPad)
        .padding(.bottom, 40)
    }

    // MARK: Tips tab
    private var tipsTab: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s3) {
            if entry.proTips.isEmpty {
                Text("No coaching tips available for this exercise.")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text3)
                    .padding(AuraSpacing.screenPad)
            } else {
                ForEach(Array(entry.proTips.enumerated()), id: \.offset) { i, tip in
                    AuraCard {
                        HStack(alignment: .top, spacing: AuraSpacing.s3) {
                            ZStack {
                                Circle()
                                    .fill(Color.aura.accent.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Text("\(i + 1)")
                                    .font(AuraFont.jakarta(14, .bold))
                                    .foregroundColor(.aura.accent)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tip \(i + 1)")
                                    .font(AuraFont.sectionLabel())
                                    .foregroundColor(.aura.text3)
                                Text(tip)
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }
                        .padding(AuraSpacing.s4)
                    }
                }
            }

            if !entry.notes.isEmpty {
                AuraCard {
                    VStack(alignment: .leading, spacing: AuraSpacing.s2) {
                        Label("Notes", systemImage: "note.text")
                            .sectionLabelStyle()
                        Text(entry.notes)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                    .padding(AuraSpacing.s4)
                }
            }
        }
        .padding(AuraSpacing.screenPad)
        .padding(.bottom, 40)
    }

    // MARK: Warmup tab
    private var warmupTab: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.aura.accent)
                        Text(entry.warmupProtocol.type)
                            .font(AuraFont.jakarta(15, .bold))
                            .foregroundColor(.aura.text)
                    }

                    if entry.warmupProtocol.steps.isEmpty {
                        Text("No specific warmup required for this exercise. Perform general mobility work before your session.")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    } else {
                        ForEach(entry.warmupProtocol.steps) { step in
                            warmupStepRow(step)
                        }
                    }
                }
                .padding(AuraSpacing.s4)
            }

            // General warmup tip
            AuraCard {
                HStack(alignment: .top, spacing: AuraSpacing.s3) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.aura.accent)
                        .font(AuraFont.jakarta(16))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Warmup Principle")
                            .font(AuraFont.sectionLabel())
                            .foregroundColor(.aura.text3)
                        Text("Always complete warmup sets before working sets. Warmup load should not cause fatigue — it prepares the CNS and joints.")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(AuraSpacing.s4)
            }
        }
        .padding(AuraSpacing.screenPad)
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private func warmupStepRow(_ step: WarmupStep) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            ZStack {
                Circle()
                    .fill(Color.aura.blue.opacity(0.15))
                    .frame(width: 32, height: 32)
                Text("S\(step.set)")
                    .font(AuraFont.jakarta(11, .bold))
                    .foregroundColor(.aura.blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(step.intensity)
                        .font(AuraFont.jakarta(13, .bold))
                        .foregroundColor(.aura.text)
                    Spacer()
                    Text("× \(step.reps) reps")
                        .font(AuraFont.jakarta(13, .medium))
                        .foregroundColor(.aura.accent)
                }
                if !step.description.isEmpty {
                    Text(step.description)
                        .font(AuraFont.jakarta(11))
                        .foregroundColor(.aura.text3)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func infoCell(label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(AuraFont.jakarta(14))
                .foregroundColor(.aura.text2)
            Text(label)
                .font(AuraFont.jakarta(11, .medium))
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(AuraFont.jakarta(17, .bold))
                .foregroundColor(.aura.text)
            Text(label)
                .font(AuraFont.jakarta(11))
                .foregroundColor(.aura.text3)
        }
        .frame(maxWidth: .infinity)
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "chest": return .aura.accent
        case "back": return .aura.blue
        case "shoulders": return .aura.purple
        case "arms": return .aura.green
        case "legs": return .aura.red
        case "core": return .aura.accent
        default: return .aura.text2
        }
    }
}

// MARK: - Legacy Exercise detail (used by active workout, kept for compatibility)
struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) var dismiss
    @StateObject private var db = ExerciseDatabase.shared

    var entry: ExerciseEntry? {
        db.entry(named: exercise.name)
    }

    var body: some View {
        if let e = entry {
            ExerciseEntryDetailView(entry: e)
        } else {
            // Fallback for exercises not in DB
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AuraRadius.lg)
                                .fill(Color.aura.surface)
                                .frame(height: 200)
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(Color.black.opacity(0.5)).frame(width: 56, height: 56)
                                    Image(systemName: "play.fill").foregroundColor(.white).font(AuraFont.jakarta(22))
                                }
                                Text("Exercise Demo").font(AuraFont.secondary()).foregroundColor(.aura.text3)
                            }
                        }

                        Text(exercise.name).font(AuraFont.cardTitle()).foregroundColor(.aura.text)

                        HStack(spacing: 0) {
                            infoCell(label: exercise.equipment, icon: "dumbbell")
                            Divider()
                            infoCell(label: exercise.primaryMuscle, icon: "figure.strengthtraining.traditional")
                            Divider()
                            infoCell(label: exercise.difficulty, icon: "star.fill")
                        }
                        .frame(height: 60)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))

                        if !exercise.hint.isEmpty {
                            AuraCard {
                                HStack(alignment: .top, spacing: AuraSpacing.s3) {
                                    Image(systemName: "lightbulb.fill").foregroundColor(.aura.accent).font(AuraFont.jakarta(16))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Pro Tip").font(AuraFont.sectionLabel()).foregroundColor(.aura.text3)
                                        Text(exercise.hint).font(AuraFont.secondary()).foregroundColor(.aura.text2).fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(AuraSpacing.s4)
                            }
                        }

                        AuraCard {
                            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                                Text("Muscle Activation").sectionLabelStyle()
                                ForEach(exercise.muscleGroups, id: \.self) { group in
                                    HStack {
                                        Text(group).font(AuraFont.secondary()).foregroundColor(.aura.text).frame(width: 100, alignment: .leading)
                                        AuraProgressBar(value: group == exercise.primaryMuscle ? 1.0 : 0.5)
                                    }
                                }
                            }
                            .padding(AuraSpacing.s4)
                        }
                    }
                    .padding(AuraSpacing.screenPad)
                    .padding(.bottom, 40)
                }
                .background(Color.aura.bgGrouped)
                .navigationTitle(exercise.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
    }

    @ViewBuilder
    private func infoCell(label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(AuraFont.jakarta(14)).foregroundColor(.aura.text2)
            Text(label).font(AuraFont.jakarta(11, .medium)).foregroundColor(.aura.text2).multilineTextAlignment(.center).lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}
