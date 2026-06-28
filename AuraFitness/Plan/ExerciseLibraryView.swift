import SwiftUI

struct ExerciseLibraryTabView: View {
    @State private var searchText = ""
    @State private var selectedMuscle = "All"
    @State private var selectedEquipment = "All"
    @State private var selectedExercise: Exercise? = nil
    @State private var showCreate = false

    let muscles = ["All","Chest","Back","Shoulders","Arms","Legs","Core","Cardio"]
    let equipment = ["All","Cable","Barbell","Dumbbell","Smith","Machine","Bodyweight"]

    var filtered: [Exercise] {
        ExerciseLibrary.all.filter { ex in
            (searchText.isEmpty || ex.name.localizedCaseInsensitiveContains(searchText))
            && (selectedMuscle == "All" || ex.primaryMuscle.localizedCaseInsensitiveContains(selectedMuscle) || ex.muscleGroups.contains(selectedMuscle))
            && (selectedEquipment == "All" || ex.equipment == selectedEquipment)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AuraSpacing.s2) {
                Image(systemName: "magnifyingglass").foregroundColor(.aura.text3)
                TextField("Search exercises", text: $searchText).font(AuraFont.body())
            }
            .padding(AuraSpacing.s3)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s2)

            // Muscle filter row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(muscles, id: \.self) { m in
                        AuraChip(label: m, active: selectedMuscle == m) { selectedMuscle = m }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s2)
            }

            // Equipment filter row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(equipment, id: \.self) { e in
                        AuraChip(label: e, active: selectedEquipment == e) { selectedEquipment = e }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s1)
                .padding(.bottom, AuraSpacing.s2)
            }

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AuraSpacing.s3) {
                    ForEach(filtered) { ex in
                        Button { selectedExercise = ex } label: { exerciseCell(ex) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(AuraSpacing.screenPad)
            }
        }
        .background(Color.aura.bgGrouped)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                }
                .foregroundColor(.aura.accent)
            }
        }
        .sheet(item: $selectedExercise) { ex in
            ExerciseDetailView(exercise: ex)
        }
        .sheet(isPresented: $showCreate) {
            CreateExerciseView()
        }
    }

    @ViewBuilder
    private func exerciseCell(_ ex: Exercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Placeholder image
            ZStack {
                RoundedRectangle(cornerRadius: AuraRadius.sm)
                    .fill(muscleColor(ex.primaryMuscle).opacity(0.15))
                    .frame(height: 80)
                Text(ex.primaryMuscle.prefix(2).uppercased())
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(muscleColor(ex.primaryMuscle).opacity(0.5))
            }

            Text(ex.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.aura.text)
                .lineLimit(2)

            Text("\(ex.primaryMuscle) · \(ex.equipment)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.aura.text2)
        }
        .padding(AuraSpacing.s3)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
    }

    private func muscleColor(_ muscle: String) -> Color {
        let m = muscle.lowercased()
        if m.contains("chest") { return .aura.accent }
        if m.contains("back") || m.contains("bicep") { return .aura.blue }
        if m.contains("shoulder") || m.contains("delt") { return .aura.purple }
        if m.contains("tricep") { return .aura.green }
        if m.contains("leg") || m.contains("glute") || m.contains("quad") || m.contains("hamstring") { return .aura.red }
        return .aura.text2
    }
}
