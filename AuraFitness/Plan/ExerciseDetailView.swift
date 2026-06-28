import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) var dismiss
    @State private var showAddToWorkout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                    // Video placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: AuraRadius.lg)
                            .fill(Color.aura.surface)
                            .frame(height: 200)
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "play.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 22))
                            }
                            Text("Exercise Demo")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text3)
                        }
                    }

                    // Name
                    Text(exercise.name)
                        .font(AuraFont.cardTitle())
                        .foregroundColor(.aura.text)

                    // Category strip
                    HStack(spacing: 0) {
                        infoCell(label: exercise.equipment, icon: "dumbbell")
                        Divider()
                        infoCell(label: exercise.primaryMuscle, icon: "figure.strengthtraining.traditional")
                        Divider()
                        infoCell(label: exercise.difficulty, icon: "star.fill")
                    }
                    .frame(height: 60)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))

                    // Pro tip
                    if !exercise.hint.isEmpty {
                        AuraCard {
                            HStack(alignment: .top, spacing: AuraSpacing.s3) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.aura.accent)
                                    .font(.system(size: 16))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Pro Tip")
                                        .font(AuraFont.sectionLabel())
                                        .foregroundColor(.aura.text3)
                                    Text(exercise.hint)
                                        .font(AuraFont.secondary())
                                        .foregroundColor(.aura.text2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(AuraSpacing.s4)
                        }
                    }

                    // Muscle activation placeholder
                    AuraCard {
                        VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                            Text("Muscle Activation")
                                .sectionLabelStyle()
                            ForEach(exercise.muscleGroups, id: \.self) { group in
                                HStack {
                                    Text(group)
                                        .font(AuraFont.secondary())
                                        .foregroundColor(.aura.text)
                                        .frame(width: 100, alignment: .leading)
                                    AuraProgressBar(value: group == exercise.primaryMuscle ? 1.0 : 0.5)
                                }
                            }
                        }
                        .padding(AuraSpacing.s4)
                    }

                    // Actions
                    AuraPrimaryButton(label: "Add to Today's Workout", icon: "plus") {
                        showAddToWorkout = true
                    }
                    AuraTintedButton(label: "Add to a Plan") {
                        showAddToWorkout = true
                    }
                }
                .padding(AuraSpacing.screenPad)
                .padding(.bottom, 40)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func infoCell(label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.aura.text2)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}
