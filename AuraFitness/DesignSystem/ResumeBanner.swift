import SwiftUI

struct ResumeBanner: View {
    let session: WorkoutSessionState
    var onResume: () -> Void
    var onDiscard: () -> Void

    var body: some View {
        HStack(spacing: AuraSpacing.s3) {
            // Pulse dot
            ZStack {
                Circle()
                    .fill(Color.aura.accent.opacity(0.25))
                    .frame(width: 34, height: 34)
                Circle()
                    .fill(Color.aura.accent)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.workout.name)
                    .font(AuraFont.secondary())
                    .fontWeight(.bold)
                    .foregroundColor(.aura.text)
                    .lineLimit(1)
                Text(formatElapsed(session.elapsedSeconds))
                    .font(AuraFont.tiny())
                    .foregroundColor(.aura.text2)
                    .monospacedDigit()
            }

            Spacer()

            Button("Resume") {
                onResume()
            }
            .font(AuraFont.secondary())
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, AuraSpacing.s3)
            .padding(.vertical, AuraSpacing.s2)
            .background(Color.aura.accent)
            .clipShape(Capsule())

            Button {
                onDiscard()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.aura.text3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AuraSpacing.s4)
        .padding(.vertical, AuraSpacing.s3)
        .background(
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AuraRadius.lg)
                        .stroke(Color.aura.separator2, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        )
        .padding(.horizontal, AuraSpacing.s4)
    }

    private func formatElapsed(_ s: Int) -> String {
        let m = s / 60, sec = s % 60
        return String(format: "%d:%02d", m, sec)
    }
}
