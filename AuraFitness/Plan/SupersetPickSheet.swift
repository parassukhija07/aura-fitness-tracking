import SwiftUI

// MARK: - Superset partner chooser
//
// Presented when the user taps "Create Superset" on an exercise (the leader).
// Lets them pair the leader with an existing non-paired exercise, or route into
// the library picker to add a brand-new Exercise B. The editor performs the
// actual pairing/mutation; this sheet is pure selection UI.

struct SupersetPickSheet: View {
    let leader: Exercise
    /// Other exercises in the workout not already in a superset (no chains).
    let candidates: [Exercise]
    let onPickExisting: (Exercise) -> Void
    let onPickFromLibrary: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            SheetGrabber()
                .frame(maxWidth: .infinity)

            Text("Create Superset")
                .font(AuraFont.cardTitle(size: 20))
                .foregroundColor(.aura.text)

            // Leader row with an "A" badge.
            memberRow(leader.name, badge: "A")

            AuraSectionLabel(title: "Pair with existing")

            if candidates.isEmpty {
                Text("No other exercises available to pair")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
                    .padding(.vertical, AuraSpacing.s2)
            } else {
                VStack(spacing: 0) {
                    ForEach(candidates) { ex in
                        Button {
                            dismiss(); onPickExisting(ex)
                        } label: {
                            memberRow(ex.name, badge: "B")
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            // Library route → editor opens EditorExercisePicker in .supersetNew.
            Button {
                dismiss(); onPickFromLibrary()
            } label: {
                HStack(spacing: AuraSpacing.s3) {
                    Image(systemName: "books.vertical")
                        .font(AuraFont.jakarta(16, .semibold))
                        .foregroundColor(.aura.accent)
                        .frame(width: 24)
                    Text("Pick from library")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AuraFont.jakarta(13, .semibold))
                        .foregroundColor(.aura.text3)
                }
                .padding(.vertical, 12)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(AuraSpacing.screenPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.aura.bgGrouped)
    }

    @ViewBuilder
    private func memberRow(_ name: String, badge: String) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            ZStack {
                Circle()
                    .fill(Color.aura.accent.opacity(0.15))
                    .frame(width: 30, height: 30)
                Text(badge)
                    .font(AuraFont.jakarta(14, .bold))
                    .foregroundColor(.aura.accent)
            }
            Text(name)
                .font(AuraFont.body())
                .foregroundColor(.aura.text)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
