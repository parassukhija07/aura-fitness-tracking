import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: WorkoutSessionState
    @State private var showEndSheet = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.aura.bg.ignoresSafeArea()

            switch session.activeView {
            case .overview:
                WorkoutOverviewView(showEndSheet: $showEndSheet)
            case .exercise(let index):
                ExerciseLoggingView(exerciseIndex: index)
            case .superset(let index):
                SupersetView(supersetIndex: index)
            case .summary:
                WorkoutSummaryView()
            }

            // Rest pill always on top
            RestPillView()

            // Celebration overlay
            CelebrationOverlay()
        }
        .sheet(isPresented: $showEndSheet) {
            EndWorkoutSheet(showEndSheet: $showEndSheet)
                .presentationDetents([.fraction(0.45)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { session.refreshOnForeground() }
        }
    }
}

// MARK: - End Workout Sheet
struct EndWorkoutSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var session: WorkoutSessionState
    @Binding var showEndSheet: Bool

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            VStack(spacing: AuraSpacing.s3) {
                VStack(spacing: 4) {
                    Text("End this workout?")
                        .font(AuraFont.navTitle())
                        .foregroundColor(.aura.text)
                    Text("\(session.doneSets) of \(session.totalSets) sets completed · \(session.elapsedFormatted)")
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                .padding(.top, AuraSpacing.s3)
                .padding(.bottom, AuraSpacing.s2)

                AuraPrimaryButton(label: "Finish & Save", icon: "checkmark") {
                    showEndSheet = false
                    session.activeView = .summary
                }

                AuraDangerButton(label: "Discard Workout", icon: "trash") {
                    showEndSheet = false
                    appState.discardWorkout()
                }

                AuraGrayButton(label: "Continue Workout") {
                    showEndSheet = false
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
    }
}
