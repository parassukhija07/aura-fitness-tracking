import SwiftUI

struct SwitchWorkoutSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var showSwitch: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            Text("Manage Today")
                .font(AuraFont.navTitle())
                .foregroundColor(.aura.text)
                .padding(.vertical, AuraSpacing.s3)

            VStack(spacing: 0) {
                optionRow(icon: "arrow.left.arrow.right", color: .aura.blue, title: "Switch to another workout") {
                    dismiss()
                }
                Divider().padding(.leading, 56)
                optionRow(icon: "moon.fill", color: .aura.text2, title: "Make it a Rest Day") {
                    dismiss()
                }
                Divider().padding(.leading, 56)
                optionRow(icon: "trash", color: .aura.red, title: "Remove", textColor: .aura.red) {
                    dismiss()
                }
            }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.horizontal, AuraSpacing.screenPad)

            AuraGrayButton(label: "Cancel") { dismiss() }
                .padding(.horizontal, AuraSpacing.screenPad)
                .padding(.top, AuraSpacing.s3)
                .padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
    }

    private func optionRow(icon: String, color: Color, title: String, textColor: Color = .aura.text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AuraSpacing.s3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(AuraFont.body())
                    .foregroundColor(textColor)
                Spacer()
            }
            .padding(.horizontal, AuraSpacing.s4)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}
