import SwiftUI

struct AddWorkoutSourceSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            Text("Add a Workout")
                .font(AuraFont.navTitle())
                .foregroundColor(.aura.text)
                .padding(.vertical, AuraSpacing.s3)

            VStack(spacing: AuraSpacing.s3) {
                sourceCard(icon: "calendar.badge.plus", color: .aura.accent,
                           title: "From a Program",
                           subtitle: "Choose from your active plan") {
                    dismiss()
                }
                sourceCard(icon: "dumbbell.fill", color: .aura.blue,
                           title: "A Saved Workout",
                           subtitle: "Pick from your workout library") {
                    dismiss()
                }
                sourceCard(icon: "magnifyingglass", color: .aura.green,
                           title: "Build from Library",
                           subtitle: "Search and add exercises") {
                    dismiss()
                }
                sourceCard(icon: "square.and.pencil", color: .aura.purple,
                           title: "Empty Workout",
                           subtitle: "Start fresh") {
                    let empty = Workout(id: UUID(), name: "My Workout", primaryMuscles: "Full Body",
                                        estimatedMinutes: 0, exercises: [])
                    appState.startWorkout(empty)
                    dismiss()
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
    }

    private func sourceCard(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: AuraRadius.sm)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text)
                    Text(subtitle)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.aura.text3)
            }
            .padding(AuraSpacing.s4)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        }
        .buttonStyle(.plain)
    }
}
