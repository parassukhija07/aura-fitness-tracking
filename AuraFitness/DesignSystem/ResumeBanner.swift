import SwiftUI

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
    }
}
