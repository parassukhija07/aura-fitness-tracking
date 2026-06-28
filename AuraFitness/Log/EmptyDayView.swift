import SwiftUI

struct EmptyDayView: View {
    @Binding var showAddWorkout: Bool
    @State private var showLogPast = false

    var body: some View {
        VStack(spacing: AuraSpacing.s4) {
            // Dashed empty state card
            ZStack {
                RoundedRectangle(cornerRadius: AuraRadius.xl)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                    .foregroundColor(.aura.separator)
                    .frame(height: 180)

                VStack(spacing: AuraSpacing.s2) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.aura.text3)
                    Text("No workout planned")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text2)
                    Text("Add a workout to get started")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text3)
                }
            }

            AuraPrimaryButton(label: "Add a Workout", icon: "plus") {
                showAddWorkout = true
            }

            AuraGrayButton(label: "Log a Past Workout", icon: "clock") {
                showLogPast = true
            }
        }
        .padding(.horizontal, AuraSpacing.screenPad)
        .sheet(isPresented: $showLogPast) {
            LogPastWorkoutSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
