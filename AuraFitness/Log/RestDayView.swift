import SwiftUI

struct RestDayView: View {
    @Binding var showAddWorkout: Bool

    var body: some View {
        VStack(spacing: AuraSpacing.s4) {
            AuraCard {
                VStack(spacing: AuraSpacing.s4) {
                    Text("🌙")
                        .font(.system(size: 48))
                    Text("Rest Day")
                        .font(AuraFont.cardTitle())
                        .foregroundColor(.aura.text)
                    Text("Recovery is part of the process.\nYour muscles grow when you rest.")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(AuraSpacing.s6)
            }

            AuraTintedButton(label: "Add a Workout", icon: "plus") {
                showAddWorkout = true
            }

            Button {
                // Convert to training day action
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Convert to training day")
                        .font(AuraFont.secondary())
                }
                .foregroundColor(.aura.text2)
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
    }
}
