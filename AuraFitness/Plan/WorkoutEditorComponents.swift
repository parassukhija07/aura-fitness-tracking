import SwiftUI

// MARK: - Rest ladder
//
// Reusable pieces for the design-faithful workout editor: a stepped "rest
// ladder" picker, a custom exercise edit card with a per-exercise ⋯ menu, and
// the action menu sheet that menu opens. These replace the stock `List`/`Form`
// rows the editor used to render.

/// Allowed rest durations, ascending. The pickers step between adjacent
/// entries rather than by a fixed number of seconds.
let restLadder: [Int] = [15, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

/// Human label for a rest duration: `"45s"` under a minute, else `"m:ss"`.
func restLabel(_ seconds: Int) -> String {
    if seconds < 60 { return "\(seconds)s" }
    return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
}

/// Index of the ladder entry nearest to `seconds` (handles legacy off-ladder
/// values such as 65 by snapping to the closest rung).
private func nearestLadderIndex(_ seconds: Int) -> Int {
    var best = 0
    var bestDist = Int.max
    for (i, v) in restLadder.enumerated() {
        let d = abs(v - seconds)
        if d < bestDist { bestDist = d; best = i }
    }
    return best
}

// MARK: - RestLadderPicker

/// Card with a minus/plus stepper over the rest ladder plus a dot row showing
/// where the current value sits in the ladder.
struct RestLadderPicker: View {
    let title: String
    @Binding var seconds: Int

    private var index: Int { nearestLadderIndex(seconds) }

    var body: some View {
        AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                HStack {
                    Text(title)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                    Spacer()
                    Text(restLabel(restLadder[index]))
                        .font(AuraFont.cardTitle(size: 20))
                        .foregroundColor(.aura.text)
                        .monospacedDigit()
                }

                HStack(spacing: AuraSpacing.s4) {
                    stepButton("minus", enabled: index > 0) {
                        seconds = restLadder[max(0, index - 1)]
                    }

                    // Dot row: one per ladder rung, active rung tinted accent.
                    HStack(spacing: 5) {
                        ForEach(restLadder.indices, id: \.self) { i in
                            Circle()
                                .fill(i == index ? Color.aura.accent : Color.aura.text3.opacity(0.4))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    stepButton("plus", enabled: index < restLadder.count - 1) {
                        seconds = restLadder[min(restLadder.count - 1, index + 1)]
                    }
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    @ViewBuilder
    private func stepButton(_ symbol: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(AuraFont.jakarta(15, .bold))
                .foregroundColor(enabled ? .aura.text : .aura.text3)
                .frame(width: 34, height: 34)
                .background(Color.aura.fill)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - ExerciseEditCard

/// One exercise row in the editor: drag grip · name over set/rep chips · ⋯ menu.
struct ExerciseEditCard: View {
    let exercise: Exercise
    let index: Int
    let isReadOnly: Bool
    let isSupersetLeader: Bool
    let onTapName: () -> Void
    let onMenu: () -> Void

    var body: some View {
        AuraCard {
            HStack(spacing: AuraSpacing.s3) {
                if !isReadOnly {
                    Image(systemName: "line.3.horizontal")
                        .font(AuraFont.jakarta(18))
                        .foregroundColor(.aura.text3)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Button(action: onTapName) {
                        Text(exercise.name)
                            .font(AuraFont.body())
                            .foregroundColor(.aura.text)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        AuraBadge(label: "\(exercise.plannedSets) sets", color: .aura.text2)
                        AuraBadge(label: "\(exercise.repRange) reps", color: .aura.text2)
                        if isSupersetLeader {
                            AuraBadge(label: "SS", color: .aura.accent)
                        }
                    }
                }

                Spacer()

                if !isReadOnly {
                    Button(action: onMenu) {
                        Image(systemName: "ellipsis")
                            .font(AuraFont.jakarta(18, .semibold))
                            .foregroundColor(.aura.text2)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AuraSpacing.s4)
        }
    }
}

// MARK: - ExerciseEditMenuSheet

/// Per-exercise action sheet: inline sets/rep editing plus optional action rows.
/// Optional closures are `nil` when the action is not available (a follow-up
/// feature supplies Substitute / Superset / Add-After); a `nil` closure hides
/// its row entirely.
struct ExerciseEditMenuSheet: View {
    @Binding var exercise: Exercise
    let onSubstitute: (() -> Void)?
    let onSuperset: (() -> Void)?
    let onAddAfter: (() -> Void)?
    let onRemove: () -> Void
    /// When true the exercise is already in a pair, so the superset row reads
    /// "Remove Superset" and dissolves rather than creating.
    var isSuperset: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {

            Text(exercise.name)
                .font(AuraFont.cardTitle(size: 20))
                .foregroundColor(.aura.text)

            // Inline sets stepper (live).
            HStack {
                Text("Sets")
                    .font(AuraFont.body())
                    .foregroundColor(.aura.text)
                Spacer()
                AuraStepper(value: $exercise.plannedSets, range: 1...10,
                            format: { "\($0) sets" })
            }

            // Inline rep-range field (live). Empty commit restores the default.
            HStack {
                Text("Reps")
                    .font(AuraFont.body())
                    .foregroundColor(.aura.text)
                Spacer()
                TextField("8–12", text: $exercise.repRange)
                    .font(AuraFont.body())
                    .foregroundColor(.aura.text)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .onSubmit {
                        if exercise.repRange.trimmingCharacters(in: .whitespaces).isEmpty {
                            exercise.repRange = "8–12"
                        }
                    }
            }

            Divider()

            VStack(spacing: 0) {
                if let onSubstitute {
                    actionRow("Substitute Exercise", icon: "arrow.triangle.2.circlepath") {
                        dismiss(); onSubstitute()
                    }
                }
                if let onSuperset {
                    actionRow(isSuperset ? "Remove Superset" : "Create Superset",
                              icon: isSuperset ? "link.badge.plus" : "link") {
                        dismiss(); onSuperset()
                    }
                }
                if let onAddAfter {
                    actionRow("Add Exercise After", icon: "plus") {
                        dismiss(); onAddAfter()
                    }
                }
                actionRow("Remove Exercise", icon: "trash", color: .aura.red) {
                    dismiss(); onRemove()
                }
            }
        }
        .padding(AuraSpacing.screenPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.aura.bgGrouped)
    }

    @ViewBuilder
    private func actionRow(_ title: String, icon: String, color: Color = .aura.text,
                           _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                Image(systemName: icon)
                    .font(AuraFont.jakarta(16, .semibold))
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .font(AuraFont.body())
                    .foregroundColor(color)
                Spacer()
            }
            .padding(.vertical, 12)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SupersetConnector

/// Rendered between a superset leader and follower card: two accent rules
/// flanking a "⚡ SUPERSET" pill.
struct SupersetConnector: View {
    var body: some View {
        HStack(spacing: AuraSpacing.s2) {
            Rectangle()
                .fill(Color.aura.accent)
                .frame(height: 1)

            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(AuraFont.jakarta(10, .bold))
                Text("SUPERSET")
                    .font(AuraFont.sectionLabel())
                    .tracking(AuraFont.sectionLabelTracking)
            }
            .foregroundColor(.aura.accent)
            .padding(.horizontal, AuraSpacing.s3)
            .padding(.vertical, 4)
            .background(Color.aura.accent.opacity(0.12))
            .clipShape(Capsule())

            Rectangle()
                .fill(Color.aura.accent)
                .frame(height: 1)
        }
        .padding(.vertical, 2)
    }
}
