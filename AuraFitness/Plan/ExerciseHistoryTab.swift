import SwiftUI

// MARK: - Exercise History tab
//
// Personal bests + past sessions for one exercise, computed on demand from the
// real workout logs in `AppState` (never seeded). Epley e1RM matches
// `PersonalRecord.compute1RM` exactly (rounded to 0.25 in canonical kg before
// unit conversion).

struct ExerciseHistoryTab: View {
    let exerciseName: String
    @EnvironmentObject var appState: AppState

    // MARK: Derived model

    /// One qualifying (done, non-nil weight+reps) set inside a session.
    private struct HistSet {
        let weightKg: Double   // 0 == bodyweight
        let reps: Int
        var e1RM: Double { PersonalRecord.compute1RM(weight: weightKg, reps: reps) }
    }

    private struct Session: Identifiable {
        let id = UUID()
        let date: Date
        let allSets: [HistSet]       // done sets (may be empty)
        var qualifying: [HistSet] { allSets.filter { $0.reps > 0 } }
    }

    /// Sessions containing this exercise, most recent first, capped at 10.
    private var sessions: [Session] {
        let target = exerciseName.trimmingCharacters(in: .whitespaces).lowercased()
        return appState.workoutLogs
            .compactMap { log -> Session? in
                guard let ex = log.exercises.first(where: {
                    $0.name.trimmingCharacters(in: .whitespaces).lowercased() == target
                }) else { return nil }
                let sets = ex.sets
                    .filter { $0.done }
                    .map { HistSet(weightKg: $0.weight ?? 0, reps: $0.reps ?? 0) }
                return Session(date: log.date, allSets: sets)
            }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { $0 }
    }

    private var allQualifying: [HistSet] {
        sessions.flatMap { $0.qualifying }
    }

    private var unit: String { appState.weightUnit }

    var body: some View {
        VStack(alignment: .leading, spacing: AuraSpacing.s4) {
            if sessions.isEmpty {
                emptyState
            } else {
                personalBests
                AuraSectionLabel(title: "Recent Sessions")
                ForEach(sessions) { session in
                    SessionRow(session: sessionSummary(session), unit: unit)
                }
            }
        }
        .padding(AuraSpacing.screenPad)
        .padding(.bottom, 40)
    }

    // MARK: Personal bests

    private var personalBests: some View {
        let best1RM = allQualifying.map { $0.e1RM }.max() ?? 0
        let maxWeight = allQualifying.map { $0.weightKg }.max() ?? 0
        let maxReps = allQualifying.map { $0.reps }.max() ?? 0
        let maxVolume = allQualifying.map { $0.weightKg * Double($0.reps) }.max() ?? 0

        return AuraCard {
            VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                Text("Personal Bests")
                    .sectionLabelStyle()
                HStack(spacing: AuraSpacing.s3) {
                    pbTile("Est. 1RM", weightDisplay(best1RM))
                    pbTile("Max Weight", weightDisplay(maxWeight))
                }
                HStack(spacing: AuraSpacing.s3) {
                    pbTile("Max Reps", maxReps > 0 ? "\(maxReps)" : "—")
                    pbTile("Max Volume", weightDisplay(maxVolume))
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    @ViewBuilder
    private func pbTile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(AuraFont.statNum(size: 20))
                .foregroundColor(.aura.text)
            Text(label)
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AuraSpacing.s3)
        .background(Color.aura.fill.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
    }

    /// 0 weight → bodyweight marker; else formatted via `UnitFormatter`.
    private func weightDisplay(_ kg: Double) -> String {
        kg <= 0 ? "BW" : UnitFormatter.weight(kg, unit: unit)
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: AuraSpacing.s3) {
            Image(systemName: "dumbbell")
                .font(AuraFont.jakarta(34))
                .foregroundColor(.aura.text3)
            Text("No logged sessions yet")
                .font(AuraFont.jakarta(16, .bold))
                .foregroundColor(.aura.text)
            Text("Sessions appear here after you log this exercise.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: Session → view summary

    private func sessionSummary(_ s: Session) -> SessionRow.Summary {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMM d, yyyy"
        let rows = s.qualifying.enumerated().map { i, set in
            SessionRow.SetRow(index: i + 1, weightKg: set.weightKg, reps: set.reps, e1RM: set.e1RM)
        }
        // Top set = highest e1RM.
        let top = s.qualifying.max { $0.e1RM < $1.e1RM }
        return SessionRow.Summary(
            dateLabel: f.string(from: s.date),
            setCount: s.qualifying.count,
            topWeightKg: top?.weightKg,
            topReps: top?.reps,
            sets: rows
        )
    }
}

// MARK: - SessionRow (expandable)

struct SessionRow: View {
    struct SetRow: Identifiable {
        let index: Int
        let weightKg: Double
        let reps: Int
        let e1RM: Double
        var id: Int { index }
    }
    struct Summary {
        let dateLabel: String
        let setCount: Int
        let topWeightKg: Double?
        let topReps: Int?
        let sets: [SetRow]
    }

    let session: Summary
    let unit: String
    @State private var expanded = false

    private func w(_ kg: Double) -> String { kg <= 0 ? "BW" : UnitFormatter.weight(kg, unit: unit) }

    private var topLine: String {
        guard session.setCount > 0, let tw = session.topWeightKg, let tr = session.topReps else {
            return "— no completed sets"
        }
        return "Top: \(w(tw)) × \(tr)"
    }

    var body: some View {
        AuraCard {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.dateLabel)
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text)
                            Text("\(session.setCount) sets · \(topLine)")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                        Spacer()
                        if !session.sets.isEmpty {
                            Image(systemName: expanded ? "chevron.up" : "chevron.down")
                                .font(AuraFont.jakarta(13, .semibold))
                                .foregroundColor(.aura.text3)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded, !session.sets.isEmpty {
                    Divider().padding(.vertical, AuraSpacing.s3)
                    setTable
                }
            }
            .padding(AuraSpacing.s4)
        }
    }

    private var setTable: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Set").frame(width: 40, alignment: .leading)
                Text("Weight").frame(maxWidth: .infinity, alignment: .leading)
                Text("Reps").frame(width: 52, alignment: .trailing)
                Text("Est-1RM").frame(width: 80, alignment: .trailing)
            }
            .font(AuraFont.sectionLabel())
            .foregroundColor(.aura.text3)

            ForEach(session.sets) { row in
                HStack {
                    Text("\(row.index)").frame(width: 40, alignment: .leading)
                    Text(w(row.weightKg)).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(row.reps)").frame(width: 52, alignment: .trailing)
                    Text(w(row.e1RM)).frame(width: 80, alignment: .trailing)
                }
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text)
                .monospacedDigit()
            }
        }
    }
}
