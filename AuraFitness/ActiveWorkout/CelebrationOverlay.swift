import SwiftUI

struct CelebrationOverlay: View {
    @EnvironmentObject var session: WorkoutSessionState
    @State private var scale: CGFloat = 0.7
    @State private var emojiScale: CGFloat = 0.5

    var body: some View {
        if let celeb = session.celebration {
            ZStack {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: AuraSpacing.s2) {
                    Text(celeb.emoji)
                        .font(.system(size: 56))
                        .scaleEffect(emojiScale)

                    Text(celeb.title)
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundColor(.aura.text)

                    Text(celeb.message)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 240)
                        .lineLimit(3)
                }
                .padding(AuraSpacing.s5)
                .background(
                    Color.aura.surface
                        .shadow(.drop(color: .black.opacity(0.22), radius: 28, y: 10))
                )
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: AuraRadius.xl)
                        .stroke(Color.aura.separator2, lineWidth: 1)
                )
                .scaleEffect(scale)
                .padding(.horizontal, 40)
            }
            .transition(.opacity)
            .onAppear {
                // Haptic first
                let isPR = celeb.title.contains("PR") || celeb.title.contains("new")
                if isPR {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
                // Spring entrance
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                    scale = 1.0
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.05)) {
                    emojiScale = 1.0
                }
            }
            .onChange(of: celeb.id) { _, _ in
                scale = 0.7
                emojiScale = 0.5
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { scale = 1.0 }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.05)) { emojiScale = 1.0 }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}
