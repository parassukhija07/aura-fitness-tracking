import SwiftUI

struct PersonalRecordsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedMuscle = "All"

    let muscles = ["All","Chest","Back","Shoulders","Arms","Legs","Core"]

    var filtered: [PersonalRecord] {
        if selectedMuscle == "All" { return appState.personalRecords }
        return appState.personalRecords.filter { $0.muscle.localizedCaseInsensitiveContains(selectedMuscle) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(muscles, id: \.self) { m in
                        AuraChip(label: m, active: selectedMuscle == m) { selectedMuscle = m }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.vertical, AuraSpacing.s2)
            }

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: AuraSpacing.s3) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundColor(.aura.text3)
                    Text("No personal records yet")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text2)
                    Text("Complete workouts to set your first PRs!")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text3)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                List(filtered.sorted { $0.date > $1.date }) { pr in
                    prRow(pr)
                        .listRowBackground(Color.aura.surface)
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color.aura.bgGrouped)
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func prRow(_ pr: PersonalRecord) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.aura.accent.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: "trophy.fill")
                    .foregroundColor(.aura.accent)
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.aura.text)
                Text(pr.date.formatted(date: .abbreviated, time: .omitted))
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", pr.weight)) kg × \(pr.reps)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.aura.text)
                Text("1RM ≈ \(Int(pr.estimated1RM)) kg")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.aura.text2)
            }
        }
    }
}
