import SwiftUI

// MARK: - Radius tokens (mirrors aura.css --r-*)
enum AuraRadius {
    static let xs: CGFloat   = 8
    static let sm: CGFloat   = 12
    static let md: CGFloat   = 16
    static let lg: CGFloat   = 22
    static let xl: CGFloat   = 28
    static let pill: CGFloat = 999
}

// MARK: - Spacing tokens (base-4 scale, mirrors aura.css --s1..--s10)
enum AuraSpacing {
    static let s1: CGFloat  = 4
    static let s2: CGFloat  = 8
    static let s3: CGFloat  = 12
    static let s4: CGFloat  = 16
    static let s5: CGFloat  = 20
    static let s6: CGFloat  = 24
    static let s8: CGFloat  = 32
    static let s10: CGFloat = 40
    /// Screen horizontal padding (`.pad` in the design = 20px).
    static let screenPad: CGFloat = 20
    /// Bottom breathing room above the flat in-flow tab bar. The bar now occupies
    /// real layout height (it is a bottom row in ContentView, not a floating
    /// overlay), so content only needs a small gap — not the full bar height that
    /// the design's `position:absolute` `.pad-b: 110px` reserved.
    static let tabBarClearance: CGFloat = 24
}

// MARK: - Shadow tokens (mirrors aura.css --shadow / --shadow-sm)
// Source: `--shadow*` use base oklch(0.4 0.02 70) ≈ #4F463C.
// CSS blur radius is roughly 2× SwiftUI's, so SwiftUI radii are ~half the CSS px.
enum AuraShadowToken {
    static let base = Color(hex: "#4F463C")
}

extension View {
    /// `--shadow-sm`: subtle card/row elevation · `0 1px 2px base/8%`.
    func auraShadowSm() -> some View {
        shadow(color: AuraShadowToken.base.opacity(0.08), radius: 1, x: 0, y: 1)
    }

    /// `--shadow`: elevated / hover surfaces · `0 1px 3px base/6%, 0 8px 24px base/6%`.
    func auraShadow() -> some View {
        shadow(color: AuraShadowToken.base.opacity(0.06), radius: 1.5, x: 0, y: 1)
            .shadow(color: AuraShadowToken.base.opacity(0.06), radius: 12, x: 0, y: 8)
    }
}
