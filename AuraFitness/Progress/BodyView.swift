import SwiftUI

// BodyView is composed of MeasurementsView and NutritionView via ProgressTabView segmented picker.
// This file acts as the top-level container if needed standalone.
struct BodyView: View {
    @State private var tab = "Measurements"
    var body: some View {
        VStack {
            AuraSegmentedPicker(options: ["Measurements","Nutrition"], selection: $tab)
                .padding()
            if tab == "Measurements" { MeasurementsView() } else { NutritionView() }
        }
    }
}
