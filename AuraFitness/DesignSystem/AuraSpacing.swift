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
    /// Bottom padding so content clears the floating glass tab bar (`.pad-b`).
    static let tabBarClearance: CGFloat = 110
}

// MARK: - Shadow tokens (mirrors aura.css --shadow / --shadow-sm)
struct AuraShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    /// --shadow-sm: subtle card/row elevation.
    func auraShadowSm() -> some View {
        shadow(color: Color(red: 0.25, green: 0.16, blue: 0.08).opacity(0.08), radius: 2, x: 0, y: 1)
    }

    /// --shadow: elevated / hover surfaces.
    func auraShadow() -> some View {
        shadow(color: Color(red: 0.25, green: 0.13, blue: 0.05).opacity(0.06), radius: 3, x: 0, y: 1)
            .shadow(color: Color(red: 0.25, green: 0.13, blue: 0.05).opacity(0.06), radius: 12, x: 0, y: 8)
    }
}
