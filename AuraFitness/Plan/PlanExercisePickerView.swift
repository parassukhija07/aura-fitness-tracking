import SwiftUI

// MARK: - Exercise Picker (full-screen search + catalog to add / substitute)
// Mirrors ExercisePicker in plan/app.jsx. Three modes drive the select behaviour.

enum PickerMode { case sub, add, ssNew }

struct PlanExercisePickerView: View {
    var mode: PickerMode
    var replacingName: String? = nil
    var titleOverride: String? = nil
    var onSelect: (PlanLibExercise) -> Void
    var onBack: () -> Void

    @State private var query = ""
    @State private var muscleFilter = "All"
    @State private var equipFilter = "All"
    private let muscles = ["All", "Chest", "Back", "Shoulders", "Arms", "Legs", "Core"]
    private let equips = ["All", "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Smith"]

    private var title: String {
        if let titleOverride { return titleOverride }
        switch mode {
        case .ssNew: return "Pick Exercise B"
        case .sub: return "Substitute"
        case .add: return "Add Exercise"
        }
    }

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
        VStack(spacing: 0) {
            PlanNavbar(title: title, backLabel: "Back", onBack: onBack)

            VStack(spacing: 0) {
                if mode == .sub, let replacingName {
                    (Text("Replacing ").foregroundColor(.aura.text2)
                        + Text(replacingName).foregroundColor(.aura.text).bold())
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 7)
                }
                PlanSearchField(placeholder: "Search exercises…", text: $query)
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 8)

            VStack(spacing: 4) {
                chipRow(muscles, selected: muscleFilter, colored: true) { muscleFilter = $0 }
                chipRow(equips, selected: equipFilter, colored: false) { equipFilter = $0 }
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.aura.separator2).frame(height: 1) }

            ScrollView(showsIndicators: false) {
                if filtered.isEmpty {
                    PlanEmptyState(title: "No exercises found", subtitle: "Try a different filter or search term")
                } else {
                    PlanCatalogGrid(exercises: filtered, onTap: onSelect)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                }
                Color.clear.frame(height: 28)
            }
        }
        .background(Color.aura.bg)
    }

    @ViewBuilder
    private func chipRow(_ items: [String], selected: String, colored: Bool, set: @escaping (String) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    PlanFilterChip(label: item, active: selected == item,
                                   palette: colored ? PlanMusclePalette.chip(item) : nil) { set(item) }
                }
            }
            .padding(.horizontal, 14)
        }
    }
}
