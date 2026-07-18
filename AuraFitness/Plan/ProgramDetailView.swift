import SwiftUI

struct ProgramDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var planDB = UserPlanDatabase.shared
    let program: Program
    @Environment(\.dismiss) var dismiss

    var isAdded: Bool { planDB.plans.contains { $0.sourceProgramID == program.id } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                    // Hero placeholder
                    ZStack {
                        LinearGradient(
                            colors: [.aura.accent.opacity(0.7), .aura.accent.opacity(0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xl))

                        VStack(spacing: 8) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                            Text(program.name)
                                .font(AuraFont.cardTitle())
                                .foregroundColor(.white)
                        }
                    }

                    // Meta chips
                    HStack(spacing: AuraSpacing.s2) {
                        AuraBadge(label: "\(program.daysPerWeek) days/week", color: .aura.accent)
                        AuraBadge(label: program.level, color: .aura.blue)
                        AuraBadge(label: program.style, color: .aura.purple)
                    }

                    // Description
                    Text(program.description)
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text2)

                    // Info note
                    HStack(alignment: .top, spacing: AuraSpacing.s2) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.aura.blue)
                            .font(.system(size: 14))
                        Text("Predefined programs must be added to My Plans before editing.")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                    .padding(AuraSpacing.s3)
                    .background(Color.aura.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))

                    // Workouts list
                    AuraSectionLabel(title: "Workouts")

                    ForEach(Array(program.workouts.enumerated()), id: \.element.id) { i, workout in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Day \(i + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.aura.text3)
                                Spacer()
                                Text("~\(workout.estimatedMinutes) min")
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                            }
                            Text(workout.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.aura.text)
                            Text(workout.exercises.prefix(3).map { $0.name }.joined(separator: " · "))
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                                .lineLimit(1)
                        }
                        .padding(AuraSpacing.s3)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    }

                    // Add button
                    if isAdded {
                        AuraGrayButton(label: "Already in My Plans") {}
                    } else {
                        AuraPrimaryButton(label: "Add to My Plans", icon: "plus") {
                            addToMyPlans()
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.bottom, 40)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle(program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func addToMyPlans() {
        planDB.addPlan(from: program, startDay: appState.calendarStartDay)
    }
}
