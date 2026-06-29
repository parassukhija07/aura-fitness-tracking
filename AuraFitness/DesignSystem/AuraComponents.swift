import SwiftUI

// MARK: - AuraCard
struct AuraCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        // .card · surface fill, radius lg, 1px separator-2 border, --shadow-sm.
        content
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.lg)
                    .stroke(Color.aura.separator2, lineWidth: 1)
            )
            .auraShadowSm()
    }
}

// MARK: - AuraPrimaryButton
struct AuraPrimaryButton: View {
    let label: String
    var icon: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(label)
                    .font(AuraFont.body())
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.aura.accent)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        }
    }
}

// MARK: - AuraTintedButton
struct AuraTintedButton: View {
    let label: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(label)
                    .font(AuraFont.body())
            }
            .foregroundColor(.aura.accent)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.aura.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        }
    }
}

// MARK: - AuraGrayButton
struct AuraGrayButton: View {
    let label: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                }
                Text(label)
                    .font(AuraFont.body())
            }
            .foregroundColor(.aura.text)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        }
    }
}

// MARK: - AuraDangerButton
struct AuraDangerButton: View {
    let label: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(label)
                    .font(AuraFont.body())
            }
            .foregroundColor(.aura.red)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.aura.red.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        }
    }
}

// MARK: - AuraChip
struct AuraChip: View {
    let label: String
    var active: Bool = false
    var color: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AuraFont.secondary())
                .foregroundColor(active ? .white : .aura.text)
                .padding(.horizontal, AuraSpacing.s3)
                .padding(.vertical, AuraSpacing.s2)
                .background(active ? (color ?? .aura.accent) : .aura.fill)
                .clipShape(Capsule())
        }
    }
}

// MARK: - AuraSegmentedPicker
struct AuraSegmentedPicker: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { opt in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = opt
                    }
                } label: {
                    Text(opt)
                        .font(AuraFont.secondary())
                        .foregroundColor(selection == opt ? .aura.text : .aura.text2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            selection == opt
                                ? AnyShapeStyle(Color.aura.surface
                                    .shadow(.drop(color: .black.opacity(0.08), radius: 1, y: 1)))
                                : AnyShapeStyle(Color.clear)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm - 2))
                }
            }
        }
        .padding(4)
        .background(Color.aura.fill)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
    }
}

// MARK: - AuraBadge
struct AuraBadge: View {
    let label: String
    var color: Color = .aura.accent

    var body: some View {
        Text(label)
            .font(AuraFont.badge())
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - AuraSectionLabel
struct AuraSectionLabel: View {
    let title: String
    var body: some View {
        Text(title)
            .sectionLabelStyle()
    }
}

// MARK: - AuraProgressBar
struct AuraProgressBar: View {
    let value: Double  // 0.0 – 1.0
    var color: Color = .aura.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.aura.track)
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(max(0, min(1, value))), height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - AuraToggle
struct AuraToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(AuraToggleStyle())
    }
}

struct AuraToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Capsule()
                .fill(configuration.isOn ? Color.aura.green : Color.aura.track)
                .frame(width: 51, height: 31)
            Circle()
                .fill(Color.white)
                .frame(width: 27, height: 27)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                .offset(x: configuration.isOn ? 10 : -10)
                .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
        }
        .onTapGesture { configuration.isOn.toggle() }
    }
}

// MARK: - AuraListRow
struct AuraListRow: View {
    var iconName: String? = nil
    var iconColor: Color = .aura.accent
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true
    var trailingText: String? = nil
    let action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AuraSpacing.s3) {
                if let icon = iconName {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(iconColor)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text)
                    if let sub = subtitle {
                        Text(sub)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                    }
                }
                Spacer()
                if let trailing = trailingText {
                    Text(trailing)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.aura.text3)
                }
            }
            .padding(.vertical, 12)
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AuraSheet helper modifier
struct AuraSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let sheetContent: () -> SheetContent

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                sheetContent()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func auraSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(AuraSheetModifier(isPresented: isPresented, sheetContent: content))
    }
}

// MARK: - Toast (flash)
/// Pill toast that auto-dismisses. Mirrors the prototype `flash(m)` helper.
final class ToastCenter: ObservableObject {
    @Published var message: String? = nil
    private var token = 0
    func flash(_ m: String) {
        message = m
        token += 1
        let mine = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.token == mine else { return }
            self.message = nil
        }
    }
}

struct ToastOverlay: View {
    let message: String?
    var body: some View {
        if let message {
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.aura.bg)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.aura.text)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.22), radius: 12, y: 8)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Overlays an auto-dismissing toast pill driven by a ToastCenter.
    func auraToast(_ center: ToastCenter) -> some View {
        overlay(ToastOverlay(message: center.message).animation(.easeInOut(duration: 0.2), value: center.message))
    }
}

// MARK: - Grabber
struct SheetGrabber: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.aura.text3.opacity(0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

// MARK: - AuraStepper
/// Pill stepper: − [value] + with min/max clamping and an optional value formatter.
/// Mirrors `Stepper` from ui.jsx (used across Workout settings).
struct AuraStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 1...99
    var step: Int = 1
    var format: ((Int) -> String)? = nil

    private var display: String { format?(value) ?? "\(value)" }
    private var canDec: Bool { value - step >= range.lowerBound }
    private var canInc: Bool { value + step <= range.upperBound }

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", enabled: canDec) {
                value = max(range.lowerBound, value - step)
            }
            Text(display)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.aura.text)
                .frame(minWidth: 64)
                .monospacedDigit()
            stepButton("plus", enabled: canInc) {
                value = min(range.upperBound, value + step)
            }
        }
        .background(Color.aura.fill)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func stepButton(_ symbol: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(enabled ? .aura.text : .aura.text3)
                .frame(width: 36, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Stat tile
struct StatTile: View {
    let value: String
    let label: String
    var color: Color = .aura.text

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AuraFont.statNum(size: 22))
                .foregroundColor(color)
            Text(label)
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AuraSpacing.s3)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
    }
}
