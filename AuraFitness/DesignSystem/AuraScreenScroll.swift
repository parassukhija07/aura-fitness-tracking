import SwiftUI

// MARK: - Scroll offset tracking

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// A vertical ScrollView that:
///  • adds bottom clearance so content isn't hidden behind the floating tab bar, and
///  • posts `.auraScroll` ("up"/"down") so the bar can collapse on scroll-down
///    and expand on scroll-up — mirroring the design's `aura:scroll` emitter.
///
/// Use as the root scroll container of a tab screen.
struct AuraScreenScroll<Content: View>: View {
    var bottomClearance: CGFloat = AuraSpacing.tabBarClearance
    @ViewBuilder var content: () -> Content

    @State private var lastOffset: CGFloat = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            content()
                .padding(.bottom, bottomClearance)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("auraScreenScroll")).minY
                        )
                    }
                )
        }
        .coordinateSpace(name: "auraScreenScroll")
        .onPreferenceChange(ScrollOffsetKey.self) { value in
            let delta = value - lastOffset
            // Negative delta = content moved up = user scrolled down.
            if delta < -6 {
                post("down"); lastOffset = value
            } else if delta > 6 {
                post("up"); lastOffset = value
            }
        }
    }

    private func post(_ dir: String) {
        NotificationCenter.default.post(name: .auraScroll, object: nil, userInfo: ["dir": dir])
    }
}
