import SwiftUI

// MARK: - Plan tab
//
// Faithful native port of `.design-import-v9/plan/app.jsx` (Phase 4 · 04-plan.html).
// Five pieces of state act like a tiny router, checked in priority order:
//   viewingEx → editingWk → editingProg → viewingProg → (sub-tab shell)
// Whichever is set wins and replaces the entire tab (hard swap, no push animation).

struct PlanTabView: View {
    @EnvironmentObject var appState: AppState

    private enum Subtab: String, CaseIterable {
        case myplans, programs, workouts, exercises
        var label: String {
            switch self { case .myplans: return "My Plans"; case .programs: return "Programs"
            case .workouts: return "Workouts"; case .exercises: return "Exercises" }
        }
    }

    @State private var subtab: Subtab = .myplans
    @State private var schedule: [PlanDay: String?] = PlanData.defaultSchedule
    @State private var workouts: [PlanWorkout] = PlanData.workouts
    @State private var modal: PlanModal?

    // Router state (priority order matches app.jsx).
    @State private var editingWk: PlanWorkout?
    @State private var viewingProg: PlanProgram?
    @State private var editingProg = false
    @State private var viewingEx: PlanLibExercise?

    private var calStartSun: Bool { appState.calendarStartDay == 0 }

    var body: some View {
        if let ex = viewingEx {
            PlanExerciseDetailView(exercise: ex, showActions: true, onBack: { viewingEx = nil })
        } else if let wk = editingWk {
            PlanWorkoutEditorView(workout: wk, onBack: { editingWk = nil })
        } else if editingProg {
            PlanProgramEditorView(calStartSun: calStartSun,
                                  onBack: { editingProg = false },
                                  onEditWorkout: { editingWk = $0 })
        } else if let prog = viewingProg {
            PlanProgramDetailView(program: prog, onBack: { viewingProg = nil },
                                  onWorkout: { editingWk = $0 })
        } else {
            shell
        }
    }

    // MARK: Shell

    private var shell: some View {
        VStack(spacing: 0) {
            navbar
            Group {
                switch subtab {
                case .myplans:   myPlansBody
                case .programs:  PlanProgramsBody(onProgram: { viewingProg = $0 })
                case .workouts:  PlanWorkoutsBody(onEdit: { editingWk = $0 })
                case .exercises: PlanExercisesBody(onExercise: { viewingEx = $0 })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.aura.bg)
        .sheet(item: $modal) { m in
            modalView(m)
                .presentationDetents(m.detents)
                .presentationDragIndicator(.visible)
        }
    }

    private var navbar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Plan").font(AuraFont.largeTitleStyle()).tracking(AuraFont.largeTitleTracking)
                    .foregroundColor(.aura.text)
                Spacer()
                PlanIconButton(icon: "plus", size: 20, accent: true) { modal = .addPlan }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Subtab.allCases, id: \.self) { st in
                        PlanFilterChip(label: st.label, active: subtab == st) { subtab = st }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, AuraSpacing.s1)
        .padding(.bottom, AuraSpacing.s2)
    }

    // MARK: My Plans body (carousel + week strip + workouts)

    private var myPlansBody: some View {
        AuraScreenScroll {
            VStack(alignment: .leading, spacing: 0) {
                PlanCarousel(onNew: { modal = .addPlan })
                    .padding(.top, 10)

                WeekStrip(schedule: schedule, calStartSun: calStartSun,
                          onDayMenu: { modal = .dayMenu(day: $0) },
                          onDayPlus: { modal = .assign(day: $0) })
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                PlanMyPlansBody(
                    workouts: workouts,
                    onEditWorkout: { editingWk = $0 },
                    onAddWorkout: { modal = .addWorkout },
                    onDeleteWorkout: deleteWorkout
                )
                .padding(.horizontal, 14)
            }
        }
    }

    // MARK: Mutations

    private func assignDay(_ day: PlanDay, _ wId: String) { schedule[day] = wId; modal = nil }
    private func makeRest(_ day: PlanDay) { schedule[day] = .some(nil); modal = nil }
    private func deleteWorkout(_ id: String) {
        workouts.removeAll { $0.id == id }
        for (day, wId) in schedule where wId == id { schedule[day] = .some(nil) }
        modal = nil
    }

    // MARK: Modal builder

    @ViewBuilder
    private func modalView(_ m: PlanModal) -> some View {
        switch m {
        case .addPlan:
            AddPlanSheet(onClose: { modal = nil },
                         onPrograms: { subtab = .programs },
                         onBuildFromScratch: { modal = nil; editingProg = true })
        case .assign(let day):
            AssignSheet(day: day, current: schedule[day] ?? nil, workouts: workouts,
                        onAssign: { assignDay(day, $0) },
                        onRest: { makeRest(day) },
                        onClose: { modal = nil })
        case .dayMenu(let day):
            DayMenuSheet(day: day, workout: PlanData.workout(by: schedule[day] ?? nil),
                         onEdit: { editingWk = PlanData.workout(by: schedule[day] ?? nil); modal = nil },
                         onChange: { modal = .assign(day: day) },
                         onRest: { makeRest(day) },
                         onRemove: { makeRest(day) },
                         onClose: { modal = nil })
        case .addWorkout:
            AddWorkoutSheet(onLibrary: { modal = nil; subtab = .workouts },
                            onCreate: { modal = .createWorkout })
        case .createWorkout:
            CreateWorkoutSheet { name, _ in
                let newWk = PlanWorkout(id: "custom-\(UUID().uuidString.prefix(6))",
                                        name: name, exCount: 0, muscles: "Custom", duration: 0)
                workouts.append(newWk)
                modal = nil
                editingWk = newWk
            }
        }
    }
}
