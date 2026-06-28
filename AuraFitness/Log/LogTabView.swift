import SwiftUI

struct LogTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDate: Date = Date()
    @State private var showCalendar = false
    @State private var showAddWorkout = false
    @State private var showSwitch = false
    @State private var showLogPast = false

    var todayWorkout: Workout? {
        guard let plan = appState.defaultPlan else { return nil }
        let dayIndex = Calendar.current.component(.weekday, from: selectedDate) - 1
        return plan.workout(for: dayIndex, programs: SeedData.programs)
    }

    var isRestDay: Bool {
        guard let plan = appState.defaultPlan else { return false }
        let dayIndex = Calendar.current.component(.weekday, from: selectedDate) - 1
        if let entry = plan.weekSchedule[dayIndex] { return entry == nil }
        return true
    }

    var hasNoPlan: Bool { appState.defaultPlan == nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Week bar
                    WeekBarView(selectedDate: $selectedDate)
                        .padding(.bottom, AuraSpacing.s4)

                    if hasNoPlan {
                        EmptyDayView(showAddWorkout: $showAddWorkout)
                    } else if isRestDay {
                        RestDayView(showAddWorkout: $showAddWorkout)
                    } else if let workout = todayWorkout {
                        PlannedWorkoutCardView(
                            workout: workout,
                            showSwitch: $showSwitch,
                            showLogPast: $showLogPast
                        ) {
                            appState.startWorkout(workout)
                        }
                    } else {
                        EmptyDayView(showAddWorkout: $showAddWorkout)
                    }

                    // Past logs for this day
                    let logs = appState.logs(for: selectedDate)
                    if !logs.isEmpty {
                        AuraSectionLabel(title: "Completed Today")
                            .padding(.horizontal, AuraSpacing.screenPad)

                        ForEach(logs) { log in
                            completedLogRow(log: log)
                                .padding(.horizontal, AuraSpacing.screenPad)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundColor(.aura.accent)
                    }
                }
            }
            .sheet(isPresented: $showCalendar) {
                CalendarSheetView(selectedDate: $selectedDate)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddWorkout) {
                AddWorkoutSourceSheet()
                    .presentationDetents([.fraction(0.6)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSwitch) {
                SwitchWorkoutSheet(showSwitch: $showSwitch)
                    .presentationDetents([.fraction(0.45)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func completedLogRow(log: WorkoutLog) -> some View {
        HStack(spacing: AuraSpacing.s3) {
            ZStack {
                Circle()
                    .fill(Color.aura.green.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.aura.green)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(log.workoutName)
                    .font(AuraFont.body())
                    .foregroundColor(.aura.text)
                let dur = log.durationSeconds
                Text("\(log.exercises.count) exercises · \(dur / 60) min")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
            }
            Spacer()
        }
        .padding(AuraSpacing.s3)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
    }
}
