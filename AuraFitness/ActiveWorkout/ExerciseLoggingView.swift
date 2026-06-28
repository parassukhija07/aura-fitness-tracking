import SwiftUI

struct ExerciseLoggingView: View {
    @EnvironmentObject var session: WorkoutSessionState
    let exerciseIndex: Int
    @State private var showWarmup = false
    @State private var showMenu = false
    @State private var pulleySelection = "single"

    var exercise: Exercise? {
        session.workout.exercises.indices.contains(exerciseIndex)
            ? session.workout.exercises[exerciseIndex] : nil
    }

    var body: some View {
        guard let ex = exercise else {
            return AnyView(Text("Exercise not found").foregroundColor(.aura.text2))
        }
        return AnyView(content(ex: ex))
    }

    @ViewBuilder
    private func content(ex: Exercise) -> some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button {
                    session.activeView = .overview
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(AuraFont.body())
                    }
                    .foregroundColor(.aura.accent)
                }

                Spacer()

                Text("Exercise \(exerciseIndex + 1)")
                    .font(AuraFont.navTitle())
                    .foregroundColor(.aura.text)

                Spacer()

                Button {
                    showMenu = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.aura.text)
                        .padding(8)
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { Divider() }

            ScrollView {
                VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                    // Exercise name
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ex.name)
                            .font(AuraFont.cardTitle())
                            .foregroundColor(.aura.text)

                        HStack(spacing: AuraSpacing.s2) {
                            AuraBadge(label: ex.equipment, color: .aura.blue)
                            AuraBadge(label: ex.primaryMuscle, color: .aura.accent)
                            AuraBadge(label: ex.difficulty, color: .aura.text2)
                        }
                    }

                    // Cable pulley selector
                    if ex.isCable {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pulley")
                                .font(AuraFont.sectionLabel())
                                .foregroundColor(.aura.text3)
                            AuraSegmentedPicker(options: ["Single", "Double"],
                                               selection: Binding(
                                                get: { (session.workout.exercises[exerciseIndex].pulley == "double") ? "Double" : "Single" },
                                                set: { val in session.onPulleyChange(exerciseIndex: exerciseIndex, pulley: val.lowercased()) }
                                               ))
                        }
                    }

                    // PR + Target cards
                    HStack(spacing: AuraSpacing.s3) {
                        if let pr = ex.lastPR {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Last PR")
                                    .font(AuraFont.sectionLabel())
                                    .foregroundColor(.aura.text3)
                                Text("\(pr.weight, specifier: "%.1f") kg × \(pr.reps)")
                                    .font(AuraFont.statNum(size: 16))
                                    .foregroundColor(.aura.text)
                                Text(pr.date)
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AuraSpacing.s3)
                            .background(Color.aura.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        }

                        if let t = ex.target {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Today's Target")
                                    .font(AuraFont.sectionLabel())
                                    .foregroundColor(.aura.accent)
                                Text("\(t.weight, specifier: "%.1f") kg × \(t.reps)")
                                    .font(AuraFont.statNum(size: 16))
                                    .foregroundColor(.aura.accent)
                                Text(t.note)
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AuraSpacing.s3)
                            .background(Color.aura.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: AuraRadius.md)
                                    .stroke(Color.aura.accent.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }

                    // Warm-up
                    if !ex.warmup.isEmpty && exerciseIndex < 2 {
                        DisclosureGroup(
                            isExpanded: $showWarmup,
                            content: {
                                VStack(spacing: 6) {
                                    ForEach(Array(ex.warmup.enumerated()), id: \.offset) { i, ws in
                                        HStack {
                                            Text("W\(i + 1)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.aura.text3)
                                                .frame(width: 28)
                                            Text(ws.label)
                                                .font(AuraFont.secondary())
                                                .foregroundColor(.aura.text2)
                                            Spacer()
                                            Text("\(ws.reps) reps")
                                                .font(AuraFont.secondary())
                                                .foregroundColor(.aura.text2)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.top, 6)
                            },
                            label: {
                                HStack {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .foregroundColor(.aura.text2)
                                    Text("Warm-up Protocol")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.aura.text)
                                }
                            }
                        )
                        .padding(AuraSpacing.s3)
                        .background(Color.aura.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    }

                    // Form tip
                    if !ex.hint.isEmpty {
                        HStack(alignment: .top, spacing: AuraSpacing.s3) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.aura.accent)
                                .font(.system(size: 16))
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Form Tip")
                                    .font(AuraFont.sectionLabel())
                                    .foregroundColor(.aura.text3)
                                Text(ex.hint)
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(AuraSpacing.s3)
                        .background(Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    }

                    // Working sets header
                    HStack {
                        Text("Working Sets")
                            .font(AuraFont.sectionLabel())
                            .foregroundColor(.aura.text3)
                            .padding(.top, AuraSpacing.s2)
                        Spacer()
                        let done = ex.sets.filter { $0.done }.count
                        Text("\(done)/\(ex.sets.count)")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }

                    // Set rows
                    // Progress bar
                    if !ex.sets.isEmpty {
                        AuraProgressBar(value: Double(ex.doneSetsCount) / Double(ex.sets.count))
                    }

                    VStack(spacing: 4) {
                        ForEach(Array(session.workout.exercises[exerciseIndex].sets.indices), id: \.self) { si in
                            SetRowView(
                                exerciseIndex: exerciseIndex,
                                setIndex: si,
                                set: Binding(
                                    get: { session.workout.exercises[exerciseIndex].sets[si] },
                                    set: { session.workout.exercises[exerciseIndex].sets[si] = $0 }
                                )
                            )
                            if si < session.workout.exercises[exerciseIndex].sets.count - 1 {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))

                    // Exercise note
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Exercise Note")
                            .sectionLabelStyle()
                        TextField("Notes…", text: Binding(
                            get: { session.workout.exercises[exerciseIndex].note },
                            set: { session.workout.exercises[exerciseIndex].note = $0 }
                        ), axis: .vertical)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text)
                            .padding(AuraSpacing.s3)
                            .background(Color.aura.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    }

                    // Action buttons
                    HStack(spacing: AuraSpacing.s3) {
                        AuraTintedButton(label: "Add Set", icon: "plus") {
                            session.onAddSet(to: exerciseIndex)
                        }
                        AuraPrimaryButton(label: "Complete Exercise", icon: "checkmark") {
                            session.onCompleteExercise(at: exerciseIndex)
                        }
                    }
                    .padding(.bottom, 100)
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s4)
            }
        }
        .background(Color.aura.bg)
        .sheet(isPresented: $showMenu) {
            ExerciseMenuSheet(exerciseIndex: exerciseIndex)
                .environmentObject(session)
                .presentationDetents([.fraction(0.55)])
                .presentationDragIndicator(.visible)
        }
    }
}
