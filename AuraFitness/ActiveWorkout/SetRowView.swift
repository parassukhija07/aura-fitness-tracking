import SwiftUI

/// A single working-set row, matching the design's `WkSetRow`:
/// set-number/type button · kg input · reps input · check · trash,
/// with an optional last-session history row underneath.
struct SetRowView: View {
    @EnvironmentObject var session: WorkoutSessionState
    let exerciseIndex: Int
    let setIndex: Int
    @Binding var set: WorkoutSet
    /// Last session's value for this set index (shown as faint reference).
    var history: SetHistory? = nil
    var showHistory: Bool = true

    @State private var weightText: String = ""
    @State private var repsText: String = ""
<<<<<<< HEAD
    @State private var showNote: Bool = false
    @State private var showTypeMenu: Bool = false
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool

    // Previous session history (passed from parent for display)
    var previousWeight: Double? = nil
    var previousReps: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            mainRow
            if showNote || !set.note.isEmpty {
                noteRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if let pw = previousWeight, let pr = previousReps {
                historyRow(pw: pw, pr: pr)
            }
        }
        .padding(.horizontal, AuraSpacing.s3)
        .padding(.vertical, 6)
        .background(set.done
            ? Color.aura.green.opacity(0.06)
            : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        .animation(.easeInOut(duration: 0.15), value: set.done)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                session.onDeleteSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
            } label: {
                Label("Delete", systemImage: "trash")
            }
=======
    @State private var showTypeMenu = false

    private var filled: Bool { !weightText.isEmpty && !repsText.isEmpty }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 9) {
                // Set number / type button
                Button { showTypeMenu = true } label: {
                    Text(set.type == .normal ? "\(setIndex + 1)" : set.type.shortLabel)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(set.type == .normal ? .aura.text : set.type.color)
                        .frame(width: 40, height: 48)
                        .background(Color.aura.fill)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                }
                .buttonStyle(.plain)

                // Weight input
                inputBox(text: $weightText, placeholder: history.map { $0.weight } ?? "–", label: "kg") {
                    set.weight = Double(weightText)
                    autoFinishOnBlur()
                }

                // Reps input
                inputBox(text: $repsText, placeholder: history.map { $0.reps } ?? "–", label: "reps") {
                    set.reps = Int(repsText)
                    autoFinishOnBlur()
                }

                // Done check
                Button { toggleDone() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(set.done ? .white : .aura.text3)
                        .frame(width: 48, height: 48)
                        .background(set.done ? Color.aura.green : Color.aura.fill)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                }
                .buttonStyle(.plain)

                // Delete (always visible, per design)
                Button {
                    session.onDeleteSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.aura.red)
                        .frame(width: 48, height: 48)
                        .background(Color.aura.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                }
                .buttonStyle(.plain)
            }

            // History row (last session), aligned under the kg / reps inputs
            if showHistory, let h = history {
                HStack(spacing: 9) {
                    Color.clear.frame(width: 40)
                    Text("\(h.weight) kg")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.aura.text3)
                        .frame(maxWidth: .infinity)
                    Text("\(h.reps) reps")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.aura.text3)
                        .frame(maxWidth: .infinity)
                    Color.clear.frame(width: 48)
                    Color.clear.frame(width: 48)
                }
                .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            weightText = set.weight.map { formatWeight($0) } ?? ""
            repsText = set.reps.map { String($0) } ?? ""
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
        }
        .sheet(isPresented: $showTypeMenu) {
            SetTypeMenuSheet(currentType: set.type) { type in
                session.onSetTypeChange(exerciseIndex: exerciseIndex, setIndex: setIndex, type: type)
                showTypeMenu = false
            }
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            weightText = set.weight.map { formatWeight($0) } ?? ""
            repsText = set.reps.map { String($0) } ?? ""
        }
    }

<<<<<<< HEAD
    // MARK: Main row
    private var mainRow: some View {
        HStack(spacing: AuraSpacing.s2) {
            // Set type / number badge — 44×44 touch target (HIG)
            Button { showTypeMenu = true } label: {
                ZStack {
                    Circle()
                        .fill(set.type.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Text(set.type == .normal ? "\(setIndex + 1)" : set.type.shortLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(set.type.color)
                }
                .frame(width: 44, height: 44) // HIG min
            }
            .buttonStyle(.plain)

            // Weight input
            VStack(spacing: 1) {
                TextField("–", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(AuraFont.statNum(size: 18))
                    .foregroundColor(set.done ? .aura.green : .aura.text)
                    .focused($weightFocused)
                    .frame(maxWidth: .infinity)
                    .onChange(of: weightText) { _, v in
                        set.weight = Double(v.replacingOccurrences(of: ",", with: "."))
                        if set.weight != nil && set.reps != nil && !set.done { autoComplete() }
                    }
                Text("KG")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.aura.text3)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(inputBg)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))

            Text("×")
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.aura.text3)
                .frame(width: 14)

            // Reps input
            VStack(spacing: 1) {
                TextField("–", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(AuraFont.statNum(size: 18))
                    .foregroundColor(set.done ? .aura.green : .aura.text)
                    .focused($repsFocused)
                    .frame(maxWidth: .infinity)
                    .onChange(of: repsText) { _, v in
                        set.reps = Int(v)
                        if set.weight != nil && set.reps != nil && !set.done { autoComplete() }
                    }
                Text("REPS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.aura.text3)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(inputBg)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))

            // Done checkmark — 44×44 (HIG)
            Button { toggleDone() } label: {
                ZStack {
                    Circle()
                        .fill(set.done ? Color.aura.green : Color.aura.fill)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(set.done ? .white : .aura.text3)
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            // Note toggle — 44×44
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showNote.toggle() }
            } label: {
                Image(systemName: set.note.isEmpty ? "note.text" : "note.text.badge.plus")
                    .font(.system(size: 15))
                    .foregroundColor(set.note.isEmpty ? .aura.text3 : .aura.accent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Note row
    private var noteRow: some View {
        HStack(spacing: AuraSpacing.s2) {
            Image(systemName: "note.text")
                .font(.system(size: 12))
                .foregroundColor(.aura.text3)
                .frame(width: 44)
            TextField("Note for this set…", text: $set.note)
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text)
                .submitLabel(.done)
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    // MARK: History row
    @ViewBuilder
    private func historyRow(pw: Double, pr: Int) -> some View {
        HStack(spacing: AuraSpacing.s2) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 10))
                .foregroundColor(.aura.text3)
                .frame(width: 44)
            Text("Last: \(formatWeight(pw)) kg × \(pr) reps")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.aura.text3)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    // MARK: Helpers
    private var inputBg: Color {
        set.done
            ? Color.aura.green.opacity(0.09)
            : Color.aura.surface2
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(w))
            : String(format: "%.1f", w)
    }

    private func autoComplete() {
        guard !set.done else { return }
        // Small delay so user can still type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard !set.done, set.weight != nil, set.reps != nil else { return }
            session.onSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
            // Haptic
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            weightFocused = false
            repsFocused = false
        }
=======
    @ViewBuilder
    private func inputBox(text: Binding<String>, placeholder: String, label: String, onBlur: @escaping () -> Void) -> some View {
        VStack(spacing: -2) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.aura.text)
                .onChange(of: text.wrappedValue) { _, _ in onBlur() }
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.aura.text3)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(set.done
                    ? Color.aura.green.opacity(0.09)
                    : Color.aura.surface2)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.sm)
                .stroke(set.done ? Color.aura.green.opacity(0.22) : Color.aura.separator.opacity(0.5), lineWidth: 1)
        )
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w)
    }

    private func autoFinishOnBlur() {
        // Design: when both kg & reps are filled, mark the set done.
        guard !set.done, filled else { return }
        session.onSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
    }

    private func toggleDone() {
        if set.done {
            set.done = false
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
<<<<<<< HEAD
            set.weight = Double(weightText.replacingOccurrences(of: ",", with: "."))
=======
            set.weight = Double(weightText)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
            set.reps = Int(repsText)
            session.onSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

// MARK: - Set Type Menu (design SET_TYPES: normal/drop/restpause/failure/partials)
struct SetTypeMenuSheet: View {
    let currentType: SetType
    let onSelect: (SetType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            HStack {
                Text("Set type")
                    .font(AuraFont.navTitle())
                    .foregroundColor(.aura.text)
                Spacer()
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.vertical, AuraSpacing.s2)

            VStack(spacing: 0) {
                ForEach(SetType.allCases, id: \.self) { type in
                    Button { onSelect(type) } label: {
                        HStack(spacing: AuraSpacing.s3) {
<<<<<<< HEAD
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(type.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text(type.shortLabel.isEmpty ? "N" : type.shortLabel)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(type.color)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.label)
                                    .font(AuraFont.body())
                                    .foregroundColor(.aura.text)
                                Text(setTypeDescription(type))
                                    .font(AuraFont.secondary())
                                    .foregroundColor(.aura.text2)
                            }
=======
                            Text(type.shortLabel.isEmpty ? "N" : type.shortLabel)
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(type.color)
                                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xs))
                            Text(type.label)
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
                            Spacer()
                            if type == currentType {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.aura.accent)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.aura.text3)
                            }
                        }
                        .padding(.horizontal, AuraSpacing.s4)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if type != SetType.allCases.last {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            Spacer()
        }
        .background(Color.aura.bg)
    }

    private func setTypeDescription(_ type: SetType) -> String {
        switch type {
        case .normal:    return "Standard working set"
        case .drop:      return "Reduce weight immediately after failure"
        case .restPause: return "Brief pause then continue to failure"
        case .failure:   return "Train to complete muscular failure"
        case .partials:  return "Reduced range of motion for extra reps"
        }
    }
}
