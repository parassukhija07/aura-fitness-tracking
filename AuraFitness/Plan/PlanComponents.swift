import SwiftUI

// MARK: - Shared Plan-tab building blocks
//
// Mirrors the small reusable pieces in plan/app.jsx: Sheet wrapper, Row helper,
// source cards, RestPicker, WeekStrip, search field, catalog grid + a hand-built
// back-navbar matching the Log tab's pixel-faithful style.

// MARK: Back navbar (full-screen pushes)

struct PlanNavbar<Trailing: View>: View {
    var title: String? = nil
    var backLabel: String? = nil
    var onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(AuraFont.jakarta(20, .semibold))
                    if let backLabel {
                        Text(backLabel).font(AuraFont.jakarta(17, .regular))
                    }
                }
                .foregroundColor(.aura.accent)
            }
            Spacer()
            if let title {
                Text(title)
                    .font(AuraFont.navTitle())
                    .foregroundColor(.aura.text)
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.top, AuraSpacing.s1)
        .padding(.bottom, AuraSpacing.s2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.aura.separator2).frame(height: 1)
        }
    }
}

extension PlanNavbar where Trailing == EmptyView {
    init(title: String? = nil, backLabel: String? = nil, onBack: @escaping () -> Void) {
        self.init(title: title, backLabel: backLabel, onBack: onBack, trailing: { EmptyView() })
    }
}

// MARK: Circle icon button (nav-icon-btn)

struct PlanIconButton: View {
    let icon: String
    var size: CGFloat = 18
    var diameter: CGFloat = 34
    var accent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(AuraFont.jakarta(size, .semibold))
                .foregroundColor(accent ? .aura.accent : .aura.text)
                .frame(width: diameter, height: diameter)
                .background(accent ? Color.aura.accentSoft : Color.aura.fill.opacity(0.5))
                .clipShape(Circle())
        }
    }
}

// MARK: Sheet wrapper (grabber + optional title/subtitle + close)

struct PlanSheet<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    var centeredTitle: String? = nil
    var centeredSubtitle: String? = nil
    var onClose: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            if let title {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(AuraFont.jakarta(15, .bold)).foregroundColor(.aura.text)
                        if let subtitle {
                            Text(subtitle).font(AuraFont.jakarta(12)).foregroundColor(.aura.text2)
                        }
                    }
                    Spacer()
                    if let onClose {
                        PlanIconButton(icon: "xmark", action: onClose)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }
            if let centeredTitle {
                VStack(spacing: 3) {
                    Text(centeredTitle).font(AuraFont.jakarta(17, .heavy)).foregroundColor(.aura.text)
                    if let centeredSubtitle {
                        Text(centeredSubtitle).font(AuraFont.jakarta(12)).foregroundColor(.aura.text2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            ScrollView {
                content()
                    .padding(.horizontal, 14)
                    .padding(.bottom, 28)
            }
        }
        .background(Color.aura.elevated)
    }
}

// MARK: Row helper (.row)

struct PlanRow: View {
    var icon: String
    var color: Color
    var label: String
    var sub: String? = nil
    var textColor: Color = .aura.text
    var chevron: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(AuraFont.jakarta(16, .semibold))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(AuraFont.jakarta(16, .medium)).foregroundColor(textColor)
                    if let sub {
                        Text(sub).font(AuraFont.secondary()).foregroundColor(.aura.text2)
                    }
                }
                Spacer()
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(AuraFont.jakarta(14, .semibold))
                        .foregroundColor(.aura.text3)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

/// Groups rows in a surface card with hairline dividers (mirrors `.list`).
struct PlanList<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) { content() }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.md)
                    .stroke(Color.aura.separator2, lineWidth: 1)
            )
    }
}

// MARK: Source card (.src-card)

struct PlanSourceCard: View {
    var icon: String
    var iconBg: Color
    var iconTint: Color
    var title: String
    var subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: AuraRadius.sm)
                        .fill(iconBg)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(AuraFont.jakarta(20, .semibold))
                        .foregroundColor(iconTint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AuraFont.jakarta(15, .bold)).foregroundColor(.aura.text)
                    Text(subtitle).font(AuraFont.secondary()).foregroundColor(.aura.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AuraFont.jakarta(14, .semibold))
                    .foregroundColor(.aura.text3)
            }
            .padding(13)
            .frame(maxWidth: .infinity)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.md)
                    .stroke(Color.aura.separator2, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: Search field (.search)

struct PlanSearchField: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(AuraFont.jakarta(16, .medium))
                .foregroundColor(.aura.text3)
            TextField(placeholder, text: $text)
                .font(AuraFont.body())
                .foregroundColor(.aura.text)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 13)
        .frame(height: 42)
        .background(Color.aura.fill.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
    }
}

// MARK: Filter chip (with optional colour theming)

struct PlanFilterChip: View {
    var label: String
    var active: Bool
    /// Optional colour-coded palette (Exercises muscle chips).
    var palette: (soft: Color, tx: Color, active: Color)? = nil
    var outlined: Bool = false
    var trailingChevron: Bool = false
    var leadingClose: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if leadingClose {
                    Image(systemName: "xmark").font(AuraFont.jakarta(11, .bold))
                }
                Text(label).font(AuraFont.jakarta(12, .bold))
                if trailingChevron {
                    Image(systemName: "chevron.down").font(AuraFont.jakarta(11, .bold))
                        .foregroundColor(active ? .aura.accent : .aura.text3)
                }
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background)
            .overlay(
                Capsule().stroke(borderColor, lineWidth: outlined ? 1 : 0)
            )
            .clipShape(Capsule())
        }
    }

    private var foreground: Color {
        if let palette { return active ? .white : palette.tx }
        if outlined { return active ? .aura.accent : .aura.text2 }
        return active ? .white : .aura.text
    }
    private var background: Color {
        if let palette { return active ? palette.active : palette.soft }
        if outlined { return active ? .aura.accentSoft : .aura.surface }
        return active ? .aura.accent : .aura.fill
    }
    private var borderColor: Color {
        guard outlined else { return .clear }
        return active ? .aura.accent : .aura.separator2
    }
}

// MARK: Catalog grid (2-up muscle-tinted thumbs)

struct PlanCatalogGrid: View {
    let exercises: [PlanLibExercise]
    let onTap: (PlanLibExercise) -> Void

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: cols, spacing: 10) {
            ForEach(exercises) { e in
                let th = PlanMusclePalette.thumb(e.muscle)
                Button { onTap(e) } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        ZStack {
                            RoundedRectangle(cornerRadius: AuraRadius.sm).fill(th.bg)
                            Text(PlanMusclePalette.displayLabel(e.muscle).uppercased())
                                .font(AuraFont.jakarta(10, .heavy))
                                .tracking(0.7)
                                .foregroundColor(th.tx)
                                .multilineTextAlignment(.center)
                        }
                        .aspectRatio(1.5, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        Text(e.name)
                            .font(AuraFont.jakarta(14, .bold))
                            .foregroundColor(.aura.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 8)
                        Text("\(e.muscle) · \(e.equip)")
                            .font(AuraFont.jakarta(12))
                            .foregroundColor(.aura.text2)
                            .padding(.top, 2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: AuraRadius.md)
                            .stroke(Color.aura.separator2, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: Empty state

struct PlanEmptyState: View {
    var title: String
    var subtitle: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(AuraFont.jakarta(16, .bold)).foregroundColor(.aura.text3)
            Text(subtitle).font(AuraFont.jakarta(13)).foregroundColor(.aura.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }
}

// MARK: Library card (.lib-card)

struct PlanLibraryCard<Trailing: View>: View {
    var thumbMuscle: String? = nil
    /// When set, the thumb is keyword-tinted via `workoutTheme(for:)` and shows
    /// its icon instead of the plain fill (used by the workout library cards).
    var themeName: String? = nil
    var title: String
    var meta: AnyView
    @ViewBuilder var trailing: () -> Trailing
    let action: () -> Void

    @ViewBuilder private var thumb: some View {
        if let themeName {
            let t = workoutTheme(for: themeName)
            ZStack {
                RoundedRectangle(cornerRadius: AuraRadius.sm)
                    .fill(t.color.opacity(0.14))
                Image(systemName: t.icon)
                    .font(AuraFont.jakarta(22)).foregroundColor(t.color)
            }
        } else {
            RoundedRectangle(cornerRadius: AuraRadius.sm)
                .fill(Color.aura.fill)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                thumb
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(AuraFont.jakarta(16, .bold)).foregroundColor(.aura.text)
                    meta
                }
                Spacer()
                trailing()
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AuraRadius.md)
                    .stroke(Color.aura.separator2, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: RestPicker (stepper over a fixed ladder + dot indicator)

struct RestPicker: View {
    let label: String
    @Binding var value: Int
    var steps: [Int] = [15, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

    private var idx: Int { steps.firstIndex(of: value) ?? 0 }

    static func fmt(_ s: Int) -> String {
        s < 60 ? "\(s)s" : "\(s / 60):" + String(format: "%02d", s % 60)
    }

    var body: some View {
        VStack(spacing: 10) {
            Text(label.uppercased())
                .font(AuraFont.jakarta(11, .bold))
                .tracking(0.55)
                .foregroundColor(.aura.text2)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Button { if idx > 0 { value = steps[idx - 1] } } label: {
                    stepGlyph("minus", accent: false)
                }
                Text(Self.fmt(value))
                    .font(AuraFont.jakarta(26, .heavy).monospacedDigit())
                    .tracking(-0.78)
                    .foregroundColor(.aura.accent)
                    .frame(maxWidth: .infinity)
                Button { if idx < steps.count - 1 { value = steps[idx + 1] } } label: {
                    stepGlyph("plus", accent: true)
                }
            }
            HStack(spacing: 4) {
                ForEach(steps, id: \.self) { s in
                    Capsule()
                        .fill(s == value ? Color.aura.accent : Color.aura.separator2)
                        .frame(width: s == value ? 14 : 5, height: 4)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AuraRadius.lg)
                .stroke(Color.aura.separator2, lineWidth: 1)
        )
    }

    private func stepGlyph(_ icon: String, accent: Bool) -> some View {
        Image(systemName: icon)
            .font(AuraFont.jakarta(17, .semibold))
            .foregroundColor(accent ? .aura.accent : .aura.text)
            .frame(width: 34, height: 34)
            .background(accent ? Color.aura.accentSoft : Color.aura.fill.opacity(0.5))
            .clipShape(Circle())
    }
}

// MARK: WeekStrip (7 day tiles)

struct WeekStrip: View {
    /// Weekday → workoutId (nil = rest).
    let schedule: [PlanDay: String?]
    var calStartSun: Bool
    var onDayMenu: (PlanDay) -> Void
    var onDayPlus: (PlanDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AuraSectionLabel(title: "This week").padding(.top, 0)
            HStack(spacing: 4) {
                ForEach(PlanDay.ordered(calStartSun: calStartSun), id: \.self) { day in
                    tile(day)
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ day: PlanDay) -> some View {
        let wId = schedule[day] ?? nil
        let w = PlanData.workout(by: wId)
        let isRest = w == nil
        let c = planWkStyle(w?.name)
        let shortName = w.map { $0.name.replacingOccurrences(of: "workout", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: " ").first ?? "" } ?? "Rest"

        Button { isRest ? onDayPlus(day) : onDayMenu(day) } label: {
            VStack(spacing: 6) {
                Text(day.shortLabel.uppercased())
                    .font(AuraFont.jakarta(9, .bold))
                    .tracking(0.6)
                    .foregroundColor(isRest ? .aura.text3 : c.tint)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isRest ? Color.aura.fill : c.bg)
                        .frame(width: 34, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isRest ? Color.aura.separator2 : c.border.opacity(0.45), lineWidth: 1.5)
                        )
                    Image(systemName: isRest ? "moon.fill" : planWkIcon(w?.name))
                        .font(AuraFont.jakarta(isRest ? 14 : 16))
                        .foregroundColor(isRest ? .aura.text3 : c.tint)
                }
                Text(shortName)
                    .font(AuraFont.jakarta(8, .bold))
                    .foregroundColor(isRest ? .aura.text3 : c.tint)
                    .lineLimit(1)
                    .frame(maxWidth: 34)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 2)
            .background(isRest ? Color.clear : c.bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRest ? Color.aura.separator2 : c.border.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workout keyword theming (shared)
//
// One rule for tile colour + SF Symbol icon across My Plans rows, the week
// strip, and the libraries. First keyword match wins in the fixed order
// push → pull → leg → upper; anything else falls back to accent + dumbbell
// (the fallback is by design, e.g. "Chest Day"). Colour reuses the existing
// `planWkStyle` tint / `planWkIcon` glyph so there's a single keyword table.

struct WorkoutTheme {
    let color: Color
    let icon: String
}

func workoutTheme(for name: String) -> WorkoutTheme {
    WorkoutTheme(color: planWkStyle(name).tint, icon: planWkIcon(name))
}
