import SwiftUI

/// Aura type scale.
///
/// Source of truth: `.design-import/styles/aura.css`. The prototype ships
/// Plus Jakarta Sans; on native we substitute SF Pro (the system font) per the
/// handoff — layouts tolerate it. Letter-spacing values are converted from the
/// CSS `em` tracking at each size (em × pointSize = tracking in points).
enum AuraFont {
    /// Large title · 30 / 800 / −.02em — tab top titles.
    static func largeTitleStyle() -> Font {
        .system(size: 30, weight: .heavy)
    }
    static let largeTitleTracking: CGFloat = -0.6  // -0.02em × 30

    /// Nav title · 17 / 700 — pushed-screen & sheet titles.
    static func navTitle() -> Font {
        .system(size: 17, weight: .bold)
    }
    static let navTitleTracking: CGFloat = -0.17  // -0.01em × 17

    /// Card title · 22–24 / 800 / −.02em — workout/exercise name.
    static func cardTitle(size: CGFloat = 22) -> Font {
        .system(size: size, weight: .heavy)
    }
    static func cardTitleTracking(size: CGFloat = 22) -> CGFloat { -0.02 * size }

    /// Body · 16 / 500 — list rows, items.
    static func body() -> Font {
        .system(size: 16, weight: .medium)
    }
    /// Body (compact) · 15 / 500.
    static func bodySmall() -> Font {
        .system(size: 15, weight: .medium)
    }
    /// Secondary · 12.5–13 / 500 — meta, subtitles (`--text-2`).
    static func secondary() -> Font {
        .system(size: 13, weight: .medium)
    }
    /// Section label · 13 / 700 / UPPER / +.02em (`--text-3`).
    static func sectionLabel() -> Font {
        .system(size: 13, weight: .bold)
    }
    static let sectionLabelTracking: CGFloat = 0.26  // +0.02em × 13

    /// Stat number · 18–32 / 800 / tabular / −.03em — timers, weights, totals.
    static func statNum(size: CGFloat = 24) -> Font {
        .system(size: size, weight: .heavy).monospacedDigit()
    }
    static func tiny() -> Font {
        .system(size: 11, weight: .medium)
    }
    static func statNumTracking(size: CGFloat = 24) -> CGFloat { -0.03 * size }

    /// Badge · 12 / 700 / +.01em.
    static func badge() -> Font {
        .system(size: 12, weight: .bold)
    }
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
