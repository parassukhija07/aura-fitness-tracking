import SwiftUI

/// A single working-set row, matching the design's `WkSetRow`:
/// set-number/type button · kg input · reps input · check · trash,
/// with an optional last-session history row underneath.
struct SetRowView: View {
    @EnvironmentObject var session: WorkoutSessionState
    @EnvironmentObject var appState: AppState
    let exerciseIndex: Int
    let setIndex: Int
    @Binding var set: WorkoutSet
    /// Last session's value for this set index (shown as faint reference).
    var history: SetHistory? = nil
    var showHistory: Bool = true

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var showTypeMenu = false

    private var filled: Bool { !weightText.isEmpty && !repsText.isEmpty }

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 9) {
                // Set number / type button
                Button { showTypeMenu = true } label: {
                    Text(set.type == .normal ? "\(setIndex + 1)" : set.type.shortLabel)
                        .font(AuraFont.jakarta(16, .heavy))
                        .foregroundColor(set.type == .normal ? .aura.text : set.type.color)
                        .frame(width: 40, height: 48)
                        .background(Color.aura.fill)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                }
                .buttonStyle(.plain)

                // Column order follows the "Show first" setting.
                if appState.showRepsFirst {
                    repsInput
                    weightInput
                } else {
                    weightInput
                    repsInput
                }

                // Done check
                Button { toggleDone() } label: {
                    Image(systemName: "checkmark")
                        .font(AuraFont.jakarta(16, .bold))
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
                        .font(AuraFont.jakarta(16))
                        .foregroundColor(.aura.red)
                        .frame(width: 48, height: 48)
                        .background(Color.aura.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                }
                .buttonStyle(.plain)
            }

            // History row (last session) — must track the same column order.
            if showHistory, let h = history {
                HStack(spacing: 9) {
                    Color.clear.frame(width: 40)
                    if appState.showRepsFirst {
                        historyCell("\(h.reps) reps")
                        historyCell(UnitFormatter.weight(Double(h.weight) ?? 0, unit: appState.weightUnit))
                    } else {
                        historyCell(UnitFormatter.weight(Double(h.weight) ?? 0, unit: appState.weightUnit))
                        historyCell("\(h.reps) reps")
                    }
                    Color.clear.frame(width: 48)
                    Color.clear.frame(width: 48)
                }
                .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            weightText = set.weight.map { UnitFormatter.weightNumber($0, unit: appState.weightUnit) } ?? ""
            repsText = set.reps.map { String($0) } ?? ""
        }
        .sheet(isPresented: $showTypeMenu) {
            SetTypeMenuSheet(currentType: set.type) { type in
                session.onSetTypeChange(exerciseIndex: exerciseIndex, setIndex: setIndex, type: type)
                showTypeMenu = false
            }
            .presentationDetents([.fraction(0.58)])
            .presentationDragIndicator(.visible)
        }
    }

    private var weightInput: some View {
        inputBox(text: $weightText, placeholder: history.map { $0.weight } ?? "–", label: appState.weightUnit) {
            set.weight = UnitFormatter.parseWeightToKg(weightText, unit: appState.weightUnit)
            autoFinishOnBlur()
        }
    }

    private var repsInput: some View {
        inputBox(text: $repsText, placeholder: history.map { $0.reps } ?? "–", label: "reps") {
            set.reps = Int(repsText)
            autoFinishOnBlur()
        }
    }

    private func historyCell(_ text: String) -> some View {
        Text(text)
            .font(AuraFont.jakarta(11, .bold))
            .foregroundColor(.aura.text3)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func inputBox(text: Binding<String>, placeholder: String, label: String, onBlur: @escaping () -> Void) -> some View {
        VStack(spacing: -2) {
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(AuraFont.jakarta(18, .heavy))
                .foregroundColor(.aura.text)
                .onChange(of: text.wrappedValue) { _, _ in onBlur() }
            Text(label)
                .font(AuraFont.jakarta(9, .bold))
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
    }

    private func toggleDone() {
        if set.done {
            set.done = false
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } else {
            set.weight = UnitFormatter.parseWeightToKg(weightText, unit: appState.weightUnit)
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
                            Text(type.shortLabel.isEmpty ? "N" : type.shortLabel)
                                .font(AuraFont.jakarta(12, .heavy))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(type.color)
                                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xs))
                            Text(type.label)
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text)
                            Spacer()
                            // Design shows a plain chevron on every row (no
                            // current-selection check).
                            Image(systemName: "chevron.right")
                                .font(AuraFont.jakarta(14))
                                .foregroundColor(.aura.text3)
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
