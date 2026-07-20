import SwiftUI

// MARK: - Editor exercise picker
//
// Sheet-presented catalog picker for the workout editor. Search + muscle +
// equipment filters over the 2-column library grid, reusing the exact grid and
// filter-chip components from the Exercises library (`PlanCatalogGrid`,
// `PlanFilterChip`, `PlanSearchField`, `PlanEmptyState` / `PlanMusclePalette`)
// so the two grids read identically. Header copy varies by mode; the caller
// (the editor) owns the indices and the `ExerciseEntry → Exercise` conversion.

/// Display variant only — the editor holds the target indices.
enum EditorPickerMode {
    case substitute(replacingName: String)
    case addAfter
    case supersetNew
}

struct EditorExercisePicker: View {
    let mode: EditorPickerMode
    let onPick: (ExerciseEntry) -> Void

    @StateObject private var db = ExerciseDatabase.shared
    @State private var search = ""
    @State private var muscle: String?     // nil == "All"
    @State private var equip: String?      // nil == "All"
    @Environment(\.dismiss) private var dismiss

    // Mirror the Exercises library's filter rows exactly.
    private let muscles = ["All", "Chest", "Back", "Shoulders", "Arms", "Legs", "Core"]
    private let equips = ["All", "Barbell", "Dumbbell", "Cable", "Machine", "Bodyweight", "Smith Machine"]

    private var title: String {
        switch mode {
        case .substitute: return "Substitute"
        case .addAfter:   return "Add Exercise"
        case .supersetNew: return "Pick Exercise B"
        }
    }

    private var subtitle: String? {
        if case .substitute(let name) = mode { return "Replacing \(name)" }
        return nil
    }

    /// Search + muscle + equipment combined. "Arms" matches Biceps/Triceps via
    /// `PlanMusclePalette.displayLabel` (same rule as the library grid).
    private var filtered: [ExerciseEntry] {
        db.entries.filter { e in
            let q = search.trimmingCharacters(in: .whitespaces).lowercased()
            let mq = q.isEmpty || e.name.lowercased().contains(q)
                || e.category.lowercased().contains(q) || e.equipment.lowercased().contains(q)
            let mm = muscle == nil || PlanMusclePalette.displayLabel(e.category) == muscle!
            let me = equip == nil || e.equipment == equip!
            return mq && mm && me
        }
    }

    private var gridItems: [PlanLibExercise] {
        filtered.map {
            PlanLibExercise(id: $0.id.uuidString, name: $0.name,
                            muscle: $0.category, equip: $0.equipment)
        }
    }

    var body: some View {
        NavigationStack {
            AuraScreenScroll {
                VStack(alignment: .leading, spacing: 0) {
                    if let subtitle {
                        Text(subtitle)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                            .padding(.top, 4)
                    }

                    PlanSearchField(placeholder: "Search exercises", text: $search)
                        .padding(.top, 6).padding(.bottom, 6)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(muscles, id: \.self) { m in
                                PlanFilterChip(label: m, active: isActive(muscle, m),
                                               palette: PlanMusclePalette.chip(m)) {
                                    muscle = (m == "All") ? nil : m
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(equips, id: \.self) { eq in
                                PlanFilterChip(label: eq == "Smith Machine" ? "Smith" : eq,
                                               active: isActive(equip, eq)) {
                                    equip = (eq == "All") ? nil : eq
                                }
                            }
                        }
                    }
                    .padding(.bottom, 10)

                    if filtered.isEmpty {
                        PlanEmptyState(title: "No exercises found", subtitle: "Try a different filter")
                    } else {
                        PlanCatalogGrid(exercises: gridItems) { tapped in
                            if let entry = db.entries.first(where: { $0.id.uuidString == tapped.id }) {
                                onPick(entry)
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
            .background(Color.aura.bg.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    /// A filter row is "active" when its "All" pill matches a nil selection, or
    /// a named pill matches the current selection.
    private func isActive(_ selection: String?, _ option: String) -> Bool {
        option == "All" ? selection == nil : selection == option
    }
}
