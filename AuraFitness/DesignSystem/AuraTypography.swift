import SwiftUI

enum AuraFont {
    static func largeTitleStyle() -> Font {
        .system(size: 30, weight: .heavy, design: .default)
    }
    static func navTitle() -> Font {
        .system(size: 17, weight: .bold)
    }
    static func cardTitle() -> Font {
        .system(size: 22, weight: .heavy)
    }
    static func body() -> Font {
        .system(size: 16, weight: .medium)
    }
    static func bodySmall() -> Font {
        .system(size: 15, weight: .medium)
    }
    static func secondary() -> Font {
        .system(size: 13, weight: .medium)
    }
    static func sectionLabel() -> Font {
        .system(size: 13, weight: .bold)
    }
    static func statNum(size: CGFloat = 24) -> Font {
        .system(size: size, weight: .heavy, design: .default).monospacedDigit()
    }
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
            .tracking(0.5)
            .padding(.top, AuraSpacing.s5)
    }
}

extension View {
    func sectionLabelStyle() -> some View {
        modifier(SectionLabelStyle())
    }
}
