import SwiftUI

// MARK: - Active workout modal routing (mirrors app.jsx modal kinds)

enum WorkoutModal: Identifiable {
    case substitute(exIdx: Int)
    case createSuperset(exIdx: Int)
    case removeSuperset(exIdx: Int)
    case addExercise(forSupersetExIdx: Int?)

    var id: String {
        switch self {
        case .substitute(let i):    return "sub-\(i)"
        case .createSuperset(let i): return "sspick-\(i)"
        case .removeSuperset(let i): return "removess-\(i)"
        case .addExercise(let i):    return "add-\(i.map(String.init) ?? "end")"
        }
    }
}

struct WorkoutModalsView: View {
    @EnvironmentObject var session: WorkoutSessionState
    let modal: WorkoutModal
    @Binding var presented: WorkoutModal?

    @State private var search = ""

    var body: some View {
        Group {
            switch modal {
            case .substitute(let i):     substituteSheet(i)
            case .createSuperset(let i): createSupersetSheet(i)
            case .removeSuperset(let i): removeSupersetSheet(i)
            case .addExercise(let ssIdx): addExerciseSheet(forSS: ssIdx)
            }
        }
        .background(Color.aura.bg)
    }

    private func grabber() -> some View { SheetGrabber().frame(maxWidth: .infinity) }

    // MARK: Substitute

    private func substituteSheet(_ ei: Int) -> some View {
        let cur = session.workout.exercises.indices.contains(ei) ? session.workout.exercises[ei] : nil
        return ScrollView {
            VStack(spacing: AuraSpacing.s3) {
                grabber()
                VStack(spacing: 3) {
                    Text("Substitute Exercise").font(.system(size: 15, weight: .bold)).foregroundColor(.aura.text)
                    Text("Replacing: \(cur?.name ?? "")").font(.system(size: 12)).foregroundColor(.aura.text2)
                }
                .padding(.vertical, 4)
                VStack(spacing: 0) {
                    ForEach(Array(ActiveWorkoutData.substituteOptions.enumerated()), id: \.element.id) { idx, o in
                        optionRow(o, trailing: "chevron") {
                            var repl = o.makeExercise()
                            // keep current sets
                            if let c = cur { repl.sets = c.sets }
                            session.substituteExercise(at: ei, with: repl)
                            presented = nil
                        }
                        if idx < ActiveWorkoutData.substituteOptions.count - 1 { Divider().padding(.leading, 56) }
                    }
                }
                .background(Color.aura.surface).clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.horizontal, AuraSpacing.screenPad)
                AuraGrayButton(label: "Cancel") { presented = nil }
                    .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Create superset (ss-pick)

    private func createSupersetSheet(_ ei: Int) -> some View {
        let src = session.workout.exercises.indices.contains(ei) ? session.workout.exercises[ei] : nil
        let others = Array(session.workout.exercises.enumerated()).filter { $0.offset != ei }
        return ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber()
                HStack {
                    Text("Create Superset").font(AuraFont.navTitle()).foregroundColor(.aura.text)
                    Spacer()
                }.padding(.horizontal, AuraSpacing.screenPad)

                // A chip
                HStack(spacing: 10) {
                    Text("A").font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
                        .frame(width: 26, height: 26).background(Color.aura.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Text(src?.name ?? "").font(.system(size: 14, weight: .bold)).foregroundColor(.aura.text)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.aura.accentSoft).clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.horizontal, AuraSpacing.screenPad)

                Text("PAIR WITH (B)").font(.system(size: 11, weight: .bold)).foregroundColor(.aura.text2)
                    .tracking(0.5).padding(.horizontal, AuraSpacing.screenPad)

                VStack(spacing: 0) {
                    ForEach(others, id: \.element.id) { pair in
                        let e = pair.element
                        let i = pair.offset   // original index in session.workout.exercises
                        Button {
                            session.createSuperset(sourceIndex: ei, targetIndex: i)
                            presented = nil
                        } label: {
                            HStack(spacing: 12) {
                                Text("B").font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
                                    .frame(width: 26, height: 26).background(Color.aura.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(e.name).font(.system(size: 16, weight: .medium)).foregroundColor(.aura.text)
                                    Text("\(e.equipment) · \(e.repRange) reps").font(.system(size: 13)).foregroundColor(.aura.text2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(.aura.text3)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                        if pair.element.id != others.last?.element.id { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color.aura.surface).clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.horizontal, AuraSpacing.screenPad)

                Text("OR ADD NEW").font(.system(size: 11, weight: .bold)).foregroundColor(.aura.text2)
                    .tracking(0.5).padding(.horizontal, AuraSpacing.screenPad)
                Button { presented = .addExercise(forSupersetExIdx: ei) } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AuraRadius.xs).fill(Color.aura.green).frame(width: 30, height: 30)
                            Image(systemName: "plus.circle.fill").foregroundColor(.white).font(.system(size: 16))
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Add new exercise").font(.system(size: 16, weight: .medium)).foregroundColor(.aura.text)
                            Text("Position in list sets A/B order").font(.system(size: 13)).foregroundColor(.aura.text2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(.aura.text3)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 13)
                    .background(Color.aura.surface).clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AuraSpacing.screenPad)

                AuraGrayButton(label: "Cancel") { presented = nil }
                    .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .presentationDetents([.large])
    }

    // MARK: Remove superset confirmation

    private func removeSupersetSheet(_ ei: Int) -> some View {
        let a = session.workout.exercises.indices.contains(ei) ? session.workout.exercises[ei] : nil
        let b = session.workout.exercises.indices.contains(ei + 1) ? session.workout.exercises[ei + 1] : nil
        return ScrollView {
            VStack(spacing: AuraSpacing.s3) {
                grabber()
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(Color.aura.red.opacity(0.12)).frame(width: 48, height: 48)
                        Image(systemName: "bolt.fill").foregroundColor(.aura.red).font(.system(size: 22))
                    }
                    Text("Remove Superset?").font(.system(size: 17, weight: .heavy)).foregroundColor(.aura.text)
                    Text("This will split the pair into two individual exercises. All logged sets and weights are kept.")
                        .font(.system(size: 12)).foregroundColor(.aura.text2)
                        .multilineTextAlignment(.center).frame(maxWidth: 260)
                }
                .padding(.bottom, 4)

                VStack(spacing: 8) {
                    if let a { ssSummaryRow("A", a, color: .aura.accent) }
                    if let b { ssSummaryRow("B", b, color: .aura.blue) }
                }
                .padding(12)
                .background(Color.aura.surface).clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, AuraSpacing.screenPad)

                AuraDangerButton(label: "Split into individual exercises") {
                    session.removeSuperset(at: ei)
                    session.triggerCelebration(emoji: "✂️", title: "Superset split", message: "Both exercises continue as individual items.")
                    presented = nil
                    if case .superset = session.activeView { session.activeView = .overview }
                }
                .padding(.horizontal, AuraSpacing.screenPad)
                AuraGrayButton(label: "Keep superset") { presented = nil }
                    .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .presentationDetents([.medium])
    }

    private func ssSummaryRow(_ letter: String, _ ex: Exercise, color: Color) -> some View {
        HStack(spacing: 7) {
            Text(letter).font(.system(size: 9, weight: .heavy)).foregroundColor(.white)
                .frame(width: 18, height: 18).background(color).clipShape(RoundedRectangle(cornerRadius: 4))
            Text(ex.name).font(.system(size: 13, weight: .semibold)).foregroundColor(.aura.text).lineLimit(1)
            Spacer()
            Text("\(ex.sets.filter { $0.done }.count)/\(ex.sets.count) sets logged")
                .font(.system(size: 11, weight: .bold)).foregroundColor(.aura.green)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.aura.green.opacity(0.12)).clipShape(Capsule())
        }
    }

    // MARK: Add exercise

    private func addExerciseSheet(forSS: Int?) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                grabber()
                VStack(spacing: 3) {
                    Text(forSS != nil ? "Add Exercise to Superset" : "Add Exercise")
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.aura.text)
                    Text(forSS != nil ? "Position in list determines A/B order" : "Added to end of workout")
                        .font(.system(size: 12)).foregroundColor(.aura.text2)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.aura.text3).font(.system(size: 16))
                    TextField("Search exercise library…", text: $search)
                        .font(.system(size: 15)).foregroundColor(.aura.text)
                }
                .padding(.horizontal, 13).padding(.vertical, 11)
                .background(Color.aura.fill.opacity(0.5)).clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                .padding(.horizontal, AuraSpacing.screenPad)

                Text("SUGGESTED").font(.system(size: 11, weight: .bold)).foregroundColor(.aura.text2)
                    .tracking(0.5).padding(.horizontal, AuraSpacing.screenPad)

                VStack(spacing: 0) {
                    let opts = filteredAddOptions
                    ForEach(Array(opts.enumerated()), id: \.element.id) { idx, o in
                        optionRow(o, trailing: "plus") {
                            session.addExercise(o.makeExercise())
                            if let srcIdx = forSS {
                                // move the just-added (last) exercise right after src and pair
                                let last = session.workout.exercises.count - 1
                                session.createSuperset(sourceIndex: srcIdx, targetIndex: last)
                            }
                            presented = nil
                        }
                        if idx < opts.count - 1 { Divider().padding(.leading, 56) }
                    }
                }
                .background(Color.aura.surface).clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.horizontal, AuraSpacing.screenPad)

                AuraGrayButton(label: "Cancel") { presented = nil }
                    .padding(.horizontal, AuraSpacing.screenPad)
            }
            .padding(.bottom, AuraSpacing.s6)
        }
        .presentationDetents([.large])
    }

    private var filteredAddOptions: [WorkoutExerciseOption] {
        guard !search.isEmpty else { return ActiveWorkoutData.addOptions }
        let all = ActiveWorkoutData.addOptions + ActiveWorkoutData.suggestions
        return all.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    // MARK: Shared option row

    private func optionRow(_ o: WorkoutExerciseOption, trailing: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(ActiveWorkoutData.muscleInitial(o.muscle))
                    .font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(ActiveWorkoutData.muscleColor(o.muscle))
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xs))
                VStack(alignment: .leading, spacing: 1) {
                    Text(o.name).font(.system(size: 16, weight: .medium)).foregroundColor(.aura.text)
                    Text("\(o.muscle) · \(o.equipment)").font(.system(size: 13)).foregroundColor(.aura.text2)
                }
                Spacer()
                Image(systemName: trailing == "plus" ? "plus.circle.fill" : "chevron.right")
                    .font(.system(size: trailing == "plus" ? 20 : 14))
                    .foregroundColor(trailing == "plus" ? .aura.accent : .aura.text3)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}
