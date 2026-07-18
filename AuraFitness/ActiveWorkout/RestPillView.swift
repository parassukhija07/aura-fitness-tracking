import SwiftUI

struct RestPillView: View {
    @EnvironmentObject var session: WorkoutSessionState
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        if session.restActive {
            GeometryReader { geo in
                restPill(geo: geo)
            }
        }
    }

    @ViewBuilder
    private func restPill(geo: GeometryProxy) -> some View {
        let pct = session.restProgress
        // Clamp the restored/default position against this device's actual
        // screen size — the persisted/hardcoded default was sized for a
        // larger device and can land off-screen (or past the safe area) on
        // an SE or after a rotation.
        let x = max(8, min(session.pillPosition.x, geo.size.width - 200))
        let y = max(60, min(session.pillPosition.y, geo.size.height - 70))

        HStack(spacing: AuraSpacing.s2) {
            // Conic ring
            ZStack {
                Circle()
                    .stroke(Color.aura.track, lineWidth: 3)
                    .frame(width: 34, height: 34)
                Circle()
                    .trim(from: 0, to: pct)
                    .stroke(Color.aura.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "timer")
                    .font(.system(size: 12))
                    .foregroundColor(.aura.accent)
            }

            // Timer
            VStack(alignment: .leading, spacing: 0) {
                Text("REST")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.aura.text2)
                Text(session.restFormatted)
                    .font(AuraFont.statNum(size: 18))
                    .foregroundColor(.aura.text)
                    .monospacedDigit()
            }

            // +15s
            Button {
                session.addRestTime(15)
            } label: {
                Text("+15")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.aura.text)
                    .frame(width: 32, height: 28)
                    .background(Color.aura.fill)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xs))
            }
            .buttonStyle(.plain)

            // Pause/Play
            Button {
                session.pauseResumeRest()
            } label: {
                Image(systemName: session.restRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.aura.text)
                    .frame(width: 28, height: 28)
                    .background(Color.aura.fill)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xs))
            }
            .buttonStyle(.plain)

            // Dismiss
            Button {
                session.dismissRest()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.aura.text)
                    .frame(width: 28, height: 28)
                    .background(Color.aura.fill)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xs))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.aura.surface
                .shadow(.drop(color: .black.opacity(0.18), radius: 12, x: 0, y: 4))
        )
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.aura.separator.opacity(0.5), lineWidth: 1))
        .position(x: x, y: y)
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newX = max(8, min(value.location.x, geo.size.width - 200))
                    let newY = max(60, min(value.location.y, geo.size.height - 70))
                    session.pillPosition = CGPoint(x: newX, y: newY)
                }
        )
    }
}
