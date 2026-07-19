import SwiftUI

struct ExerciseLibraryTabView: View {
    @StateObject private var db = ExerciseDatabase.shared
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var selectedEquipment = "All"
    @State private var selectedEntry: ExerciseEntry? = nil
    @State private var showCreate = false

    private let categories = ["All","Chest","Back","Shoulders","Arms","Legs","Core","Cardio","Warm-up"]
    private let equipmentOptions = ["All","Barbell","Dumbbell","Cable","Machine","Smith Machine","Bodyweight"]

    var filtered: [ExerciseEntry] {
        db.filtered(
            category: selectedCategory == "All" ? nil : selectedCategory,
            equipment: selectedEquipment == "All" ? nil : selectedEquipment,
            query: searchText
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AuraSpacing.s2) {
                Image(systemName: "magnifyingglass").foregroundColor(.aura.text3)
                TextField("Search exercises", text: $searchText).font(AuraFont.body())
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.aura.text3)
                    }
                }
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(categories, id: \.self) { m in
                        AuraChip(label: m, active: selectedCategory == m) { selectedCategory = m }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s2)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(equipmentOptions, id: \.self) { e in
                        AuraChip(label: e, active: selectedEquipment == e) { selectedEquipment = e }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s1)
                .padding(.bottom, AuraSpacing.s2)
            }

            Text("\(filtered.count) exercises")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.bottom, AuraSpacing.s1)

            Divider()

            AuraScreenScroll {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AuraSpacing.s3) {
                    ForEach(filtered) { entry in
                        Button { selectedEntry = entry } label: { exerciseCell(entry) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(AuraSpacing.screenPad)
            }
        }
        .background(Color.aura.bgGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showCreate = true } label: {
                    Image(systemName: "plus")
                }
                .foregroundColor(.aura.accent)
            }
        }
        .sheet(item: $selectedEntry) { entry in
            ExerciseEntryDetailView(entry: entry)
        }
        .sheet(isPresented: $showCreate) {
            CreateExerciseView()
        }
    }

    @ViewBuilder
    private func exerciseCell(_ entry: ExerciseEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: AuraRadius.sm)
                    .fill(categoryColor(entry.category).opacity(0.15))
                    .frame(height: 80)
                VStack(spacing: 4) {
                    Text(entry.category.prefix(2).uppercased())
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(categoryColor(entry.category).opacity(0.5))
                    if entry.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.aura.red.opacity(0.7))
                    }
                }
            }

            Text(entry.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.aura.text)
                .lineLimit(2)

            Text("\(entry.category) · \(entry.equipment)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.aura.text2)

            if entry.isCustom {
                AuraBadge(label: "Custom", color: .aura.purple)
            }
        }
        .padding(AuraSpacing.s3)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
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
