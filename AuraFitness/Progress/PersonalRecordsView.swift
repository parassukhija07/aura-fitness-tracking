import SwiftUI

struct PersonalRecordsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedMuscle = "All"

    let muscles = ["All","Chest","Back","Shoulders","Arms","Legs","Core"]

    /// Current best per exercise — `personalRecords` is an append-only log,
    /// so group down to the top e1RM entry per exercise for display.
    var filtered: [PersonalRecord] {
        let bestByExercise = Dictionary(grouping: appState.personalRecords, by: { $0.exerciseName.lowercased() })
            .compactMap { _, records in records.max { a, b in (a.estimated1RM, a.weight) < (b.estimated1RM, b.weight) } }
        let all = bestByExercise.sorted { $0.estimated1RM > $1.estimated1RM }
        if selectedMuscle == "All" { return all }
        return all.filter { $0.muscle.localizedCaseInsensitiveContains(selectedMuscle) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AuraSpacing.s2) {
                    ForEach(muscles, id: \.self) { m in
                        AuraChip(label: m, active: selectedMuscle == m) { selectedMuscle = m }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.vertical, AuraSpacing.s2)
            }
            Divider()

            if filtered.isEmpty {
                Spacer()
                VStack(spacing: AuraSpacing.s3) {
                    Image(systemName: "trophy")
                        .font(.system(size: 44))
                        .foregroundColor(.aura.text3)
                    Text("No personal records yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.aura.text2)
                    Text("Complete workouts to set your first PRs automatically.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: AuraSpacing.s3) {
                        AuraCard {
                            VStack(spacing: 0) {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, pr in
                                    prRow(pr, isTop: idx == 0)
                                    if idx < filtered.count - 1 {
                                        Divider().padding(.leading, 56)
                                    }
                                }
                            }
                        }

                        // Info hint
                        HStack(alignment: .top, spacing: AuraSpacing.s2) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 15))
                                .foregroundColor(.aura.text3)
                                .padding(.top, 1)
                            Text("New PRs are detected automatically while you log and celebrated mid-workout.")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(AuraSpacing.s3)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md)
                            .stroke(Color.aura.separator2, lineWidth: 1))

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.top, AuraSpacing.s3)
                }
            }
        }
        .background(Color.aura.bgGrouped)
        .navigationTitle("Personal Records")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func prRow(_ pr: PersonalRecord, isTop: Bool) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isTop ? Color.aura.accent : Color.aura.fill)
                    .frame(width: 36, height: 36)
                Image(systemName: isTop ? "trophy.fill" : "medal.fill")
                    .foregroundColor(isTop ? .white : .aura.text2)
                    .font(.system(size: 16))
            }

            // Name + date
            VStack(alignment: .leading, spacing: 2) {
                Text(pr.exerciseName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.aura.text)
                Text("Set \(pr.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
                if isTop {
                    Text("1RM est. \(UnitFormatter.weight(pr.estimated1RM, unit: appState.weightUnit))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.aura.accent)
                }
            }

            Spacer()

            // Weight × reps
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(UnitFormatter.weightNumber(pr.weight, unit: appState.weightUnit))
                        .font(AuraFont.statNum(size: 18))
                        .foregroundColor(.aura.text)
                    Text("×\(pr.reps)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.aura.text2)
                }
                if !isTop {
                    Text("1RM ≈ \(UnitFormatter.weight(pr.estimated1RM, unit: appState.weightUnit))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.aura.text3)
                }
            }
        }
        .padding(.horizontal, AuraSpacing.s4)
        .padding(.vertical, 13)
        .background(isTop ? Color.aura.accentSoft : Color.clear)
    }

    private func formatW(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}
