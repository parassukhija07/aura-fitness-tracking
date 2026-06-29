import SwiftUI

// MARK: - Body map (front/back muscle silhouette)
// Port of BodyMap in plan/exercise-detail.jsx. Same viewBox (130×158) scaled to
// a 115×140 frame. Primary muscles fill accent, secondary fill blue.

struct PlanBodyMap: View {
    var primary: [String]
    var secondary: [String]

    private let viewW: CGFloat = 130
    private let viewH: CGFloat = 158
    private let frameW: CGFloat = 115
    private let frameH: CGFloat = 140

    private func fill(_ muscle: String?) -> (color: Color, opacity: Double) {
        guard let muscle else { return (.aura.fill, 0.35) }
        if primary.contains(muscle) { return (.aura.accent, 0.92) }
        if secondary.contains(muscle) { return (.aura.blue, 0.92) }
        return (.aura.fill, 0.35)
    }

    var body: some View {
        Canvas { ctx, size in
            let sx = size.width / viewW
            let sy = size.height / viewH
            func S(_ m: String?) -> (Color, Double) { fill(m) }
            let base: (Color, Double) = (.aura.fill, 0.35)

            // Helpers
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ f: (Color, Double)) {
                let p = Path(roundedRect: CGRect(x: x*sx, y: y*sy, width: w*sx, height: h*sy), cornerRadius: r*sx)
                ctx.fill(p, with: .color(f.0.opacity(f.1)))
            }
            func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ f: (Color, Double)) {
                let p = Path(ellipseIn: CGRect(x: (cx-rx)*sx, y: (cy-ry)*sy, width: rx*2*sx, height: ry*2*sy))
                ctx.fill(p, with: .color(f.0.opacity(f.1)))
            }
            func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ f: (Color, Double)) {
                ellipse(cx, cy, r, r, f)
            }
            func poly(_ pts: [(CGFloat, CGFloat)], _ f: (Color, Double)) {
                var p = Path()
                if let first = pts.first { p.move(to: CGPoint(x: first.0*sx, y: first.1*sy)) }
                for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0*sx, y: pt.1*sy)) }
                p.closeSubpath()
                ctx.fill(p, with: .color(f.0.opacity(f.1)))
            }

            // divider
            var divider = Path()
            divider.move(to: CGPoint(x: 65*sx, y: 4*sy))
            divider.addLine(to: CGPoint(x: 65*sx, y: 150*sy))
            ctx.stroke(divider, with: .color(.aura.separator2), lineWidth: 0.7*sx)

            // ── FRONT ──
            circle(32, 11, 8, base)
            rect(29, 19, 6, 6, 2, base)
            ellipse(18, 29, 9, 7, S("Shoulders"))
            ellipse(46, 29, 9, 7, S("Shoulders"))
            poly([(22,23),(32,20),(42,23),(43,52),(32,55),(21,52)], S("Chest"))
            rect(10, 24, 9, 26, 4, S("Biceps"))
            rect(43, 24, 9, 26, 4, S("Biceps"))
            rect(9, 50, 8, 20, 4, base)
            rect(45, 50, 8, 20, 4, base)
            rect(25, 52, 14, 26, 3, S("Core"))
            poly([(22,78),(32,82),(42,78),(43,88),(32,90),(21,88)], base)
            rect(22, 88, 11, 32, 5, S("Legs"))
            rect(35, 88, 11, 32, 5, S("Legs"))
            rect(22, 122, 10, 24, 4, base)
            rect(35, 122, 10, 24, 4, base)

            // ── BACK ──
            circle(98, 11, 8, base)
            rect(95, 19, 6, 6, 2, base)
            ellipse(84, 29, 9, 7, S("Shoulders"))
            ellipse(112, 29, 9, 7, S("Shoulders"))
            rect(86, 22, 24, 16, 4, S("Back"))
            poly([(86,26),(79,36),(78,60),(86,66)], S("Back"))
            poly([(110,26),(117,36),(118,60),(110,66)], S("Back"))
            rect(76, 24, 9, 26, 4, S("Triceps"))
            rect(111, 24, 9, 26, 4, S("Triceps"))
            rect(75, 50, 8, 20, 4, base)
            rect(113, 50, 8, 20, 4, base)
            rect(91, 50, 14, 22, 3, S("Back"))
            ellipse(94, 86, 9, 10, S("Legs"))
            ellipse(104, 86, 9, 10, S("Legs"))
            rect(89, 94, 11, 32, 5, S("Legs"))
            rect(102, 94, 11, 32, 5, S("Legs"))
            rect(89, 128, 10, 22, 4, base)
            rect(102, 128, 10, 22, 4, base)
        }
        .frame(width: frameW, height: frameH)
        .overlay(alignment: .bottom) {
            HStack(spacing: 0) {
                Text("FRONT").frame(maxWidth: .infinity)
                Text("BACK").frame(maxWidth: .infinity)
            }
            .font(.system(size: 7, weight: .bold))
            .tracking(0.6)
            .foregroundColor(.aura.text3)
        }
    }
}
