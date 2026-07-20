import SwiftUI

// MARK: - Program Detail
//
// Predefined-program preview pushed from the Plan → Programs library. Shows the
// program's hero, generated summary, meta chips, and its real workouts (each
// opening a read-only WorkoutEditorView), with a sticky "Add to My Plans" CTA
// that respects the 3-plan cap and flips to a disabled "Added ✓" once adopted.

struct ProgramDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var planDB = UserPlanDatabase.shared
    let program: Program
    @Environment(\.dismiss) var dismiss

    @State private var showFullAlert = false

    /// True once a plan sourced from this program exists in My Plans.
    var isAdded: Bool { planDB.plans.contains { $0.sourceProgramID == program.id } }

    private var c: PlanWorkoutStyle { planWkStyle(program.name) }

    /// "A 4-day Hypertrophy split. Advanced level." (fields are the program's real values).
    private var summary: String {
        "A \(program.daysPerWeek)-day \(program.style) split. \(program.level) level."
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AuraSpacing.s4) {
                        hero
                        Text(summary)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text2)
                        chips
                        workoutsSection
                        if program.isPredefined { infoCard }
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.top, AuraSpacing.s4)
                    .padding(.bottom, 120)   // clearance for the sticky footer
                }

                stickyFooter
            }
            .background(Color.aura.bgGrouped)
            .navigationTitle(program.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("My Plans is full", isPresented: $showFullAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("My Plans is full — remove a plan first.")
            }
        }
    }

    // MARK: Hero (16:9 program-tinted gradient + name)

    private var hero: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s3) {
            ZStack {
                LinearGradient(
                    colors: [c.tint.opacity(0.85), c.tint.opacity(0.45)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                Image(systemName: planWkIcon(program.name))
                    .font(AuraFont.jakarta(44))
                    .foregroundColor(.white.opacity(0.9))
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.xl))

            Text(program.name)
                .font(AuraFont.cardTitle(size: 26))
                .tracking(AuraFont.cardTitleTracking(size: 26))
                .foregroundColor(.aura.text)
        }
    }

    // MARK: Meta chips

    private var chips: some View {
        HStack(spacing: AuraSpacing.s2) {
            AuraBadge(label: "\(program.daysPerWeek) days/wk", color: .aura.accent)
            AuraBadge(label: program.level, color: .aura.blue)
            AuraBadge(label: program.style, color: .aura.purple)
        }
    }

    // MARK: Workouts in this program

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuraSectionLabel(title: "Workouts in this program")

            if program.workouts.isEmpty {
                Text("No workouts in this program yet")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text3)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(program.workouts.enumerated()), id: \.element.id) { i, w in
                        workoutRow(index: i + 1, workout: w)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func workoutRow(index: Int, workout w: Workout) -> some View {
        let style = planWkStyle(w.name)
        let muscles = w.primaryMuscles
            .components(separatedBy: ", ")
            .joined(separator: " · ")
        return NavigationLink {
            WorkoutEditorView(workout: w, context: .view)
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(style.bg)
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(style.border.opacity(0.35), lineWidth: 1.5))
                    Text("\(index)")
                        .font(AuraFont.jakarta(15, .heavy))
                        .foregroundColor(style.tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(w.name)
                        .font(AuraFont.jakarta(15, .heavy))
                        .foregroundColor(.aura.text)
                    Text(muscles.isEmpty ? "Custom" : muscles)
                        .font(AuraFont.jakarta(12, .medium))
                        .foregroundColor(style.tint)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AuraFont.jakarta(14, .semibold))
                    .foregroundColor(.aura.text3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .overlay(RoundedRectangle(cornerRadius: AuraRadius.md).stroke(Color.aura.separator2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Info card (predefined-only)

    private var infoCard: some View {
        HStack(alignment: .top, spacing: AuraSpacing.s2) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.aura.accent)
                .font(AuraFont.jakarta(15))
            Text("Predefined programs must be added to My Plans before editing. Edits live on your copy.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
        }
        .padding(AuraSpacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.aura.accentSoft)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
    }

    // MARK: Sticky footer

    private var stickyFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Group {
                if isAdded {
                    AuraGrayButton(label: "Added ✓") {}
                        .disabled(true)
                        .opacity(0.7)
                } else {
                    AuraPrimaryButton(label: "Add to My Plans", icon: "plus") {
                        addToMyPlans()
                    }
                }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.top, AuraSpacing.s3)
            .padding(.bottom, AuraSpacing.s4)
        }
        .background(.ultraThinMaterial)
    }

    private func addToMyPlans() {
        // The `from:` adopt path can't surface the cap (it returns a plan
        // regardless), so gate on the cap here and alert instead of no-op.
        guard planDB.plans.count < UserPlanDatabase.maxPlans else {
            showFullAlert = true
            return
        }
        _ = planDB.addPlan(from: program, startDay: appState.calendarStartDay)
        dismiss()
    }
}
