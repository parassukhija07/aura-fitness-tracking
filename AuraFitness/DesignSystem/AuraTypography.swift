import SwiftUI

/// Aura type scale.
///
/// Source of truth: `styles/aura.css` in the design package. The prototype ships
/// **Plus Jakarta Sans**; we now bundle the five static instances (Regular/Medium/
/// SemiBold/Bold/ExtraBold — see `AuraFitness/Fonts/`) and register them via
/// `INFOPLIST_KEY_UIAppFonts`, so native type matches the design exactly rather
/// than substituting SF Pro. Letter-spacing values are converted from the CSS
/// `em` tracking at each size (em × pointSize = tracking in points).
enum AuraFont {
    // MARK: Face names (PostScript names of the bundled instances)
    enum Face {
        static let regular   = "PlusJakartaSans-Regular"    // 400
        static let medium    = "PlusJakartaSans-Medium"     // 500
        static let semibold  = "PlusJakartaSans-SemiBold"   // 600
        static let bold      = "PlusJakartaSans-Bold"       // 700
        static let extrabold = "PlusJakartaSans-ExtraBold"  // 800
    }

    /// Map a SwiftUI weight onto the closest bundled Jakarta face.
    static func face(for weight: Font.Weight) -> String {
        switch weight {
        case .regular, .light, .thin, .ultraLight: return Face.regular
        case .medium:                              return Face.medium
        case .semibold:                            return Face.semibold
        case .bold:                                return Face.bold
        case .heavy, .black:                       return Face.extrabold
        default:                                   return Face.regular
        }
    }

    /// Plus Jakarta Sans at an explicit size + weight-mapped face.
    static func jakarta(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .custom(face(for: weight), fixedSize: size)
    }

    /// Large title · 30 / 800 / −.02em — tab top titles.
    static func largeTitleStyle() -> Font { .custom(Face.extrabold, fixedSize: 30) }
    static let largeTitleTracking: CGFloat = -0.6  // -0.02em × 30

    /// Nav title · 17 / 700 — pushed-screen & sheet titles.
    static func navTitle() -> Font { .custom(Face.bold, fixedSize: 17) }
    static let navTitleTracking: CGFloat = -0.17  // -0.01em × 17

    /// Card title · 22–24 / 800 / −.02em — workout/exercise name.
    static func cardTitle(size: CGFloat = 22) -> Font { .custom(Face.extrabold, fixedSize: size) }
    static func cardTitleTracking(size: CGFloat = 22) -> CGFloat { -0.02 * size }

    /// Body · 16 / 500 — list rows, items.
    static func body() -> Font { .custom(Face.medium, fixedSize: 16) }
    /// Body (compact) · 15 / 500.
    static func bodySmall() -> Font { .custom(Face.medium, fixedSize: 15) }
    /// Secondary · 12.5–13 / 500 — meta, subtitles (`--text-2`).
    static func secondary() -> Font { .custom(Face.medium, fixedSize: 13) }
    /// Section label · 13 / 700 / UPPER / +.02em (`--text-3`).
    static func sectionLabel() -> Font { .custom(Face.bold, fixedSize: 13) }
    static let sectionLabelTracking: CGFloat = 0.26  // +0.02em × 13

    /// Stat number · 18–32 / 800 / tabular / −.03em — timers, weights, totals.
    static func statNum(size: CGFloat = 24) -> Font {
        .custom(Face.extrabold, fixedSize: size).monospacedDigit()
    }
    static func tiny() -> Font { .custom(Face.medium, fixedSize: 11) }
    static func statNumTracking(size: CGFloat = 24) -> CGFloat { -0.03 * size }

    /// Badge · 12 / 700 / +.01em.
    static func badge() -> Font { .custom(Face.bold, fixedSize: 12) }
}

// MARK: - View modifiers
struct SectionLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(AuraFont.sectionLabel())
            .foregroundColor(.aura.text3)
            .textCase(.uppercase)
            .tracking(AuraFont.sectionLabelTracking)
            .padding(.top, AuraSpacing.s5)
    }
}

extension View {
    func sectionLabelStyle() -> some View {
        modifier(SectionLabelStyle())
    }
}
