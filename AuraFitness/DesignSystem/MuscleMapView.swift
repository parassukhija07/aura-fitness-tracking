import SwiftUI

// MARK: - MuscleMapView

/// Front/back muscle map for an exercise: a neutral silhouette with the targeted
/// regions filled in.
///
/// This is the first-party stand-in for exercise imagery. The catalog ships with
/// every `imageURL` empty on purpose (THIRD_PARTY_NOTICES.md), so a thumbnail is
/// either a gradient or nothing; the map is the one visual that actually carries
/// information about the movement, and it works for all 1,316 catalog rows plus
/// any custom exercise, because it is driven by `musclesTargeted` rather than by
/// an asset that has to exist per exercise.
///
/// Colour convention matches the muscle-activation bars in the plan detail
/// screen: accent = primary target, blue = supporting mover.
struct MuscleMapView: View {
    /// Region → emphasis. Build with `MuscleRegion.highlights(for:)` rather than
    /// assembling by hand, so the primary-is-first rule stays in one place.
    let highlights: [MuscleRegion: MuscleEmphasis]
    var orientations: [MuscleMapOrientation] = [.front, .back]
    var primaryColor: Color = .aura.accent
    var secondaryColor: Color = .aura.blue
    var silhouetteColor: Color = .aura.fill
    var showsLabels: Bool = true
    var labelFont: Font = AuraFont.jakarta(9, .bold)

    var body: some View {
        HStack(alignment: .top, spacing: AuraSpacing.s2) {
            ForEach(orientations, id: \.self) { orientation in
                panel(orientation)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: Panels

    private func panel(_ orientation: MuscleMapOrientation) -> some View {
        VStack(spacing: 3) {
            ZStack {
                CanvasShape(path: MuscleAnatomy.silhouette(orientation))
                    .fill(silhouetteColor.opacity(isFullBody ? 0 : 0.35))
                // Cardio work names no muscle worth pointing at, so the whole
                // figure carries the tint instead of nothing lighting up.
                if isFullBody {
                    CanvasShape(path: MuscleAnatomy.silhouette(orientation))
                        .fill(primaryColor.opacity(0.35))
                }
                ForEach(drawnRegions(orientation)) { drawn in
                    CanvasShape(path: drawn.path)
                        .fill(color(for: drawn.emphasis))
                }
            }
            .aspectRatio(MuscleAnatomy.canvas.width / MuscleAnatomy.canvas.height, contentMode: .fit)

            if showsLabels {
                Text(orientation.displayName)
                    .font(labelFont)
                    .tracking(0.6)
                    .foregroundColor(.aura.text3)
            }
        }
    }

    /// Secondaries first so a primary always wins the overlap where two regions
    /// share pixels (traps under upper back, obliques under lats).
    private func drawnRegions(_ orientation: MuscleMapOrientation) -> [DrawnRegion] {
        guard !isFullBody else { return [] }
        let order: [MuscleEmphasis] = [.secondary, .primary]
        return order.flatMap { emphasis in
            MuscleRegion.allCases.compactMap { region -> DrawnRegion? in
                guard highlights[region] == emphasis,
                      let path = MuscleAnatomy.region(region, orientation)
                else { return nil }
                return DrawnRegion(region: region, emphasis: emphasis, path: path)
            }
        }
    }

    private func color(for emphasis: MuscleEmphasis) -> Color {
        switch emphasis {
        case .primary:   return primaryColor.opacity(0.92)
        case .secondary: return secondaryColor.opacity(0.92)
        }
    }

    private var isFullBody: Bool { highlights[.fullBody] != nil }

    // MARK: Accessibility

    private var accessibilityDescription: String {
        if isFullBody { return "Muscle map: full body" }
        let primaries = named(.primary)
        let secondaries = named(.secondary)
        if primaries.isEmpty && secondaries.isEmpty { return "Muscle map: no muscles specified" }
        var parts: [String] = []
        if !primaries.isEmpty { parts.append("primary \(primaries.joined(separator: ", "))") }
        if !secondaries.isEmpty { parts.append("secondary \(secondaries.joined(separator: ", "))") }
        return "Muscle map: " + parts.joined(separator: "; ")
    }

    private func named(_ emphasis: MuscleEmphasis) -> [String] {
        MuscleRegion.allCases
            .filter { highlights[$0] == emphasis && $0 != .fullBody }
            .map { $0.displayName }
    }

    // MARK: Support types

    private struct DrawnRegion: Identifiable {
        let region: MuscleRegion
        let emphasis: MuscleEmphasis
        let path: Path
        var id: MuscleRegion { region }
    }

    /// Scales a path authored in `MuscleAnatomy.canvas` units into the view's
    /// rect, preserving aspect and centring the remainder.
    private struct CanvasShape: Shape {
        let path: Path

        func path(in rect: CGRect) -> Path {
            let canvas = MuscleAnatomy.canvas
            let scale = min(rect.width / canvas.width, rect.height / canvas.height)
            let transform = CGAffineTransform(
                translationX: rect.midX - canvas.width * scale / 2,
                y: rect.midY - canvas.height * scale / 2
            ).scaledBy(x: scale, y: scale)
            return self.path.applying(transform)
        }
    }
}

// MARK: - Catalog-keyed conveniences

extension MuscleMapView {
    /// Keyed straight off a library entry. `musclesTargeted.first` is the primary
    /// target — the same rule `ExerciseDatabase.toExercise` uses for
    /// `Exercise.primaryMuscle`.
    init(
        entry: ExerciseEntry,
        orientations: [MuscleMapOrientation] = [.front, .back],
        showsLabels: Bool = true
    ) {
        self.init(
            highlights: MuscleRegion.highlights(for: entry.musclesTargeted),
            orientations: orientations,
            showsLabels: showsLabels
        )
    }

    /// Keyed off a workout-side exercise, which carries the same label list.
    init(
        exercise: Exercise,
        orientations: [MuscleMapOrientation] = [.front, .back],
        showsLabels: Bool = true
    ) {
        self.init(
            highlights: MuscleRegion.highlights(for: exercise.muscleGroups),
            orientations: orientations,
            showsLabels: showsLabels
        )
    }
}
