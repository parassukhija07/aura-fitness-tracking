import SwiftUI

struct PlannedWorkoutCardView: View {
    @EnvironmentObject var appState: AppState
    let workout: Workout
    @Binding var showSwitch: Bool
    @Binding var showLogPast: Bool
    let onStart: () -> Void

    private let maxPreview = 5

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            // Program badge
            if let plan = appState.defaultPlan {
                HStack(spacing: 6) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 12))
                    Text(plan.name)
                        .font(AuraFont.secondary())
                }
                .foregroundColor(.aura.text2)
                .padding(.horizontal, AuraSpacing.screenPad)
            }

            // Workout card
            AuraCard {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.name)
                            .font(AuraFont.cardTitle())
                            .foregroundColor(.aura.text)

                        HStack(spacing: AuraSpacing.s2) {
                            Label("\(workout.exercises.count) exercises", systemImage: "list.bullet")
                            Label("~\(workout.estimatedMinutes) min", systemImage: "clock")
                            Label(workout.primaryMuscles, systemImage: "figure.strengthtraining.traditional")
                        }
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                    }

                    Divider()

                    // Exercise list
                    VStack(spacing: 6) {
                        ForEach(Array(workout.exercises.prefix(maxPreview).enumerated()), id: \.offset) { i, ex in
                            HStack(spacing: AuraSpacing.s2) {
                                Text("\(i + 1)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.aura.text3)
                                    .frame(width: 18)
                                Text(ex.name)
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text)
                                Spacer()
                                Text("\(ex.plannedSets) × \(ex.repRange)")
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                            }
                        }
                        if workout.exercises.count > maxPreview {
                            Text("+\(workout.exercises.count - maxPreview) more")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                                .padding(.top, 2)
                        }
                    }

                    // Start button
                    AuraPrimaryButton(label: "Start Workout", icon: "bolt.fill") {
                        onStart()
                    }

                    // Secondary actions
                    HStack(spacing: AuraSpacing.s3) {
                        AuraGrayButton(label: "Log Past") {
                            showLogPast = true
                        }
                        AuraGrayButton(label: "Switch") {
                            showSwitch = true
                        }
                    }
                }
                .padding(AuraSpacing.s4)
            }
            .padding(.horizontal, AuraSpacing.screenPad)
        }
    }
}
