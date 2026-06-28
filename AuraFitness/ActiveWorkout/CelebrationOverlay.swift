import SwiftUI

struct CelebrationOverlay: View {
    @EnvironmentObject var session: WorkoutSessionState

    var body: some View {
        if let celeb = session.celebration {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: AuraSpacing.s2) {
                    Text(celeb.emoji)
                        .font(.system(size: 48))
                    Text(celeb.title)
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.aura.text)
                    Text(celeb.message)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 240)
                        .lineLimit(3)
                }
                .padding(AuraSpacing.s5)
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xl))
                .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 8)
                .padding(.horizontal, 40)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: celeb.id)
        }
    }
}
