import SwiftUI

struct SaveEditScopeSheet: View {
    let onJustToday: (() -> Void)?
    let onPermanently: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AuraSpacing.s3) {
            Text("Apply changes")
                .font(AuraFont.cardTitle())
                .foregroundColor(.aura.text)

            Text("Choose how to save this change.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)

            if let onJustToday {
                AuraTintedButton(label: "Just for Today") {
                    onJustToday()
                    dismiss()
                }
            }

            AuraPrimaryButton(label: "Save Permanently", icon: "checkmark") {
                onPermanently()
                dismiss()
            }

            AuraGrayButton(label: "Cancel") {
                dismiss()
            }
        }
        .padding(AuraSpacing.screenPad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.aura.bgGrouped)
    }
}
