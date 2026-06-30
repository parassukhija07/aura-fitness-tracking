import SwiftUI

struct ProgramLibraryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var programDB = ProgramDatabase.shared
    @StateObject private var planDB = UserPlanDatabase.shared
    @State private var searchText = ""
    @State private var selectedLevel = "All"
    @State private var selectedProgram: Program? = nil
    @State private var showCreateProgram = false
    @Environment(\.dismiss) var dismiss

    let levels = ["All","Beginner","Intermediate","Advanced","All Levels"]

    var filtered: [Program] {
        programDB.programs.filter { p in
            (searchText.isEmpty || p.name.localizedCaseInsensitiveContains(searchText))
            && (selectedLevel == "All" || p.level == selectedLevel)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: AuraSpacing.s2) {
                    Image(systemName: "magnifyingglass").foregroundColor(.aura.text3)
                    TextField("Search programs", text: $searchText).font(AuraFont.body())
                }
                .padding(AuraSpacing.s3)
                .background(Color.aura.fill)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.vertical, AuraSpacing.s2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AuraSpacing.s2) {
                        ForEach(levels, id: \.self) { level in
                            AuraChip(label: level, active: selectedLevel == level) {
                                selectedLevel = level
                            }
                        }
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.bottom, AuraSpacing.s2)
                }

                List(filtered) { program in
                    Button { selectedProgram = program } label: { programRow(program: program) }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.aura.surface)
                }
                .listStyle(.insetGrouped)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Program Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateProgram = true } label: {
                        Image(systemName: "plus")
                    }
                    .foregroundColor(.aura.accent)
                }
            }
            .sheet(item: $selectedProgram) { program in
                ProgramDetailView(program: program)
            }
            .sheet(isPresented: $showCreateProgram) {
                ProgramEditorView(mode: .create)
            }
        }
    }

    @ViewBuilder
    private func programRow(program: Program) -> some View {
        let isAdded = planDB.plans.contains { $0.sourceProgramID == program.id }
        HStack(spacing: AuraSpacing.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: AuraRadius.sm)
                    .fill(levelColor(program.level).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(levelColor(program.level))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(program.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.aura.text)
                    if isAdded { AuraBadge(label: "Added", color: .aura.green) }
                    if !program.isPredefined { AuraBadge(label: "Custom", color: .aura.purple) }
                }
                HStack(spacing: AuraSpacing.s2) {
                    Text("\(program.daysPerWeek) days/wk")
                    Text("·")
                    Text(program.level)
                    Text("·")
                    Text(program.style)
                }
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(.aura.text3)
        }
        .padding(.vertical, 4)
    }

    private func levelColor(_ level: String) -> Color {
        switch level {
        case "Beginner": return .aura.green
        case "Intermediate": return .aura.blue
        case "Advanced": return .aura.red
        default: return .aura.accent
        }
    }
}
