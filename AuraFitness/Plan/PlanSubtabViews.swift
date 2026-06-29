import SwiftUI

// MARK: - Sub-tab bodies (My Plans / Programs / Workouts / Exercises)
// Mirrors MyPlansView, ProgramsView, WorkoutsView, ExercisesView in plan/app.jsx.

// MARK: My Plans — workouts in program

struct PlanMyPlansBody: View {
    let workouts: [PlanWorkout]
    var onEditWorkout: (PlanWorkout) -> Void
    var onAddWorkout: () -> Void
    var onDeleteWorkout: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                AuraSectionLabel(title: "Workouts in program").padding(.top, 0)
                Spacer()
                PlanIconButton(icon: "plus", size: 16, diameter: 28, accent: true, action: onAddWorkout)
            }
            .padding(.top, 16)
            .padding(.bottom, 10)

            VStack(spacing: 10) {
                ForEach(workouts) { w in
                    workoutCard(w)
                }
            }
        }
    }

    @ViewBuilder
    private func workoutCard(_ w: PlanWorkout) -> some View {
        let c = planWkStyle(w.name)
        let muscles = w.muscles.components(separatedBy: ", ").joined(separator: " · ")
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(c.bg)
                    .frame(width: 46, height: 46)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(c.border.opacity(0.35), lineWidth: 1.5))
                Image(systemName: planWkIcon(w.name))
                    .font(.system(size: 20)).foregroundColor(c.tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(w.name).font(.system(size: 15, weight: .heavy)).foregroundColor(.aura.text)
                Text(muscles).font(.system(size: 12, weight: .medium)).foregroundColor(c.tint)
            }
            Spacer()
            HStack(spacing: 5) {
                Button { onEditWorkout(w) } label: {
                    smallGlyph("pencil", color: .aura.text)
                }
                Button { onDeleteWorkout(w.id) } label: {
                    smallGlyph("trash", color: .aura.red)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
    }

    private func smallGlyph(_ icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(color)
            .frame(width: 30, height: 30)
            .background(Color.aura.fill.opacity(0.5))
            .clipShape(Circle())
    }
}

// MARK: My Plans — plan carousel

struct PlanCarousel: View {
    var onNew: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                planCard(title: "Push Pull Legs", sub: "6 days · Intermediate", active: true,
                         colors: [Color(hex: "#F59E0B"), Color(hex: "#C85A2C")], minW: 150)
                planCard(title: "Upper / Lower", sub: "4 days · Strength", active: false,
                         colors: [Color(hex: "#4A6FB5"), Color(hex: "#3D3A78")], minW: 130)
                planCard(title: "Full Body 3×", sub: "3 days · Beginner", active: false,
                         colors: [Color(hex: "#3E8C6E"), Color(hex: "#2E6359")], minW: 130)
                Button(action: onNew) {
                    VStack(spacing: 6) {
                        Image(systemName: "plus").font(.system(size: 22, weight: .medium))
                        Text("New").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.aura.text3)
                    .frame(width: 96, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: AuraRadius.lg)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                            .foregroundColor(.aura.separator)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
        }
    }

    private func planCard(title: String, sub: String, active: Bool, colors: [Color], minW: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 1) {
                if active {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                        Text("Active").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.aura.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                Spacer()
                Text(title).font(.system(size: 14, weight: .heavy)).foregroundColor(.white).lineLimit(2)
                Text(sub).font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
            }
            .padding(13)
        }
        .frame(width: minW, height: 120)
    }
}

// MARK: Programs library

struct PlanProgramsBody: View {
    var onProgram: (PlanProgram) -> Void

    @State private var query = ""
    @State private var openFilter: ProgFilter.ID?
    @State private var freq: String?
    @State private var equip: String?
    @State private var level: String?
    @State private var split: String?
    @State private var type: String?

    struct ProgFilter: Identifiable { let id: String; let label: String; let opts: [String] }

    private var filterDefs: [ProgFilter] {
        [
            ProgFilter(id: "freq",  label: "Frequency", opts: ["2 days/wk","3 days/wk","4 days/wk","5 days/wk","6 days/wk"]),
            ProgFilter(id: "equip", label: "Equipment", opts: ["Full Gym","Barbell Only","Dumbbell","Bodyweight","Home"]),
            ProgFilter(id: "level", label: "Level",     opts: ["Beginner","Intermediate","Advanced"]),
            ProgFilter(id: "split", label: "Split",     opts: ["Body Part","Full Body","Push/Pull/Legs","Upper/Lower"]),
            ProgFilter(id: "type",  label: "Type",      opts: ["Strength","Hypertrophy","Mobility","Powerlifting"]),
        ]
    }

    private func value(_ id: String) -> String? {
        switch id { case "freq": return freq; case "equip": return equip; case "level": return level
        case "split": return split; case "type": return type; default: return nil }
    }
    private func setValue(_ id: String, _ v: String?) {
        switch id { case "freq": freq = v; case "equip": equip = v; case "level": level = v
        case "split": split = v; case "type": type = v; default: break }
    }

    /// `PROG_META` keyed by program id (everything except Level).
    private let progMeta: [String: (freq: String, equip: String, split: String, type: String)] = [
        "ppl":  ("6 days/wk", "Full Gym", "Push/Pull/Legs", "Hypertrophy"),
        "ul":   ("4 days/wk", "Full Gym", "Upper/Lower",    "Strength"),
        "phul": ("4 days/wk", "Full Gym", "Upper/Lower",    "Strength"),
        "fb3":  ("3 days/wk", "Full Gym", "Full Body",      "Strength"),
        "bro":  ("5 days/wk", "Full Gym", "Body Part",      "Hypertrophy"),
    ]

    private var filtered: [PlanProgram] {
        PlanData.programs.filter { p in
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            let mq = q.isEmpty || p.name.lowercased().contains(q) || p.tag.lowercased().contains(q) || p.level.lowercased().contains(q)
            let m = progMeta[p.id]
            return mq
                && (freq == nil || m?.freq == freq)
                && (equip == nil || m?.equip == equip)
                && (level == nil || p.level == level)
                && (split == nil || m?.split == split)
                && (type == nil || m?.type == type)
        }
    }

    private var activeCount: Int { [freq, equip, level, split, type].compactMap { $0 }.count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                PlanSearchField(placeholder: "Search programs", text: $query)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        if activeCount > 0 {
                            Button {
                                freq = nil; equip = nil; level = nil; split = nil; type = nil
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                                    Text("Clear").font(.system(size: 12, weight: .bold))
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

            ScrollView(showsIndicators: false) {
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
                Color.clear.frame(height: AuraSpacing.tabBarClearance)
            }
        }
        .sheet(item: Binding(get: { openFilter.map { IdString($0) } }, set: { openFilter = $0?.value })) { wrapped in
            filterSheet(wrapped.value)
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
        }
    }

    private func programCard(_ p: PlanProgram) -> some View {
        let freqLabel = progMeta[p.id]?.freq ?? "\(p.days) days/wk"
        return PlanLibraryCard(
            title: p.name,
            meta: AnyView(
                HStack(spacing: 6) {
                    Text(freqLabel); dot(); Text(p.level); dot(); Text(p.tag)
                }
                .font(.system(size: 13))
                .foregroundColor(.aura.text2)
            ),
            trailing: {
                if p.active {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                        Text("Added").font(AuraFont.badge())
                    }
                    .foregroundColor(.aura.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.aura.accentSoft)
                    .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.aura.text3)
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
                                .font(.system(size: 16, weight: isSel ? .bold : .medium))
                                .foregroundColor(isSel ? .aura.accent : .aura.text)
                            Spacer()
                            if isSel {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20)).foregroundColor(.aura.accent)
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
    var onEdit: (PlanWorkout) -> Void

    @State private var query = ""
    @State private var filter = "All"
    private let filters = ["All", "Push", "Pull", "Legs", "Upper", "Chest", "Back"]

    private var filtered: [PlanWorkout] {
        PlanData.workouts.filter { w in
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            let mq = q.isEmpty || w.name.lowercased().contains(q) || w.muscles.lowercased().contains(q)
            let mf = filter == "All" || w.name.lowercased().contains(filter.lowercased()) || w.muscles.lowercased().contains(filter.lowercased())
            return mq && mf
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
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
                                title: w.name,
                                meta: AnyView(
                                    Text("\(w.exCount) exercises · \(w.muscles)")
                                        .font(.system(size: 13)).foregroundColor(.aura.text2)
                                ),
                                trailing: {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.aura.text3)
                                },
                                action: { onEdit(w) }
                            )
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 14)
            Color.clear.frame(height: AuraSpacing.tabBarClearance)
        }
    }
}

// MARK: Exercises library

struct PlanExercisesBody: View {
    var onExercise: (PlanLibExercise) -> Void

    @State private var query = ""
    @State private var muscleFilter = "All"
    @State private var equipFilter = "All"
    private let muscles = ["All", "Chest", "Back", "Shoulders", "Arms", "Legs", "Core"]
    private let equips = ["All", "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Smith"]

    private var filtered: [PlanLibExercise] {
        PlanData.exercises.filter { e in
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            let mq = q.isEmpty || e.name.lowercased().contains(q) || e.muscle.lowercased().contains(q) || e.equip.lowercased().contains(q)
            let mm = muscleFilter == "All"
                || (muscleFilter == "Arms" ? (e.muscle == "Biceps" || e.muscle == "Triceps") : e.muscle == muscleFilter)
            let me = equipFilter == "All" || e.equip == equipFilter
            return mq && mm && me
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
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
                            PlanFilterChip(label: eq, active: equipFilter == eq) { equipFilter = eq }
                        }
                    }
                }
                .padding(.bottom, 10)

                if filtered.isEmpty {
                    PlanEmptyState(title: "No exercises found", subtitle: "Try a different filter")
                } else {
                    PlanCatalogGrid(exercises: filtered, onTap: onExercise)
                }
            }
            .padding(.horizontal, 14)
            Color.clear.frame(height: AuraSpacing.tabBarClearance)
        }
    }
}
