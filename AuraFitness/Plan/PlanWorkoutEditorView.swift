import SwiftUI
import UniformTypeIdentifiers

// MARK: - Workout Editor (full-screen)
// Mirrors WorkoutEditorView in plan/app.jsx: name field, two rest pickers, a
// reorderable exercise list, per-exercise ⋯ menu, substitute / add-after /
// superset / remove, and a tappable name → Exercise detail in workoutCtx mode.

struct PlanWorkoutEditorView: View {
    let workout: PlanWorkout
    var onBack: () -> Void

    @State private var wkName: String
    @State private var restSets = 60
    @State private var restEx = 90
    @State private var exercises: [PlanEditorExercise]
    @State private var dragIndex: Int? = nil

    // Routing within the editor. A single sheet enum avoids multi-`.sheet` races.
    @State private var sheet: EditorSheet? = nil
    @State private var picker: PickerRoute? = nil
    @State private var exDetail: ExDetailRoute? = nil

    enum EditorSheet: Identifiable {
        case menu(Int)      // ex-menu for exercise i
        case ssPick(Int)    // create-superset picker for leader i
        var id: String {
            switch self { case .menu(let i): return "menu-\(i)"; case .ssPick(let i): return "ss-\(i)" }
        }
    }
    struct PickerRoute: Identifiable {
        let id = UUID(); let mode: PickerMode
        var subIdx: Int? = nil; var afterIdx: Int? = nil; var ssSource: Int? = nil
    }
    struct ExDetailRoute: Identifiable {
        let id = UUID(); let exercise: PlanLibExercise; let idx: Int; let ctx: PlanWorkoutCtx
    }

    init(workout: PlanWorkout, onBack: @escaping () -> Void) {
        self.workout = workout
        self.onBack = onBack
        _wkName = State(initialValue: workout.name)
        _exercises = State(initialValue: PlanData.seedExercises(for: workout.id))
    }

    var body: some View {
        Group {
            if let route = exDetail {
                PlanExerciseDetailView(
                    exercise: route.exercise,
                    workoutCtx: route.ctx,
                    onSave: { sets, reps, rest in
                        if exercises.indices.contains(route.idx) {
                            exercises[route.idx].sets = sets
                            exercises[route.idx].reps = reps
                        }
                        restSets = rest
                        exDetail = nil
                    },
                    onBack: { exDetail = nil }
                )
            } else if let route = picker {
                PlanExercisePickerView(
                    mode: route.mode == .ssNew ? .add : route.mode,
                    replacingName: route.mode == .sub ? exercises[route.subIdx ?? 0].name : nil,
                    titleOverride: route.mode == .ssNew ? "Pick Exercise B" : nil,
                    onSelect: { ex in applyPick(route, ex); picker = nil },
                    onBack: { picker = nil }
                )
            } else {
                editor
            }
        }
    }

    // MARK: Editor body

    private var editor: some View {
        VStack(spacing: 0) {
            PlanNavbar(title: wkName, onBack: onBack) {
                Button { onBack() } label: {
                    Text("Save").font(.system(size: 17, weight: .bold)).foregroundColor(.aura.accent)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workout name").font(.system(size: 13, weight: .semibold)).foregroundColor(.aura.text2)
                        TextField("Workout name", text: $wkName)
                            .font(AuraFont.body())
                            .padding(.horizontal, 13).frame(height: 46)
                            .background(Color.aura.fill.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                    }
                    .padding(.top, 14)

                    HStack(spacing: 14) {
                        RestPicker(label: "Between sets", value: $restSets)
                        RestPicker(label: "After exercise", value: $restEx)
                    }
                    .padding(.top, 14)

                    HStack {
                        AuraSectionLabel(title: "Exercises")
                        Spacer()
                        PlanIconButton(icon: "plus", size: 16, diameter: 28, accent: true) {
                            picker = PickerRoute(mode: .add, afterIdx: exercises.count - 1)
                        }
                        .padding(.top, AuraSpacing.s5)
                    }
                    .padding(.bottom, 10)

                    VStack(spacing: 8) {
                        ForEach(Array(exercises.enumerated()), id: \.element.id) { i, ex in
                            let isSSSecond = i > 0
                                && ex.supersetGroupID != nil
                                && exercises[i - 1].supersetGroupID == ex.supersetGroupID
                            if isSSSecond { supersetConnector }
                            exerciseCard(i, ex)
                        }
                    }

                    Button { picker = PickerRoute(mode: .add, afterIdx: exercises.count - 1) } label: {
                        HStack(spacing: AuraSpacing.s2) {
                            Image(systemName: "plus").font(.system(size: 18, weight: .semibold))
                            Text("Add Exercise").font(AuraFont.body())
                        }
                        .foregroundColor(.aura.accent)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color.aura.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 14)
                Color.clear.frame(height: 28)
            }
        }
        .background(Color.aura.bg)
        .sheet(item: $sheet) { s in
            switch s {
            case .menu(let i):
                exMenuSheet(i)
                    .presentationDetents([.fraction(0.7)])
                    .presentationDragIndicator(.visible)
            case .ssPick(let i):
                ssPickSheet(i)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var supersetConnector: some View {
        HStack(spacing: 8) {
            Capsule().fill(Color.aura.accentSoft).frame(height: 2)
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill").font(.system(size: 11))
                Text("SUPERSET").font(.system(size: 10, weight: .heavy))
            }
            .foregroundColor(.aura.accent)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Color.aura.accentSoft).clipShape(Capsule())
            Capsule().fill(Color.aura.accentSoft).frame(height: 2)
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    private func exerciseCard(_ i: Int, _ ex: PlanEditorExercise) -> some View {
        let isSSSecond = i > 0
            && ex.supersetGroupID != nil
            && exercises[i - 1].supersetGroupID == ex.supersetGroupID
        let isSSFirst = ex.supersetGroupID != nil && !isSSSecond
        let tinted = isSSFirst || isSSSecond
        let dimmed = dragIndex != nil && dragIndex != i

        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").font(.system(size: 18))
                .foregroundColor(.aura.text3)
            VStack(alignment: .leading, spacing: 6) {
                Button { openExDetail(i) } label: {
                    Text(ex.name).font(.system(size: 15, weight: .bold)).foregroundColor(.aura.text)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                HStack(spacing: 5) {
                    cardChip("\(ex.sets) sets")
                    cardChip("\(ex.reps) reps")
                    if isSSFirst {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill").font(.system(size: 10))
                            Text("SS").font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.aura.accent)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Color.aura.accentSoft).clipShape(Capsule())
                    }
                }
            }
            Spacer()
            Button { sheet = .menu(i) } label: {
                Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold)).foregroundColor(.aura.text)
                    .frame(width: 34, height: 34).background(Color.aura.fill.opacity(0.5)).clipShape(Circle())
            }
        }
        .padding(14)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.md)
                .stroke(tinted ? Color.aura.accent.opacity(0.3) : Color.aura.separator2,
                        style: StrokeStyle(lineWidth: 1, dash: dimmed ? [4] : []))
        )
        .opacity(dimmed ? 0.5 : 1)
        .onDrag { dragIndex = i; return NSItemProvider(object: String(i) as NSString) }
        .onDrop(of: [UTType.text], delegate: ExerciseDropDelegate(target: i, dragIndex: $dragIndex, exercises: $exercises))
    }

    private func cardChip(_ t: String) -> some View {
        Text(t).font(.system(size: 12, weight: .medium)).foregroundColor(.aura.text)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color.aura.fill).clipShape(Capsule())
    }

    // MARK: ex-menu sheet

    @ViewBuilder
    private func exMenuSheet(_ i: Int) -> some View {
        let ex = exercises[i]
        let isSSed = ex.supersetGroupID != nil
        PlanSheet(centeredTitle: ex.name) {
            VStack(spacing: 0) {
                // Sets stepper
                HStack {
                    Text("Sets").font(.system(size: 14, weight: .semibold)).foregroundColor(.aura.text)
                    Spacer()
                    HStack(spacing: 10) {
                        stepBtn("minus", accent: false) { exercises[i].sets = max(1, exercises[i].sets - 1) }
                        Text("\(exercises[i].sets)").font(.system(size: 17, weight: .heavy))
                            .frame(minWidth: 24).foregroundColor(.aura.text)
                        stepBtn("plus", accent: true) { exercises[i].sets += 1 }
                    }
                }
                .padding(14)
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                .padding(.bottom, 10)

                // Rep-range input
                HStack {
                    Text("Rep range").font(.system(size: 14, weight: .semibold)).foregroundColor(.aura.text)
                    Spacer()
                    TextField("", text: $exercises[i].reps)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15, weight: .bold)).foregroundColor(.aura.text)
                        .frame(width: 80, height: 34)
                        .background(Color.aura.fill)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xs))
                        .overlay(RoundedRectangle(cornerRadius: AuraRadius.xs).stroke(Color.aura.separator2, lineWidth: 1))
                }
                .padding(14)
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                .padding(.bottom, 14)

                PlanList {
                    PlanRow(icon: "arrow.left.arrow.right", color: .aura.blue, label: "Substitute exercise") {
                        sheet = nil
                        picker = PickerRoute(mode: .sub, subIdx: i)
                    }
                    Divider().padding(.leading, 14)
                    PlanRow(icon: "bolt.fill", color: .aura.accent,
                            label: isSSed ? "Remove Superset" : "Create Superset…") {
                        if isSSed { removeSuperset(i); sheet = nil }
                        else { sheet = .ssPick(i) }   // swap sheet content in place
                    }
                    Divider().padding(.leading, 14)
                    PlanRow(icon: "plus.circle.fill", color: .aura.green, label: "Add exercise after") {
                        sheet = nil
                        picker = PickerRoute(mode: .add, afterIdx: i)
                    }
                }

                PlanList {
                    PlanRow(icon: "trash", color: .aura.red, label: "Remove exercise",
                            textColor: .aura.red, chevron: false) {
                        removeExercise(i); sheet = nil
                    }
                }
                .padding(.top, 12)

                AuraGrayButton(label: "Cancel") { sheet = nil }
                    .padding(.top, 12)
            }
        }
    }

    private func stepBtn(_ icon: String, accent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold))
                .foregroundColor(accent ? .aura.accent : .aura.text)
                .frame(width: 32, height: 32)
                .background(accent ? Color.aura.accentSoft : Color.aura.fill.opacity(0.5))
                .clipShape(Circle())
        }
    }

    // MARK: ss-pick sheet

    @ViewBuilder
    private func ssPickSheet(_ src: Int) -> some View {
        let srcEx = exercises[src]
        PlanSheet(title: "Create Superset", onClose: { sheet = nil }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    badge("A", color: .aura.accent)
                    Text(srcEx.name).font(.system(size: 14, weight: .bold)).foregroundColor(.aura.text)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.aura.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.bottom, 14)

                PlanSourceCard(icon: "magnifyingglass", iconBg: .aura.blue.opacity(0.14), iconTint: .aura.blue,
                               title: "Pick from library", subtitle: "Browse 50+ exercises") {
                    sheet = nil
                    picker = PickerRoute(mode: .ssNew, ssSource: src)
                }
                .padding(.bottom, 14)

                Text("OR PAIR WITH EXISTING").font(.system(size: 11, weight: .bold)).tracking(0.4)
                    .foregroundColor(.aura.text2).padding(.horizontal, 4).padding(.bottom, 10)

                PlanList {
                    let others = exercises.enumerated().filter { $0.offset != src }
                    ForEach(Array(others.enumerated()), id: \.element.element.id) { listIdx, pair in
                        let e = pair.element
                        Button { createSuperset(src: src, tgt: pair.offset); sheet = nil } label: {
                            HStack(spacing: AuraSpacing.s3) {
                                badge("B", color: .aura.blue, size: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(e.name).font(.system(size: 16, weight: .medium)).foregroundColor(.aura.text)
                                    Text("\(e.sets) sets · \(e.reps) reps").font(AuraFont.secondary()).foregroundColor(.aura.text2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.aura.text3)
                            }
                            .padding(.vertical, 11).padding(.horizontal, 14).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        if listIdx < others.count - 1 { Divider().padding(.leading, 14) }
                    }
                }
                .padding(.bottom, 12)

                AuraGrayButton(label: "Cancel") { sheet = nil }
            }
        }
    }

    private func badge(_ t: String, color: Color, size: CGFloat = 24) -> some View {
        Text(t).font(.system(size: 10, weight: .heavy)).foregroundColor(.white)
            .frame(width: size, height: size).background(color).clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: Mutations

    private func removeExercise(_ i: Int) {
        guard exercises.indices.contains(i) else { return }
        exercises.remove(at: i)
    }

    private func removeSuperset(_ index: Int) {
        guard exercises.indices.contains(index),
              let gid = exercises[index].supersetGroupID else { return }
        for idx in exercises.indices where exercises[idx].supersetGroupID == gid {
            exercises[idx].supersetGroupID = nil
        }
    }

    /// Create superset with existing partner — reorder target to sit right after
    /// the leader and assign both a shared group id (mirrors createSS in app.jsx).
    private func createSuperset(src: Int, tgt: Int) {
        var a = exercises
        for existingGID in [a[src].supersetGroupID, a[tgt].supersetGroupID].compactMap({ $0 }) {
            for idx in a.indices where a[idx].supersetGroupID == existingGID { a[idx].supersetGroupID = nil }
        }
        let t = a.remove(at: tgt)
        let leader = tgt < src ? src - 1 : src
        a.insert(t, at: leader + 1)
        let gid = UUID()
        a[leader].supersetGroupID = gid
        a[leader + 1].supersetGroupID = gid
        exercises = a
    }

    private func applyPick(_ route: PickerRoute, _ ex: PlanLibExercise) {
        switch route.mode {
        case .sub:
            if let i = route.subIdx { exercises[i].name = ex.name }
        case .ssNew:
            if let src = route.ssSource {
                var a = exercises
                if let existingGID = a[src].supersetGroupID {
                    for idx in a.indices where a[idx].supersetGroupID == existingGID { a[idx].supersetGroupID = nil }
                }
                let gid = UUID()
                a.insert(PlanEditorExercise(name: ex.name, sets: 3, reps: "8–12", supersetGroupID: gid), at: src + 1)
                a[src].supersetGroupID = gid
                exercises = a
            }
        case .add:
            let ai = route.afterIdx ?? (exercises.count - 1)
            exercises.insert(PlanEditorExercise(name: ex.name, sets: 3, reps: "8–12"), at: min(ai + 1, exercises.count))
        }
    }

    private func openExDetail(_ i: Int) {
        let ex = exercises[i]
        let libEx = PlanData.libExercise(named: ex.name)
        let isSSSecond = i > 0
            && ex.supersetGroupID != nil
            && exercises[i - 1].supersetGroupID == ex.supersetGroupID
        let isSSFirst = ex.supersetGroupID != nil && !isSSSecond
        let isSuperset = isSSFirst || isSSSecond
        let partner: PlanLibExercise? = isSSFirst ? (exercises.indices.contains(i + 1) ? PlanData.libExercise(named: exercises[i + 1].name) : nil)
            : (isSSSecond ? PlanData.libExercise(named: exercises[i - 1].name) : nil)
        exDetail = ExDetailRoute(exercise: libEx, idx: i, ctx: PlanWorkoutCtx(
            sets: ex.sets, reps: ex.reps, restTime: restSets,
            isSuperset: isSuperset, ssRole: isSSFirst ? "A" : "B", partner: partner))
    }
}

// MARK: Drag-reorder delegate (matches JSX removal-offset semantics)

private struct ExerciseDropDelegate: DropDelegate {
    let target: Int
    @Binding var dragIndex: Int?
    @Binding var exercises: [PlanEditorExercise]

    func performDrop(info: DropInfo) -> Bool {
        defer { dragIndex = nil }
        guard let from = dragIndex, from != target else { return false }
        var a = exercises
        let moved = a.remove(at: from)
        a.insert(moved, at: from < target ? target - 1 : target)
        exercises = a
        return true
    }
    func dropEntered(info: DropInfo) {}
    func validateDrop(info: DropInfo) -> Bool { true }
}

