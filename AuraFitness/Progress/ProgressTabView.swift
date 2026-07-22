import SwiftUI

struct ProgressTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var topTab = "Stats"
    @State private var bodyTab = "Measurements"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom large-title navbar (nav-title-lg · 30/800), matching Log/Plan.
                HStack {
                    Text("Progress")
                        .font(AuraFont.largeTitleStyle())
                        .tracking(AuraFont.largeTitleTracking)
                        .foregroundColor(.aura.text)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, AuraSpacing.s1)
                .padding(.bottom, AuraSpacing.s2)

                AuraSegmentedPicker(options: ["Stats","Body"], selection: $topTab)
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.bottom, AuraSpacing.s2)

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
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                // The tab bar floats over the content and contributes no layout
                // height, so the full bar depth has to be reserved here.
                Color.clear.frame(height: AuraSpacing.tabBarClearance)
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
