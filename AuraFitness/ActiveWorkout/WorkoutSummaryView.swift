import SwiftUI

struct WorkoutSummaryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: WorkoutSessionState

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Gradient hero
                ZStack {
                    LinearGradient(
                        colors: [Color.aura.accent.opacity(0.9), Color.aura.accent.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 220)

                    VStack(spacing: 8) {
                        Text("🔥")
                            .font(AuraFont.jakarta(48))
                        Text("Workout Complete")
                            .font(AuraFont.jakarta(26, .heavy))
                            .foregroundColor(.white)
                        Text("\(session.workout.name)")
                            .font(AuraFont.secondary())
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: AuraSpacing.s4) {
                    // Stats grid
                    AuraCard {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                             GridItem(.flexible()), GridItem(.flexible())], spacing: 0) {
                            statCell(value: session.elapsedFormatted, label: "Duration")
                            statCell(value: "\(session.doneSets)", label: "Sets")
                            statCell(value: "\(Int(session.totalVolume).formatted())", label: "Volume (kg)")
                            statCell(value: "\(session.newPRsCount)", label: "New PRs")
                        }
                        .padding(.vertical, AuraSpacing.s3)
                    }
                    .padding(.top, -26)

                    // PR banner
                    if session.newPRsCount > 0 {
                        HStack(spacing: AuraSpacing.s3) {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.aura.accent)
                                .font(AuraFont.jakarta(18))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(session.newPRsCount) new personal record\(session.newPRsCount > 1 ? "s" : "")!")
                                    .font(AuraFont.jakarta(14, .bold))
                                    .foregroundColor(.aura.text)
                                Text("Logged to your Progress tab.")
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                            }
                        }
                        .padding(AuraSpacing.s3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.aura.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AuraRadius.md)
                                .stroke(Color.aura.accent.opacity(0.4), lineWidth: 1)
                        )
                    }

                    // Exercises recap
                    AuraSectionLabel(title: "Exercises")

                    AuraCard {
                        VStack(spacing: 0) {
                            ForEach(Array(session.workout.exercises.enumerated()), id: \.element.id) { i, ex in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ex.name)
                                            .font(AuraFont.jakarta(15, .semibold))
                                            .foregroundColor(.aura.text)
                                        let d = ex.sets.filter { $0.done }.count
                                        let vol = ex.sets.filter { $0.done }.reduce(0.0) { $0 + ($1.weight ?? 0) * Double($1.reps ?? 0) }
                                        Text("\(d) sets · \(UnitFormatter.weight(vol, unit: appState.weightUnit))")
                                            .font(AuraFont.secondary())
                                            .foregroundColor(.aura.text2)
                                    }
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.aura.green)
                                        .font(AuraFont.jakarta(20))
                                }
                                .padding(.horizontal, AuraSpacing.s4)
                                .padding(.vertical, 12)
                                if i < session.workout.exercises.count - 1 {
                                    Divider().padding(.leading, AuraSpacing.s4)
                                }
                            }
                        }
                    }

                    // Session notes
                    AuraSectionLabel(title: "Session Notes")

                    TextField("How did it feel? Anything to remember for next time…",
                              text: $session.sessionNotes,
                              axis: .vertical)
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text)
                        .lineLimit(4, reservesSpace: true)
                        .padding(AuraSpacing.s3)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))

                    // Actions
                    AuraPrimaryButton(label: "Save Workout", icon: "checkmark") {
                        appState.saveWorkout(session)
                    }
                    AuraGrayButton(label: "Back to Workout") {
                        session.activeView = .overview
                    }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.bottom, 40)
            }
        }
        .background(Color.aura.bg)
        .ignoresSafeArea(edges: .top)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AuraFont.statNum(size: 22))
                .foregroundColor(.aura.text)
                .monospacedDigit()
            Text(label)
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AuraSpacing.s2)
    }
}
