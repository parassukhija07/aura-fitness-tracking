import SwiftUI

struct ProgressTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var topTab = "Stats"
    @State private var bodyTab = "Measurements"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AuraSegmentedPicker(options: ["Stats","Body"], selection: $topTab)
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.vertical, AuraSpacing.s2)

                if topTab == "Stats" {
                    StatsView()
                } else {
                    VStack(spacing: 0) {
                        AuraSegmentedPicker(options: ["Measurements","Nutrition"], selection: $bodyTab)
                            .padding(.horizontal, AuraSpacing.screenPad)
                            .padding(.bottom, AuraSpacing.s2)

                        if bodyTab == "Measurements" {
                            MeasurementsView()
                        } else {
                            NutritionView()
                        }
                    }
                }
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: AuraSpacing.tabBarClearance - 34)
            }
            // FAB deep links (Log Measurements / Progress Photo) open the Body
            // tab; MeasurementsView then raises the matching sheet.
            .onChange(of: appState.progressDeepLink) { _, link in
                guard link != nil else { return }
                topTab = "Body"
                bodyTab = "Measurements"
            }
            .onAppear {
                if appState.progressDeepLink != nil {
                    topTab = "Body"; bodyTab = "Measurements"
                }
            }
        }
    }
}
