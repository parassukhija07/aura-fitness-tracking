import SwiftUI

// MARK: - The five plan bottom-sheets
// add-plan · assign · day-menu · add-workout · create-workout (plan/app.jsx modalEl)

enum PlanModal: Identifiable {
    case addPlan
    case assign(day: PlanDay)
    case dayMenu(day: PlanDay)
    case addWorkout
    case createWorkout

    var id: String {
        switch self {
        case .addPlan: return "add-plan"
        case .assign(let d): return "assign-\(d.rawValue)"
        case .dayMenu(let d): return "daymenu-\(d.rawValue)"
        case .addWorkout: return "add-workout"
        case .createWorkout: return "create-workout"
        }
    }

    var detents: Set<PresentationDetent> {
        switch self {
        case .addPlan: return [.fraction(0.56)]
        case .assign: return [.fraction(0.74)]
        case .dayMenu: return [.fraction(0.5)]
        case .addWorkout: return [.fraction(0.5)]
        case .createWorkout: return [.large]
        }
    }
}

// MARK: Add-plan sheet

struct AddPlanSheet: View {
    var onClose: () -> Void
    var onPrograms: () -> Void
    var onBuildFromScratch: () -> Void

    var body: some View {
        PlanSheet(centeredTitle: "Add to My Plans", centeredSubtitle: "Pick a program or build your own") {
            VStack(spacing: 10) {
                PlanSourceCard(icon: "sparkles", iconBg: .aura.accentSoft, iconTint: .aura.accent,
                               title: "Browse programs", subtitle: "PPL, Upper/Lower, Full Body and more") {
                    onClose(); onPrograms()
                }
                PlanSourceCard(icon: "dumbbell.fill", iconBg: .aura.blue.opacity(0.14), iconTint: .aura.blue,
                               title: "Build from scratch", subtitle: "Create a custom weekly program") {
                    onClose(); onBuildFromScratch()
                }
                PlanSourceCard(icon: "doc.text", iconBg: .aura.green.opacity(0.14), iconTint: .aura.green,
                               title: "Duplicate active plan", subtitle: "Copy Push Pull Legs and tweak it") {
                    onClose()
                }
                AuraGrayButton(label: "Cancel") { onClose() }
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: Assign sheet

struct AssignSheet: View {
    let day: PlanDay
    let current: String?
    let workouts: [PlanWorkout]
    var onAssign: (String) -> Void
    var onRest: () -> Void
    var onClose: () -> Void

    var body: some View {
        PlanSheet(title: "Assign to \(day.rawValue)", subtitle: "Choose from workouts in this program", onClose: onClose) {
            VStack(spacing: 8) {
                ForEach(workouts) { w in
                    let isCur = current == w.id
                    Button { onAssign(w.id) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(w.name).font(.system(size: 15, weight: .bold))
                                    .foregroundColor(isCur ? .aura.accent : .aura.text)
                                Text("\(w.exCount) ex · \(w.muscles)")
                                    .font(.system(size: 12)).foregroundColor(.aura.text2)
                            }
                            Spacer()
                            Image(systemName: isCur ? "checkmark.circle.fill" : "chevron.right")
                                .font(.system(size: isCur ? 20 : 14, weight: .semibold))
                                .foregroundColor(isCur ? .aura.accent : .aura.text3)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(isCur ? Color.aura.accentSoft : Color.aura.surface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: AuraRadius.md)
                                .stroke(isCur ? Color.aura.accent : Color.aura.separator2, lineWidth: isCur ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Divider().padding(.vertical, 6)

                PlanSourceCard(icon: "plus.circle.fill", iconBg: .aura.accentSoft, iconTint: .aura.accent,
                               title: "Create new workout", subtitle: "Build from scratch and add to program") {
                    onClose()
                }
                AuraGrayButton(label: "Keep as Rest Day") { onRest() }
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: Day-menu sheet

struct DayMenuSheet: View {
    let day: PlanDay
    let workout: PlanWorkout?
    var onEdit: () -> Void
    var onChange: () -> Void
    var onRest: () -> Void
    var onRemove: () -> Void
    var onClose: () -> Void

    var body: some View {
        PlanSheet(centeredTitle: day.rawValue, centeredSubtitle: workout?.name ?? "Rest Day") {
            VStack(spacing: 12) {
                PlanList {
                    PlanRow(icon: "pencil", color: .aura.accent, label: "Edit workout",
                            sub: "Change exercises, sets or order", action: onEdit)
                    Divider().padding(.leading, 14)
                    PlanRow(icon: "arrow.left.arrow.right", color: .aura.blue, label: "Change workout",
                            sub: "Assign a different workout to \(day.rawValue)", action: onChange)
                    Divider().padding(.leading, 14)
                    PlanRow(icon: "moon.fill", color: .aura.text2, label: "Make it a rest day",
                            chevron: false, action: onRest)
                }
                PlanList {
                    PlanRow(icon: "trash", color: .aura.red, label: "Remove from program",
                            textColor: .aura.red, chevron: false, action: onRemove)
                }
                AuraGrayButton(label: "Cancel") { onClose() }
            }
        }
    }
}

// MARK: Add-workout sheet

struct AddWorkoutSheet: View {
    var onLibrary: () -> Void
    var onCreate: () -> Void

    var body: some View {
        PlanSheet(title: "Add a Workout", onClose: nil) {
            VStack(spacing: 10) {
                PlanSourceCard(icon: "magnifyingglass", iconBg: .aura.blue.opacity(0.14), iconTint: .aura.blue,
                               title: "From Workout Library", subtitle: "Browse and pick a ready-made workout",
                               action: onLibrary)
                PlanSourceCard(icon: "sparkles", iconBg: .aura.accentSoft, iconTint: .aura.accent,
                               title: "Create custom workout", subtitle: "Name it, pick an icon, add exercises",
                               action: onCreate)
            }
            .padding(.top, 4)
        }
    }
}

// MARK: Create-workout sheet (12-icon picker)

struct CreateWorkoutSheet: View {
    /// Returns the new workout name + chosen icon when "Continue" is tapped.
    var onContinue: (String, String) -> Void

    @State private var name = ""
    @State private var icon = "dumbbell.fill"

    struct WkIcon: Identifiable { let id = UUID(); let icon: String; let label: String; let color: Color }
    private let icons: [WkIcon] = [
        .init(icon: "flame.fill",    label: "Push",       color: .aura.accent),
        .init(icon: "bolt.fill",     label: "Pull",       color: .aura.blue),
        .init(icon: "trophy.fill",   label: "Legs",       color: .aura.green),
        .init(icon: "arrow.up",      label: "Upper",      color: .aura.purple),
        .init(icon: "dumbbell.fill", label: "Weights",    color: .aura.text2),
        .init(icon: "sparkles",      label: "Full Body",  color: .aura.accent),
        .init(icon: "target",        label: "Core",       color: .aura.red),
        .init(icon: "medal.fill",    label: "Strength",   color: Color(hex: "#C99A3A")),
        .init(icon: "timer",         label: "Cardio",     color: .aura.blue),
        .init(icon: "cable.connector", label: "Cable",    color: .aura.purple),
        .init(icon: "lightbulb.fill",label: "Hypertrophy",color: Color(hex: "#C9A52A")),
        .init(icon: "moon.fill",     label: "Recovery",   color: Color(hex: "#6E6A9C")),
    ]
    private let cols = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        PlanSheet(title: "New Workout", onClose: nil) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Workout name").font(.system(size: 13, weight: .semibold)).foregroundColor(.aura.text2)
                    TextField("e.g. Push Day A", text: $name)
                        .font(AuraFont.body())
                        .padding(.horizontal, 13).frame(height: 46)
                        .background(Color.aura.fill.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                }
                .padding(.bottom, 16)

                Text("ICON").font(.system(size: 10, weight: .bold)).tracking(0.5)
                    .foregroundColor(.aura.text2).padding(.bottom, 10)

                LazyVGrid(columns: cols, spacing: 8) {
                    ForEach(icons) { ic in
                        let sel = icon == ic.icon
                        Button { icon = ic.icon } label: {
                            VStack(spacing: 5) {
                                Image(systemName: ic.icon).font(.system(size: 20))
                                    .foregroundColor(sel ? .aura.accent : ic.color)
                                Text(ic.label).font(.system(size: 9, weight: .bold))
                                    .foregroundColor(sel ? .aura.accent : .aura.text3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(sel ? Color.aura.accentSoft : Color.aura.fill)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.aura.accent, lineWidth: sel ? 1.5 : 0)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 20)

                Button { onContinue(name.trimmingCharacters(in: .whitespaces), icon) } label: {
                    Text("Continue → Add Exercises")
                        .font(AuraFont.body()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.aura.accent)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }
        }
    }
}
