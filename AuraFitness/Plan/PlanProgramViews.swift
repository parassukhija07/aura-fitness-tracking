import SwiftUI

// MARK: - Program Detail (predefined program preview)
// Mirrors ProgramDetailView in plan/app.jsx.

struct PlanProgramDetailView: View {
    let program: PlanProgram
    var onBack: () -> Void
    var onWorkout: (PlanWorkout) -> Void

    private var wks: [PlanWorkout] { Array(PlanData.workouts.prefix(4)) }

    var body: some View {
        VStack(spacing: 0) {
            PlanNavbar(backLabel: "Programs", onBack: onBack) {
                PlanIconButton(icon: "ellipsis", size: 20) {}
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    RoundedRectangle(cornerRadius: AuraRadius.lg)
                        .fill(Color.aura.fill)
                        .aspectRatio(16.0/9.0, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                    Text(program.name)
                        .font(AuraFont.jakarta(24, .heavy)).tracking(-0.48)
                        .foregroundColor(.aura.text)
                        .padding(.top, 14).padding(.bottom, 4)
                    Text("A \(program.days)-day \(program.tag.lowercased()) split. \(program.level) level.")
                        .font(AuraFont.jakarta(13)).foregroundColor(.aura.text2)

                    HStack(spacing: 6) {
                        chip("\(program.days) days/wk"); chip(program.level); chip(program.tag)
                    }
                    .padding(.top, 12)

                    AuraSectionLabel(title: "Workouts in this program")
                    PlanList {
                        ForEach(Array(wks.enumerated()), id: \.element.id) { i, w in
                            Button { onWorkout(w) } label: {
                                HStack(spacing: AuraSpacing.s3) {
                                    Text("\(i + 1)")
                                        .font(AuraFont.jakarta(13, .bold)).foregroundColor(.aura.accent)
                                        .frame(width: 30, height: 30)
                                        .background(Color.aura.accentSoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 9))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(w.name).font(AuraFont.jakarta(16, .medium)).foregroundColor(.aura.text)
                                        Text("\(w.exCount) exercises · \(w.muscles)")
                                            .font(AuraFont.secondary()).foregroundColor(.aura.text2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(AuraFont.jakarta(14, .semibold)).foregroundColor(.aura.text3)
                                }
                                .padding(.vertical, 11).padding(.horizontal, 14)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            if i < wks.count - 1 { Divider().padding(.leading, 14) }
                        }
                    }

                    HStack(alignment: .top, spacing: AuraSpacing.s3) {
                        Image(systemName: "info.circle").foregroundColor(.aura.text2).font(AuraFont.jakarta(18))
                        (Text("To edit a predefined program, add it to ").foregroundColor(.aura.text2)
                            + Text("My Plans").foregroundColor(.aura.text2).bold()
                            + Text(" first. Your edits stay on your copy.").foregroundColor(.aura.text2))
                            .font(AuraFont.secondary())
                    }
                    .padding(AuraSpacing.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
                    .padding(.top, 14)

                    AuraPrimaryButton(label: "Add to My Plans", icon: "plus") {}
                        .padding(.top, 16)
                }
                .padding(.horizontal, 14)
                Color.clear.frame(height: 28)
            }
        }
        .background(Color.aura.bg)
    }

    private func chip(_ t: String) -> some View {
        Text(t).font(AuraFont.jakarta(13, .medium)).foregroundColor(.aura.text)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.aura.fill).clipShape(Capsule())
    }
}

// MARK: - Program Editor (build from scratch)
// Mirrors ProgramEditorView in plan/app.jsx.

struct PlanProgramEditorView: View {
    var calStartSun: Bool
    var onBack: () -> Void
    var onEditWorkout: (PlanWorkout) -> Void

    @State private var name = ""
    @State private var level: String? = nil
    @State private var workouts: [PlanWorkout] = []
    @State private var schedule: [PlanDay: String?] = Dictionary(uniqueKeysWithValues: PlanDay.allCases.map { (day: PlanDay) -> (PlanDay, String?) in (day, nil) })
    @State private var dayWarn = false
    @State private var addSheet: AddMode? = nil

    enum AddMode: Identifiable { case pick, library; var id: Int { hashValue } }

    private let levels = ["Beginner", "Intermediate", "Advanced"]
    private func levelColor(_ l: String) -> Color {
        switch l { case "Beginner": return .aura.green; case "Advanced": return .aura.red; default: return .aura.accent }
    }

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            PlanNavbar(onBack: onBack)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    TextField("Program name", text: $name)
                        .font(AuraFont.jakarta(24, .heavy)).tracking(-0.48)
                        .foregroundColor(.aura.text)
                        .padding(.top, 16).padding(.bottom, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("DIFFICULTY · OPTIONAL").font(AuraFont.jakarta(10, .bold)).tracking(0.5)
                            .foregroundColor(.aura.text2)
                        HStack(spacing: 6) {
                            ForEach(levels, id: \.self) { l in
                                Button { level = (level == l) ? nil : l } label: {
                                    Text(l).font(AuraFont.jakarta(12, .bold))
                                        .foregroundColor(level == l ? .white : .aura.text2)
                                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                                        .background(level == l ? levelColor(l) : .aura.fill)
                                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 18)

                    WeekStrip(schedule: schedule, calStartSun: calStartSun,
                              onDayMenu: { _ in }, onDayPlus: handleDayPlus)

                    if dayWarn {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").font(AuraFont.jakarta(16)).foregroundColor(.aura.accent)
                            Text("Add workouts below before assigning days")
                                .font(AuraFont.jakarta(13, .semibold)).foregroundColor(.aura.accent)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.aura.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                        .padding(.top, 10)
                    }

                    HStack {
                        AuraSectionLabel(title: "Workouts")
                        Spacer()
                        if !workouts.isEmpty {
                            PlanIconButton(icon: "plus", size: 16, diameter: 28, accent: true) { addSheet = .pick }
                                .padding(.top, AuraSpacing.s5)
                        }
                    }
                    .padding(.bottom, 10)

                    if workouts.isEmpty {
                        VStack(spacing: 10) {
                            PlanSourceCard(icon: "magnifyingglass", iconBg: .aura.blue.opacity(0.14), iconTint: .aura.blue,
                                           title: "Add from Workout Library", subtitle: "Browse and pick ready-made workouts") {
                                addSheet = .library
                            }
                            PlanSourceCard(icon: "dumbbell.fill", iconBg: .aura.accentSoft, iconTint: .aura.accent,
                                           title: "Create your own workout", subtitle: "Build a custom set of exercises") {
                                workouts.append(PlanWorkout(id: "new-\(UUID().uuidString.prefix(6))", name: "New Workout", exCount: 0, muscles: "Custom", duration: 0))
                            }
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach($workouts) { $w in
                                workoutRow($w)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                Color.clear.frame(height: 24)
            }

            VStack {
                Button { onBack() } label: {
                    Text("Save Program").font(AuraFont.body()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.aura.accent).clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.4)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .background(Color.aura.bg)
        .sheet(item: $addSheet) { mode in
            addWorkoutSheet(mode)
                .presentationDetents(mode == .library ? [.large] : [.fraction(0.5)])
                .presentationDragIndicator(.visible)
        }
    }

    private func handleDayPlus(_ day: PlanDay) {
        if workouts.isEmpty {
            dayWarn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { dayWarn = false }
            return
        }
        schedule[day] = workouts[0].id
    }

    @ViewBuilder
    private func workoutRow(_ w: Binding<PlanWorkout>) -> some View {
        let c = planWkStyle(w.wrappedValue.name)
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(c.bg).frame(width: 38, height: 38)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(c.border.opacity(0.35), lineWidth: 1.5))
                Image(systemName: planWkIcon(w.wrappedValue.name)).font(AuraFont.jakarta(17)).foregroundColor(c.tint)
            }
            TextField("Workout name", text: w.name)
                .font(AuraFont.jakarta(15, .bold)).foregroundColor(.aura.text)
            Spacer()
            Button { onEditWorkout(w.wrappedValue) } label: {
                Image(systemName: "chevron.right").font(AuraFont.jakarta(16, .semibold)).foregroundColor(.aura.text)
                    .frame(width: 30, height: 30).background(Color.aura.fill.opacity(0.5)).clipShape(Circle())
            }
            Button { workouts.removeAll { $0.id == w.wrappedValue.id } } label: {
                Image(systemName: "trash").font(AuraFont.jakarta(14)).foregroundColor(.aura.red)
                    .frame(width: 30, height: 30).background(Color.aura.fill.opacity(0.5)).clipShape(Circle())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
    }

    @ViewBuilder
    private func addWorkoutSheet(_ mode: AddMode) -> some View {
        switch mode {
        case .pick:
            PlanSheet(title: "Add a Workout", onClose: nil) {
                VStack(spacing: 10) {
                    PlanSourceCard(icon: "magnifyingglass", iconBg: .aura.blue.opacity(0.14), iconTint: .aura.blue,
                                   title: "From Workout Library", subtitle: "Browse ready-made workouts") {
                        addSheet = .library
                    }
                    PlanSourceCard(icon: "dumbbell.fill", iconBg: .aura.accentSoft, iconTint: .aura.accent,
                                   title: "Create your own workout", subtitle: "Build a custom set of exercises") {
                        workouts.append(PlanWorkout(id: "new-\(UUID().uuidString.prefix(6))", name: "New Workout", exCount: 0, muscles: "Custom", duration: 0))
                        addSheet = nil
                    }
                }
                .padding(.top, 4)
            }
        case .library:
            PlanSheet(title: "Workout Library", onClose: nil) {
                VStack(spacing: 8) {
                    ForEach(PlanData.workouts) { w in
                        let c = planWkStyle(w.name)
                        PlanSourceCard(icon: planWkIcon(w.name), iconBg: c.bg, iconTint: c.tint,
                                       title: w.name, subtitle: w.muscles) {
                            workouts.append(w); addSheet = nil
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
