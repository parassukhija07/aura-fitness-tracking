import SwiftUI

struct SetRowView: View {
    @EnvironmentObject var session: WorkoutSessionState
    let exerciseIndex: Int
    let setIndex: Int
    @Binding var set: WorkoutSet

    @State private var weightText: String = ""
    @State private var repsText: String = ""
    @State private var showNote: Bool = false
    @State private var showTypeMenu: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: AuraSpacing.s2) {
                // Set type badge
                Button {
                    showTypeMenu = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(set.type.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Text(set.type == .normal ? "\(setIndex + 1)" : set.type.shortLabel)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(set.type.color)
                    }
                }
                .buttonStyle(.plain)

                // Weight
                TextField("kg", text: $weightText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(AuraFont.statNum(size: 18))
                    .foregroundColor(.aura.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.aura.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                    .onAppear { weightText = set.weight.map { String($0) } ?? "" }
                    .onChange(of: weightText) { _, newVal in
                        set.weight = Double(newVal)
                        autoFinishIfReady()
                    }
                    .onSubmit { autoFinishIfReady() }

                Text("×")
                    .font(AuraFont.body())
                    .foregroundColor(.aura.text3)

                // Reps
                TextField("reps", text: $repsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(AuraFont.statNum(size: 18))
                    .foregroundColor(.aura.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.aura.surface2)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
                    .onAppear { repsText = set.reps.map { String($0) } ?? "" }
                    .onChange(of: repsText) { _, newVal in
                        set.reps = Int(newVal)
                        autoFinishIfReady()
                    }
                    .onSubmit { autoFinishIfReady() }

                // Done checkmark
                Button {
                    toggleDone()
                } label: {
                    ZStack {
                        Circle()
                            .fill(set.done ? Color.aura.green : Color.aura.fill)
                            .frame(width: 34, height: 34)
                        Image(systemName: set.done ? "checkmark" : "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(set.done ? .white : .aura.text3)
                    }
                }
                .buttonStyle(.plain)

                // Note toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNote.toggle()
                    }
                } label: {
                    Image(systemName: "note.text")
                        .font(.system(size: 15))
                        .foregroundColor(set.note.isEmpty ? .aura.text3 : .aura.accent)
                }
                .buttonStyle(.plain)
            }

            // Note field
            if showNote {
                HStack {
                    TextField("Note for this set…", text: $set.note)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text)
                        .padding(.horizontal, AuraSpacing.s3)
                        .padding(.vertical, 8)
                        .background(Color.aura.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))

                    Button {
                        session.onDeleteSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.aura.red)
                            .font(.system(size: 15))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, AuraSpacing.s3)
        .padding(.vertical, AuraSpacing.s2)
        .background(set.done ? Color.aura.green.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        .sheet(isPresented: $showTypeMenu) {
            SetTypeMenuSheet(currentType: set.type) { type in
                session.onSetTypeChange(exerciseIndex: exerciseIndex, setIndex: setIndex, type: type)
                showTypeMenu = false
            }
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
        }
    }

    private func autoFinishIfReady() {
        guard !set.done,
              set.weight != nil, set.reps != nil
        else { return }
        session.onSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
    }

    private func toggleDone() {
        if set.done {
            set.done = false
        } else {
            // Sync text fields first
            set.weight = Double(weightText)
            set.reps = Int(repsText)
            session.onSetCompleted(exerciseIndex: exerciseIndex, setIndex: setIndex)
        }
    }
}

// MARK: - Set Type Menu
struct SetTypeMenuSheet: View {
    let currentType: SetType
    let onSelect: (SetType) -> Void

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            Text("Set Type")
                .font(AuraFont.navTitle())
                .foregroundColor(.aura.text)
                .padding(.vertical, AuraSpacing.s3)

            VStack(spacing: 0) {
                ForEach(SetType.allCases, id: \.self) { type in
                    Button {
                        onSelect(type)
                    } label: {
                        HStack(spacing: AuraSpacing.s3) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(type.color.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text(type.shortLabel.isEmpty ? "N" : type.shortLabel)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(type.color)
                            }
                            Text(type.label)
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text)
                            Spacer()
                            if type == currentType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.aura.accent)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                        }
                        .padding(.horizontal, AuraSpacing.s4)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    if type != SetType.allCases.last {
                        Divider().padding(.leading, 56)
                    }
                }
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
    }
}
