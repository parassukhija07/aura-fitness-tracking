import SwiftUI

// MARK: - Sub-tab bodies (Programs / Workouts / Exercises)
//
// Prototype-faithful bodies from plan/app.jsx (ProgramsView, WorkoutsView,
// ExercisesView) wired to the real databases. Data comes in as props from
// PlanTabView; taps route back out so the existing DB-backed detail/editor
// screens handle CRUD.

// MARK: Programs library

struct PlanProgramsBody: View {
    let programs: [Program]
    /// Programs already added to My Plans (drives the "Added" badge).
    let addedProgramIDs: Set<UUID>
    var onProgram: (Program) -> Void

    @State private var query = ""
    @State private var openFilter: String?
    @State private var freq: String?
    @State private var level: String?
    @State private var type: String?

    struct ProgFilter: Identifiable { let id: String; let label: String; let opts: [String] }

    /// Filter options derived from the live library (prototype ships fixed
    /// PROG_META; native derives so custom programs filter correctly).
    private var filterDefs: [ProgFilter] {
        [
            ProgFilter(id: "freq", label: "Frequency",
                       opts: Set(programs.map { "\($0.daysPerWeek) days/wk" }).sorted()),
            ProgFilter(id: "level", label: "Level",
                       opts: Set(programs.map(\.level)).sorted()),
            ProgFilter(id: "type", label: "Type",
                       opts: Set(programs.map(\.style)).sorted()),
        ]
    }

    private func value(_ id: String) -> String? {
        switch id { case "freq": return freq; case "level": return level
        case "type": return type; default: return nil }
    }
    private func setValue(_ id: String, _ v: String?) {
        switch id { case "freq": freq = v; case "level": level = v
        case "type": type = v; default: break }
    }

    private var filtered: [Program] {
        programs.filter { p in
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            let mq = q.isEmpty || p.name.lowercased().contains(q)
                || p.style.lowercased().contains(q) || p.level.lowercased().contains(q)
            return mq
                && (freq == nil || "\(p.daysPerWeek) days/wk" == freq)
                && (level == nil || p.level == level)
                && (type == nil || p.style == type)
        }
    }

    private var activeCount: Int { [freq, level, type].compactMap { $0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                PlanSearchField(placeholder: "Search programs", text: $query)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if activeCount > 0 {
                            Button {
                                freq = nil; level = nil; type = nil
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark").font(AuraFont.jakarta(11, .bold))
                                    Text("Clear").font(AuraFont.jakarta(12, .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.aura.red)
                                .clipShape(Capsule())
                            }
                        }
                        ForEach(filterDefs) { f in
                            PlanFilterChip(label: value(f.id) ?? f.label, active: value(f.id) != nil,
                                           outlined: true, trailingChevron: true) {
                                openFilter = f.id
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 8)

            AuraScreenScroll {
                if filtered.isEmpty {
                    PlanEmptyState(title: "No programs found", subtitle: "Try a different filter")
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { p in
                            programCard(p)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                }
            }
        }
        .sheet(item: Binding(get: { openFilter.map { IdString($0) } }, set: { openFilter = $0?.value })) { wrapped in
            filterSheet(wrapped.value)
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
        }
    }

    private func programCard(_ p: Program) -> some View {
        PlanLibraryCard(
            title: p.name,
            meta: AnyView(
                HStack(spacing: 6) {
                    Text("\(p.daysPerWeek) days/wk"); dot(); Text(p.level); dot(); Text(p.style)
                }
                .font(AuraFont.jakarta(13))
                .foregroundColor(.aura.text2)
                .lineLimit(1)
            ),
            trailing: {
                if addedProgramIDs.contains(p.id) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark").font(AuraFont.jakarta(12, .bold))
                        Text("Added").font(AuraFont.badge())
                    }
                    .foregroundColor(.aura.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.aura.accentSoft)
                    .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(AuraFont.jakarta(14, .semibold)).foregroundColor(.aura.text3)
                }
            },
            action: { onProgram(p) }
        )
    }

    private func dot() -> some View {
        Circle().fill(Color.aura.text3).frame(width: 3, height: 3)
    }

    @ViewBuilder
    private func filterSheet(_ id: String) -> some View {
        let f = filterDefs.first { $0.id == id }!
        let current = value(id)
        PlanSheet(title: f.label, onClose: { openFilter = nil }) {
            PlanList {
                ForEach(Array((["All"] + f.opts).enumerated()), id: \.offset) { i, o in
                    let isSel = (o == "All") ? (current == nil) : (current == o)
                    Button {
                        setValue(id, o == "All" ? nil : o); openFilter = nil
                    } label: {
                        HStack {
                            Text(o)
                                .font(AuraFont.jakarta(16, isSel ? .bold : .medium))
                                .foregroundColor(isSel ? .aura.accent : .aura.text)
                            Spacer()
                            if isSel {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(AuraFont.jakarta(20)).foregroundColor(.aura.accent)
                            }
                        }
                        .padding(.vertical, 11).padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .background(isSel ? Color.aura.accentSoft : Color.aura.surface)
                    }
                    .buttonStyle(.plain)
                    if i < f.opts.count { Divider().padding(.leading, 14) }
                }
            }
        }
    }
}

/// Identifiable string wrapper for `.sheet(item:)` on the filter id.
private struct IdString: Identifiable { let value: String; var id: String { value }; init(_ v: String) { value = v } }

// MARK: Workouts library

struct PlanWorkoutsBody: View {
    let workouts: [Workout]
    var onEdit: (Workout) -> Void

    @State private var query = ""
    @State private var filter = "All"
    private let filters = ["All", "Push", "Pull", "Legs", "Upper", "Chest", "Back"]

    private var filtered: [Workout] {
        workouts.filter { w in
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            let mq = q.isEmpty || w.name.lowercased().contains(q) || w.primaryMuscles.lowercased().contains(q)
            let mf = filter == "All" || w.name.lowercased().contains(filter.lowercased())
                || w.primaryMuscles.lowercased().contains(filter.lowercased())
            return mq && mf
        }
    }

    var body: some View {
        AuraScreenScroll {
            VStack(alignment: .leading, spacing: 0) {
                PlanSearchField(placeholder: "Search workouts", text: $query)
                    .padding(.top, 6).padding(.bottom, 8)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(filters, id: \.self) { f in
                            PlanFilterChip(label: f, active: filter == f) { filter = f }
                        }
                    }
                }
                .padding(.bottom, 8)

                if filtered.isEmpty {
                    PlanEmptyState(title: "No workouts found", subtitle: "Try a different search or filter")
                } else {
                    VStack(spacing: 10) {
                        ForEach(filtered) { w in
                            PlanLibraryCard(
                                themeName: w.name,
                                title: w.name,
                                meta: AnyView(
                                    Text("\(w.exercises.count) exercises · \(w.primaryMuscles)")
                                        .font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)
                                        .lineLimit(1)
                                ),
                                trailing: {
                                    Image(systemName: "chevron.right")
                                        .font(AuraFont.jakarta(14, .semibold)).foregroundColor(.aura.text3)
                                },
                                action: { onEdit(w) }
                            )
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 14)
        }
    }
}

// MARK: Exercises library

struct PlanExercisesBody: View {
    let entries: [ExerciseEntry]
    var onExercise: (ExerciseEntry) -> Void

    @State private var query = ""
    @State private var muscleFilter = "All"
    @State private var equipFilter = "All"
    private let muscles = ["All", "Chest", "Back", "Shoulders", "Arms", "Legs", "Core"]
    private let equips = ["All", "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Smith Machine"]

    private var filtered: [ExerciseEntry] {
        entries.filter { e in
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            let mq = q.isEmpty || e.name.lowercased().contains(q)
                || e.category.lowercased().contains(q) || e.equipment.lowercased().contains(q)
            let mm = muscleFilter == "All"
                || PlanMusclePalette.displayLabel(e.category) == muscleFilter
            let me = equipFilter == "All" || e.equipment == equipFilter
            return mq && mm && me
        }
    }

    /// Grid rows rendered through the prototype's muscle-tinted thumb cells.
    private var gridItems: [PlanLibExercise] {
        filtered.map {
            PlanLibExercise(id: $0.id.uuidString, name: $0.name,
                            muscle: $0.category, equip: $0.equipment)
        }
    }

    var body: some View {
        AuraScreenScroll {
            VStack(alignment: .leading, spacing: 0) {
                PlanSearchField(placeholder: "Search exercises", text: $query)
                    .padding(.top, 6).padding(.bottom, 6)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(muscles, id: \.self) { m in
                            PlanFilterChip(label: m, active: muscleFilter == m,
                                           palette: PlanMusclePalette.chip(m)) { muscleFilter = m }
                        }
                    }
                }
                .padding(.bottom, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(equips, id: \.self) { eq in
                            PlanFilterChip(label: eq == "Smith Machine" ? "Smith" : eq,
                                           active: equipFilter == eq) { equipFilter = eq }
                        }
                    }
                }
                .padding(.bottom, 10)

                if filtered.isEmpty {
                    PlanEmptyState(title: "No exercises found", subtitle: "Try a different filter")
                } else {
                    PlanCatalogGrid(exercises: gridItems) { tapped in
                        if let entry = entries.first(where: { $0.id.uuidString == tapped.id }) {
                            onExercise(entry)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
        }
    }
}
