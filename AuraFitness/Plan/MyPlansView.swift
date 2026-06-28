import SwiftUI

struct MyPlansView: View {
    @EnvironmentObject var appState: AppState
    @State private var showProgramLibrary = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                AuraSectionLabel(title: "My Plans")
                    .padding(.horizontal, AuraSpacing.screenPad)

                // Plan cards horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AuraSpacing.s3) {
                        ForEach(Array(appState.userPlans.enumerated()), id: \.element.id) { idx, plan in
                            planCard(plan: plan, variant: idx % 3)
                        }

                        // Add plan card (dashed)
                        Button {
                            showProgramLibrary = true
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: AuraRadius.xl)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                    .foregroundColor(.aura.separator)
                                    .frame(width: 160, height: 120)
                                VStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundColor(.aura.text3)
                                    Text("Add Plan")
                                        .font(AuraFont.secondary())
                                        .foregroundColor(.aura.text2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AuraSpacing.screenPad)
                    .padding(.vertical, AuraSpacing.s3)
                }

                if let plan = appState.defaultPlan {
                    AuraSectionLabel(title: "This Week")
                        .padding(.horizontal, AuraSpacing.screenPad)

                    weekScheduleView(plan: plan)
                        .padding(.horizontal, AuraSpacing.screenPad)
                }

                AuraSectionLabel(title: "Options")
                    .padding(.horizontal, AuraSpacing.screenPad)

                VStack(spacing: 0) {
                    AuraListRow(iconName: "plus.circle", iconColor: .aura.accent,
                                title: "Create Custom Plan") {}
                }
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.bottom, 40)
            }
        }
        .background(Color.aura.bgGrouped)
        .sheet(isPresented: $showProgramLibrary) {
            ProgramLibraryView()
        }
    }

    /// Three gradient variants cycling per card, mirroring the design's
    /// `.plan-card` / `.plan-card.alt` / `.plan-card.alt2`.
    private func planGradient(_ variant: Int) -> LinearGradient {
        let pair: [Color]
        switch variant {
        case 1:  // .alt — blue → purple
            pair = [Color(hex: "#4A6FB5"), Color(hex: "#3D3A78")]
        case 2:  // .alt2 — green → teal
            pair = [Color(hex: "#3E8C6E"), Color(hex: "#2E6359")]
        default: // base — accent → warm orange
            pair = [.aura.accent, Color(hex: "#C85A2C")]
        }
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    private func planCard(plan: UserPlan, variant: Int) -> some View {
        let gradient = planGradient(variant)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AuraRadius.xl)
                .fill(gradient)
                .frame(width: 180, height: 120)

            VStack(alignment: .leading, spacing: 4) {
                if plan.isDefault {
                    AuraBadge(label: "Default", color: .white)
                }
                Spacer()
                Text(plan.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text("\(plan.weekSchedule.values.compactMap { $0 }.count) training days")
                    .font(AuraFont.secondary())
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(AuraSpacing.s3)
            .frame(width: 180, height: 120, alignment: .topLeading)
        }
        .contextMenu {
            Button { appState.userPlans.indices.forEach { appState.userPlans[$0].isDefault = false }
                     if let idx = appState.userPlans.firstIndex(where: { $0.id == plan.id }) {
                         appState.userPlans[idx].isDefault = true
                     }
            } label: {
                Label("Set as Default", systemImage: "star")
            }
        }
    }

    @ViewBuilder
    private func weekScheduleView(plan: UserPlan) -> some View {
        let days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        VStack(spacing: AuraSpacing.s2) {
            ForEach(0..<7, id: \.self) { i in
                let entry = plan.weekSchedule[i]
                let workout: Workout? = entry != nil ? (entry! != nil ? SeedData.programs.flatMap { $0.workouts }.first { $0.id == entry!! } : nil) : nil

                HStack {
                    Text(days[i])
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.aura.text2)
                        .frame(width: 36, alignment: .leading)

                    if let w = workout {
                        Text(w.name)
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text)
                        Spacer()
                        AuraBadge(label: w.primaryMuscles, color: .aura.accent)
                    } else {
                        Text("Rest")
                            .font(AuraFont.secondary())
                            .foregroundColor(.aura.text3)
                        Spacer()
                    }
                }
                .padding(AuraSpacing.s3)
                .background(Color.aura.surface)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
            }
        }
        .padding(.bottom, 8)
    }
}
