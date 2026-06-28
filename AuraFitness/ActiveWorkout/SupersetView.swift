import SwiftUI

struct SupersetView: View {
    @EnvironmentObject var session: WorkoutSessionState
    let supersetIndex: Int
    @State private var showMenu = false

    var exA: Exercise? {
        session.workout.exercises.indices.contains(supersetIndex)
            ? session.workout.exercises[supersetIndex] : nil
    }
    var exB: Exercise? {
        session.workout.exercises.indices.contains(supersetIndex + 1)
            ? session.workout.exercises[supersetIndex + 1] : nil
    }

    var body: some View {
        guard let a = exA, let b = exB else {
            return AnyView(Text("Superset not found"))
        }
        return AnyView(content(exA: a, exB: b))
    }

    @ViewBuilder
    private func content(exA: Exercise, exB: Exercise) -> some View {
        VStack(spacing: 0) {
            // Nav
            HStack {
                Button {
                    session.activeView = .overview
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(AuraFont.body())
                    .foregroundColor(.aura.accent)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.aura.accent)
                        .font(.system(size: 13))
                    Text("Superset")
                        .font(AuraFont.navTitle())
                        .foregroundColor(.aura.text)
                }
                Spacer()
                Button { showMenu = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.aura.text)
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { Divider() }

            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    // Exercise A
                    supersetBlock(exercise: exA, label: "A", color: .aura.accent, exerciseIndex: supersetIndex)

                    // Connector
                    HStack {
                        Rectangle().fill(Color.aura.accentSoft).frame(height: 2)
                        Text("⚡ REST BETWEEN")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.aura.accent)
                            .padding(.horizontal, 8)
                        Rectangle().fill(Color.aura.accentSoft).frame(height: 2)
                    }

                    // Exercise B
                    supersetBlock(exercise: exB, label: "B", color: .aura.blue, exerciseIndex: supersetIndex + 1)

                    // Actions
                    HStack(spacing: AuraSpacing.s3) {
                        AuraTintedButton(label: "Add Round") {
                            session.workout.exercises[supersetIndex].sets.append(WorkoutSet())
                            session.workout.exercises[supersetIndex + 1].sets.append(WorkoutSet())
                        }
                        AuraPrimaryButton(label: "Complete Superset") {
                            completeSuperset()
                        }
                    }
                    .padding(.bottom, 100)
                }
                .padding(AuraSpacing.screenPad)
            }
        }
        .background(Color.aura.bg)
        .sheet(isPresented: $showMenu) {
            ExerciseMenuSheet(exerciseIndex: supersetIndex)
                .environmentObject(session)
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func supersetBlock(exercise: Exercise, label: String, color: Color, exerciseIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s3) {
            HStack(spacing: AuraSpacing.s2) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: 24, height: 24)
                    Text(label)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                }
                Text(exercise.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.aura.text)
                Spacer()
                Text("\(exercise.doneSetsCount)/\(exercise.sets.count)")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
            }

            AuraProgressBar(value: exercise.sets.isEmpty ? 0 : Double(exercise.doneSetsCount) / Double(exercise.sets.count))

            // Sets header
            HStack {
                Text("Set")
                    .font(AuraFont.secondary()).foregroundColor(.aura.text3)
                    .frame(width: 32)
                Text("kg")
                    .font(AuraFont.secondary()).foregroundColor(.aura.text3)
                    .frame(maxWidth: .infinity)
                Text("Reps")
                    .font(AuraFont.secondary()).foregroundColor(.aura.text3)
                    .frame(maxWidth: .infinity)
                Image(systemName: "checkmark")
                    .font(.system(size: 12))
                    .foregroundColor(.aura.text3)
                    .frame(width: 34)
            }
            .padding(.horizontal, AuraSpacing.s3)

            ForEach(session.workout.exercises[exerciseIndex].sets.indices, id: \.self) { si in
                SetRowView(
                    exerciseIndex: exerciseIndex,
                    setIndex: si,
                    set: Binding(
                        get: { session.workout.exercises[exerciseIndex].sets[si] },
                        set: { session.workout.exercises[exerciseIndex].sets[si] = $0 }
                    )
                )
            }
        }
        .padding(AuraSpacing.s4)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    private func completeSuperset() {
        for idx in [supersetIndex, supersetIndex + 1] {
            guard session.workout.exercises.indices.contains(idx) else { continue }
            session.workout.exercises[idx].sets.removeAll { s in
                s.weight == nil && s.reps == nil && !s.done
            }
            for i in session.workout.exercises[idx].sets.indices {
                let s = session.workout.exercises[idx].sets[i]
                if s.weight != nil && s.reps != nil {
                    session.workout.exercises[idx].sets[i].done = true
                }
            }
            session.workout.exercises[idx].completed = true
        }
        session.triggerCelebration(emoji: "💪", title: "Superset done",
            message: "Both exercises logged. Keep going.")
        session.startRest(duration: 60)
        session.activeView = .overview
    }
}
