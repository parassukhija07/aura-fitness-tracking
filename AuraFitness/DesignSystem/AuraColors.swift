import SwiftUI
import UIKit

extension Color {
    static let aura = AuraColorNamespace()
}

/// Aura colour tokens.
///
/// Source of truth: `.design-import/styles/aura.css`, authored in **OKLCH**.
/// The hex values below are the math-accurate sRGB conversions of those OKLCH
/// tokens (light = `:root`, dark = `[data-theme="dark"]`). Do not hand-tune
/// these — regenerate from the OKLCH source if the design changes.
struct AuraColorNamespace {
    // MARK: - Accent (warm amber — shared chroma/lightness family)
    /// `--accent` · oklch(.70 .17 60) / dark oklch(.76 .17 65)
    var accent: Color {
        dyn(light: "#E88000", dark: "#F99603")
    }
    /// `--accent-press` · oklch(.64 .17 60) / dark oklch(.70 .17 65)
    var accentPress: Color {
        dyn(light: "#D46D00", dark: "#E48300")
    }
    /// `--accent-soft` · accent @ 12% (light) / 18% (dark)
    var accentSoft: Color {
        dynA(light: "#E88000", lightA: 0.12, dark: "#F99603", darkA: 0.18)
    }
    /// `--on-accent` · text colour drawn on top of an accent fill.
    var onAccent: Color { .white }

    // MARK: - Semantic accents (same chroma/lightness, varied hue)
    /// `--green` · done · oklch(.70 .15 150)
    var green: Color  { Color(hex: "#4CB86A") }
    /// `--red` · destroy · oklch(.64 .19 25)
    var red: Color    { Color(hex: "#E9504D") }
    /// `--blue` · info · oklch(.66 .14 250)
    var blue: Color   { Color(hex: "#4697E4") }
    /// `--purple` · drop-set/special · oklch(.62 .15 300)
    var purple: Color { Color(hex: "#956ED2") }

    // MARK: - Backgrounds
    /// `--bg` · screen background
    var bg: Color {
        dyn(light: "#FBFAF7", dark: "#0E0C0A")
    }
    /// `--bg-grouped` · grouped/list background
    var bgGrouped: Color {
        dyn(light: "#F5F3F0", dark: "#080605")
    }
    /// `--surface` · cards
    var surface: Color {
        dyn(light: "#FFFFFF", dark: "#191714")
    }
    /// `--surface-2` · inset fields
    var surface2: Color {
        dyn(light: "#F8F6F4", dark: "#201E1B")
    }
    /// `--elevated` · raised surfaces (sheets, popovers)
    var elevated: Color {
        dyn(light: "#FFFFFF", dark: "#201E1B")
    }

    // MARK: - Text ramp
    /// `--text` · primary
    var text: Color {
        dyn(light: "#1A1510", dark: "#F6F5F2")
    }
    /// `--text-2` · secondary
    var text2: Color {
        dyn(light: "#6E6862", dark: "#A39D96")
    }
    /// `--text-3` · tertiary
    var text3: Color {
        dyn(light: "#96918C", dark: "#76716A")
    }

    // MARK: - Dividers / fills / track
    /// `--separator` · strong divider
    var separator: Color {
        dyn(light: "#E0DDDA", dark: "#353230")
    }
<<<<<<< HEAD
    var separator2: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.27, green: 0.255, blue: 0.235, alpha: 1) // oklch(0.27 0.006 70)
                : UIColor(red: 0.93, green: 0.922, blue: 0.912, alpha: 1) // oklch(0.93 0.004 70)
        }))
    }
=======
    /// `--separator-2` · hairline divider
    var separator2: Color {
        dyn(light: "#EAE7E5", dark: "#282623")
    }
    /// `--fill` · neutral fill (chips, icon bg) · base @ 12% (light) / 16% (dark)
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
    var fill: Color {
        dynA(light: "#A9A49E", lightA: 0.12, dark: "#B2ADA7", darkA: 0.16)
    }
<<<<<<< HEAD
    var fill2: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.75, green: 0.74, blue: 0.73, alpha: 0.10) // oklch(0.75 0.01 75 / 0.10)
                : UIColor(red: 0.72, green: 0.71, blue: 0.695, alpha: 0.08) // oklch(0.72 0.01 70 / 0.08)
        }))
    }
=======
    /// `--fill-2` · subtler neutral fill · base @ 8% (light) / 10% (dark)
    var fill2: Color {
        dynA(light: "#A9A49E", lightA: 0.08, dark: "#B2ADA7", darkA: 0.10)
    }
    /// `--track` · progress/timer track
>>>>>>> 91e379ec4685afd991790ab0373badd82d02b753
    var track: Color {
        dyn(light: "#DAD7D3", dark: "#302D2B")
    }

    // MARK: - Scrim
    /// `--scrim` · sheet/overlay dim · text-dark @ 40% (light) / #000 @ ~67% (dark)
    var scrim: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor.black.withAlphaComponent(0.667)
                : UIColor(hex: "#1A1510").withAlphaComponent(0.40)
        }))
    }
}

// MARK: - Dynamic helpers
private func dyn(light: String, dark: String) -> Color {
    Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    }))
}

private func dynA(light: String, lightA: CGFloat, dark: String, darkA: CGFloat) -> Color {
    Color(UIColor(dynamicProvider: { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: dark).withAlphaComponent(darkA)
            : UIColor(hex: light).withAlphaComponent(lightA)
    }))
}

// MARK: - UIColor hex init
extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >>  8) & 0xFF) / 255
        let b = CGFloat( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    init(hex: String) {
        self.init(UIColor(hex: hex))
    }
}
