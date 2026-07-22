import SwiftUI

// MARK: - Body map (front/back muscle silhouette)
//
// Thin adapter over `MuscleMapView`. It keeps the call-site API from the port of
// BodyMap in plan/exercise-detail.jsx — two pre-bucketed label lists and a fixed
// 115×140 frame — while the figure itself now comes from the shared anatomy in
// `MuscleMap.swift`.
//
// The original drew its own shapes and understood exactly seven coarse tokens
// (Shoulders/Chest/Biceps/Triceps/Core/Back/Legs), which is all the hand-written
// `PlanExerciseDetailData` ever passed it. Those tokens still resolve, but the
// shared map also handles the catalog's 50 raw `musclesTargeted` labels, so the
// same figure can be driven from `ExerciseEntry` elsewhere without a second
// drawing to keep in sync.

struct PlanBodyMap: View {
    var primary: [String]
    var secondary: [String]

    var body: some View {
        MuscleMapView(
            highlights: MuscleRegion.highlights(primary: primary, secondary: secondary),
            labelFont: AuraFont.jakarta(7, .bold)
        )
        .frame(width: 115, height: 140)
    }
}
