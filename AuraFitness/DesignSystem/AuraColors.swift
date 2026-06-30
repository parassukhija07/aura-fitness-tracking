import SwiftUI
import UIKit

extension Color {
    static let aura = AuraColorNamespace()
}

struct AuraColorNamespace {
    // MARK: - Accent
    var accent: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#F59331")
                : UIColor(hex: "#E07A1F")
        }))
    }
    var accentPress: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#E07A1F")
                : UIColor(hex: "#C4650F")
        }))
    }
    var accentSoft: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#F59331").withAlphaComponent(0.18)
                : UIColor(hex: "#E07A1F").withAlphaComponent(0.12)
        }))
    }

    // MARK: - Semantic
    var green: Color  { Color(hex: "#2DA66A") }
    var red: Color    { Color(hex: "#D8432E") }
    var blue: Color   { Color(hex: "#3E83D4") }
    var purple: Color { Color(hex: "#9354C9") }

    // MARK: - Backgrounds
    var bg: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#1E1C1A")
                : UIColor(hex: "#FCFBFA")
        }))
    }
    var bgGrouped: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#181614")
                : UIColor(hex: "#F5F3F1")
        }))
    }
    var surface: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#2A2724")
                : UIColor.white
        }))
    }
    var surface2: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#302D2A")
                : UIColor(hex: "#F8F7F6")
        }))
    }

    // MARK: - Text
    var text: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#F7F5F3")
                : UIColor(hex: "#2E2A26")
        }))
    }
    var text2: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#AEA89F")
                : UIColor(hex: "#7C746C")
        }))
    }
    var text3: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#706860")
                : UIColor(hex: "#A39A91")
        }))
    }

    // MARK: - Misc
    var separator: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#4A4540")
                : UIColor(hex: "#E5E2DF")
        }))
    }
    var separator2: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.27, green: 0.255, blue: 0.235, alpha: 1) // oklch(0.27 0.006 70)
                : UIColor(red: 0.93, green: 0.922, blue: 0.912, alpha: 1) // oklch(0.93 0.004 70)
        }))
    }
    var fill: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#F7F5F3").withAlphaComponent(0.16)
                : UIColor(hex: "#2E2A26").withAlphaComponent(0.12)
        }))
    }
    var fill2: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(red: 0.75, green: 0.74, blue: 0.73, alpha: 0.10) // oklch(0.75 0.01 75 / 0.10)
                : UIColor(red: 0.72, green: 0.71, blue: 0.695, alpha: 0.08) // oklch(0.72 0.01 70 / 0.08)
        }))
    }
    var track: Color {
        Color(UIColor(dynamicProvider: { t in
            t.userInterfaceStyle == .dark
                ? UIColor(hex: "#3D3833")
                : UIColor(hex: "#DED9D4")
        }))
    }
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
