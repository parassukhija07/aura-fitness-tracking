import SwiftUI

<<<<<<< HEAD
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
=======
/// "Workout in progress" resume banner (shell · resume).
///
/// Shown only on the Log tab while a session is minimized (not finished). Solid
/// accent pill that floats just above the tab bar; tapping anywhere resumes the
/// live session. Mirrors `combined/log.jsx`: bottom 96, left/right 14, r-lg.
struct ResumeBanner: View {
    let onResume: () -> Void

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Workout in progress")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Tap to resume your session")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                }

                Spacer(minLength: 8)

                Text("Resume")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.20), in: Capsule())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.aura.accent, in: RoundedRectangle(cornerRadius: AuraRadius.lg))
            .shadow(color: Color.aura.accent.opacity(0.45), radius: 14, x: 0, y: 4)
        }
        .buttonStyle(.plain)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
    }
}
