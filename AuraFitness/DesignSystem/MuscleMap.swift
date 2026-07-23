import SwiftUI

// MARK: - MuscleMapOrientation

/// Which side of the body a panel draws. Every region declares the orientations
/// it is visible from, so a "Lats" exercise lights up the back panel and leaves
/// the front one clean rather than inventing a front-facing lat blob.
enum MuscleMapOrientation: String, CaseIterable, Hashable {
    case front
    case back

    var displayName: String {
        switch self {
        case .front: return "FRONT"
        case .back:  return "BACK"
        }
    }
}

// MARK: - MuscleRegion

/// The canonical muscle vocabulary the body map can draw.
///
/// The catalog's `musclesTargeted` strings are NOT this vocabulary — the MIT
/// dataset ships 50 distinct labels with heavy synonymy ("Quads"/"Quadriceps",
/// "Delts"/"Deltoids"/"Shoulders", "Abs"/"Abdominals"/"Core"). `regions(matching:)`
/// collapses those onto the regions below; nothing else in the app should try to
/// interpret the raw strings for drawing purposes.
enum MuscleRegion: String, CaseIterable, Hashable {
    case neck
    case traps
    case shoulders
    case rearDelts
    case chest
    case lats
    case upperBack
    case lowerBack
    case biceps
    case triceps
    case forearms
    case abs
    case obliques
    case glutes
    case quads
    case hamstrings
    case adductors
    case abductors
    case calves
    /// Not a drawable region: cardio work that loads everything and nothing.
    /// `MuscleMapView` renders it as a tinted whole silhouette.
    case fullBody

    var displayName: String {
        switch self {
        case .neck:       return "Neck"
        case .traps:      return "Traps"
        case .shoulders:  return "Shoulders"
        case .rearDelts:  return "Rear Delts"
        case .chest:      return "Chest"
        case .lats:       return "Lats"
        case .upperBack:  return "Upper Back"
        case .lowerBack:  return "Lower Back"
        case .biceps:     return "Biceps"
        case .triceps:    return "Triceps"
        case .forearms:   return "Forearms"
        case .abs:        return "Abs"
        case .obliques:   return "Obliques"
        case .glutes:     return "Glutes"
        case .quads:      return "Quads"
        case .hamstrings: return "Hamstrings"
        case .adductors:  return "Adductors"
        case .abductors:  return "Abductors"
        case .calves:     return "Calves"
        case .fullBody:   return "Full Body"
        }
    }
}

// MARK: - Emphasis

/// Primary target vs. supporting mover. Mirrors `ExerciseDatabase.toExercise`,
/// which already treats `musclesTargeted.first` as the primary muscle — the map
/// must not disagree with the label shown next to it.
enum MuscleEmphasis: Hashable {
    case primary
    case secondary
}

// MARK: - Label normalisation

extension MuscleRegion {
    /// Regions for one raw catalog label. Empty means "nothing to draw" — an
    /// unrecognised label is a normal outcome (custom exercises let users type
    /// anything), never an error.
    static func regions(matching raw: String) -> [MuscleRegion] {
        let key = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return [] }
        if let exact = aliases[key] { return exact }
        // Fall back to containment for labels outside the shipped vocabulary
        // ("mid back", "front delts", …). Longest alias first so "lower back"
        // is never shadowed by "back".
        for alias in aliasesByLengthDescending where key.contains(alias) {
            return aliases[alias] ?? []
        }
        return []
    }

    /// Highlights for a whole exercise. Index 0 is the primary target; a region
    /// reached by both a primary and a secondary label stays primary.
    static func highlights(for labels: [String]) -> [MuscleRegion: MuscleEmphasis] {
        var result: [MuscleRegion: MuscleEmphasis] = [:]
        for (index, label) in labels.enumerated() {
            let emphasis: MuscleEmphasis = index == 0 ? .primary : .secondary
            for region in regions(matching: label) where result[region] != .primary {
                result[region] = emphasis
            }
        }
        return result
    }

    /// Highlights from pre-bucketed label lists (the shape `PlanExerciseDetailData`
    /// already stores). Primary wins wherever the two lists overlap.
    static func highlights(primary: [String], secondary: [String]) -> [MuscleRegion: MuscleEmphasis] {
        var result: [MuscleRegion: MuscleEmphasis] = [:]
        for label in secondary {
            for region in regions(matching: label) { result[region] = .secondary }
        }
        for label in primary {
            for region in regions(matching: label) { result[region] = .primary }
        }
        return result
    }

    /// Full synonym table for the 50 labels in `gym_exercise_library.json`, plus
    /// the coarse tokens `PlanExerciseDetailData` uses and the obvious near-misses
    /// a hand-typed custom exercise produces.
    private static let aliases: [String: [MuscleRegion]] = [
        // Neck
        "neck": [.neck],
        "sternocleidomastoid": [.neck],
        "levator scapulae": [.traps, .neck],
        // Shoulders / traps
        "shoulders": [.shoulders],
        "delts": [.shoulders],
        "deltoids": [.shoulders],
        "front delts": [.shoulders],
        "side delts": [.shoulders],
        "rear deltoids": [.rearDelts],
        "rear delts": [.rearDelts],
        "rotator cuff": [.shoulders, .rearDelts],
        "traps": [.traps],
        "trapezius": [.traps],
        // Chest
        "chest": [.chest],
        "pectorals": [.chest],
        "pecs": [.chest],
        "upper chest": [.chest],
        "lower chest": [.chest],
        "serratus anterior": [.obliques],
        // Back
        "back": [.upperBack, .lats],
        "upper back": [.upperBack],
        "rhomboids": [.upperBack],
        "lats": [.lats],
        "latissimus dorsi": [.lats],
        "lower back": [.lowerBack],
        "erector spinae": [.lowerBack],
        "spine": [.lowerBack],
        // Arms
        "arms": [.biceps, .triceps],
        "biceps": [.biceps],
        "brachialis": [.biceps],
        "triceps": [.triceps],
        "forearms": [.forearms],
        "wrists": [.forearms],
        "wrist flexors": [.forearms],
        "wrist extensors": [.forearms],
        "hands": [.forearms],
        "grip muscles": [.forearms],
        "grip": [.forearms],
        // Trunk
        "abs": [.abs],
        "abdominals": [.abs],
        "lower abs": [.abs],
        "upper abs": [.abs],
        "core": [.abs, .obliques],
        "obliques": [.obliques],
        // Hips / legs
        "legs": [.quads, .hamstrings, .glutes],
        "glutes": [.glutes],
        "hip flexors": [.quads],
        "quads": [.quads],
        "quadriceps": [.quads],
        "hamstrings": [.hamstrings],
        "adductors": [.adductors],
        "inner thighs": [.adductors],
        "groin": [.adductors],
        "abductors": [.abductors],
        "calves": [.calves],
        "soleus": [.calves],
        "shins": [.calves],
        "ankles": [.calves],
        "ankle stabilizers": [.calves],
        "feet": [.calves],
        // Whole-body
        "cardio": [.fullBody],
        "cardiovascular system": [.fullBody],
        "full body": [.fullBody]
    ]

    private static let aliasesByLengthDescending: [String] =
        aliases.keys.sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs < rhs : lhs.count > rhs.count
        }
}

// MARK: - MuscleAnatomy

/// Stylised human figure, authored as vector paths in a fixed 100 × 200 canvas.
///
/// Geometry in code rather than an image asset: it recolours per region, scales
/// to any size without a second asset, adds nothing to the bundle, and carries no
/// third-party licence — see THIRD_PARTY_NOTICES.md, where the dataset's rendered
/// exercise imagery is deliberately absent. This fills the hole that leaves in
/// the UI without going near the imagery that was carved out.
///
/// The figure is symmetric about x = 50, so paired muscles are authored once for
/// the left side and mirrored.
enum MuscleAnatomy {
    static let canvas = CGSize(width: 100, height: 200)

    // MARK: Silhouette

    /// Body outline. Assembled from overlapping primitives filled as one path —
    /// they union visually because the whole silhouette draws in a single colour.
    static func silhouette(_ orientation: MuscleMapOrientation) -> Path {
        // Front and back share the outline; only the muscles on top differ.
        _ = orientation
        var path = Path()
        // Head + neck
        path.addEllipse(in: CGRect(x: 41.5, y: 4, width: 17, height: 21))
        path.addRoundedRect(in: CGRect(x: 44.5, y: 20, width: 11, height: 14),
                            cornerSize: CGSize(width: 4, height: 4))
        path.addPath(torso)
        // Arms: shoulder → elbow → wrist, plus a hand cap.
        path.addPath(paired(limb(from: pt(29, 40), to: pt(21.5, 80), width: 11)))
        path.addPath(paired(limb(from: pt(21.5, 80), to: pt(16, 114), width: 8.5)))
        path.addPath(paired(ellipse(cx: 15, cy: 118, rx: 5, ry: 6)))
        // Legs: hip → knee → ankle, plus a foot cap.
        path.addPath(paired(limb(from: pt(42.5, 108), to: pt(39, 156), width: 16)))
        path.addPath(paired(limb(from: pt(39, 156), to: pt(37.5, 189), width: 10.5)))
        path.addPath(paired(ellipse(cx: 36.5, cy: 191, rx: 6, ry: 4.5)))
        return path
    }

    /// Shoulders-to-hips trunk, authored as one closed curve (left half then
    /// right half) so the waist taper stays smooth.
    private static var torso: Path {
        var path = Path()
        path.move(to: pt(50, 29))
        path.addCurve(to: pt(31, 41), control1: pt(41, 29), control2: pt(35, 33))
        path.addCurve(to: pt(38, 76), control1: pt(28, 54), control2: pt(36, 68))
        path.addCurve(to: pt(36, 112), control1: pt(39, 90), control2: pt(35, 101))
        path.addLine(to: pt(64, 112))
        path.addCurve(to: pt(62, 76), control1: pt(65, 101), control2: pt(61, 90))
        path.addCurve(to: pt(69, 41), control1: pt(64, 68), control2: pt(72, 54))
        path.addCurve(to: pt(50, 29), control1: pt(65, 33), control2: pt(59, 29))
        path.closeSubpath()
        return path
    }

    // MARK: Regions

    /// The shape for one region on one side of the body, or `nil` when that
    /// region is not visible from that side (chest from the back, lats from the
    /// front, …). Callers skip `nil` rather than substituting anything.
    static func region(_ region: MuscleRegion, _ orientation: MuscleMapOrientation) -> Path? {
        switch orientation {
        case .front: return frontRegion(region)
        case .back:  return backRegion(region)
        }
    }

    private static func frontRegion(_ region: MuscleRegion) -> Path? {
        switch region {
        case .neck:
            return paired(limb(from: pt(47, 23), to: pt(46, 32), width: 4.5))
        case .traps:
            return paired(limb(from: pt(46.5, 32), to: pt(37, 39), width: 6))
        case .shoulders:
            return paired(ellipse(cx: 30.5, cy: 41, rx: 7, ry: 7.5))
        case .chest:
            return paired(rounded(x: 36, y: 41, w: 13, h: 19, r: 5.5))
        case .biceps:
            return paired(limb(from: pt(28, 48), to: pt(22.5, 73), width: 8))
        case .forearms:
            return paired(limb(from: pt(21, 84), to: pt(16.5, 112), width: 7))
        case .abs:
            return rounded(x: 44, y: 58, w: 12, h: 36, r: 5)
        case .obliques:
            return paired(rounded(x: 38, y: 60, w: 5.5, h: 30, r: 2.75))
        case .abductors:
            return paired(limb(from: pt(35.5, 112), to: pt(34.5, 132), width: 5.5))
        case .quads:
            return paired(limb(from: pt(43, 112), to: pt(40, 152), width: 12))
        case .adductors:
            return paired(limb(from: pt(47.5, 113), to: pt(45.5, 145), width: 5))
        case .calves:
            // Front view shows the shin (tibialis), not the gastroc.
            return paired(limb(from: pt(38.5, 160), to: pt(37.5, 186), width: 7))
        case .lats, .upperBack, .lowerBack, .rearDelts, .triceps, .glutes, .hamstrings, .fullBody:
            return nil
        }
    }

    private static func backRegion(_ region: MuscleRegion) -> Path? {
        switch region {
        case .neck:
            return paired(limb(from: pt(47, 23), to: pt(46.5, 32), width: 4.5))
        case .traps:
            return trapsYoke
        case .shoulders:
            return paired(ellipse(cx: 30.5, cy: 41, rx: 7, ry: 7.5))
        case .rearDelts:
            return paired(ellipse(cx: 30.5, cy: 42, rx: 6, ry: 6.5))
        case .upperBack:
            return rounded(x: 39, y: 47, w: 22, h: 17, r: 5)
        case .lats:
            return paired(latWedge)
        case .lowerBack:
            return rounded(x: 41, y: 78, w: 18, h: 18, r: 6)
        case .obliques:
            return paired(rounded(x: 38, y: 62, w: 5, h: 26, r: 2.5))
        case .triceps:
            return paired(limb(from: pt(27.5, 47), to: pt(22, 74), width: 8))
        case .forearms:
            return paired(limb(from: pt(21, 84), to: pt(16.5, 112), width: 7))
        case .glutes:
            return paired(ellipse(cx: 43.5, cy: 108, rx: 7, ry: 8.5))
        case .abductors:
            return paired(limb(from: pt(35.5, 112), to: pt(34.5, 132), width: 5.5))
        case .hamstrings:
            return paired(limb(from: pt(43, 118), to: pt(40, 152), width: 12))
        case .adductors:
            return paired(limb(from: pt(47.5, 116), to: pt(45.5, 145), width: 5))
        case .calves:
            return paired(limb(from: pt(38.5, 157), to: pt(37.5, 184), width: 8.5))
        case .chest, .biceps, .abs, .quads, .fullBody:
            return nil
        }
    }

    /// Upper trapezius: centred, spans both sides, so it is authored whole. A
    /// yoke from the base of the neck out to the shoulder tips and back down to
    /// a point between the shoulder blades.
    private static var trapsYoke: Path {
        polygon([pt(44, 30), pt(56, 30), pt(64, 44), pt(55, 62), pt(50, 66), pt(45, 62), pt(36, 44)])
    }

    /// One latissimus: broad under the armpit, tapering into the waist. The
    /// outer edge stays inside the torso curve — a lat that spills past the
    /// flank reads as a rendering bug, not as a wide back.
    private static var latWedge: Path {
        polygon([pt(34, 46), pt(42, 47), pt(46, 78), pt(39, 82), pt(35.5, 62)])
    }

    // MARK: Primitives

    private static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x, y: y)
    }

    /// A capsule laid along a segment — the workhorse for arms, legs and most
    /// long muscles. Authored vertically at the origin, then rotated onto the
    /// segment and translated to its midpoint.
    private static func limb(from a: CGPoint, to b: CGPoint, width: CGFloat) -> Path {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let angle = atan2(dy, dx) - .pi / 2
        var path = Path()
        path.addRoundedRect(in: CGRect(x: -width / 2, y: -length / 2, width: width, height: length),
                            cornerSize: CGSize(width: width / 2, height: width / 2))
        let placement = CGAffineTransform(translationX: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            .rotated(by: angle)
        return path.applying(placement)
    }

    private static func polygon(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }

    private static func rounded(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat) -> Path {
        var path = Path()
        path.addRoundedRect(in: CGRect(x: x, y: y, width: w, height: h),
                            cornerSize: CGSize(width: r, height: r))
        return path
    }

    private static func ellipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        return path
    }

    /// Left-side shape + its reflection about the canvas centre line (x' = 100 − x).
    private static func paired(_ path: Path) -> Path {
        var combined = path
        combined.addPath(path.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1,
                                                         tx: canvas.width, ty: 0)))
        return combined
    }
}
