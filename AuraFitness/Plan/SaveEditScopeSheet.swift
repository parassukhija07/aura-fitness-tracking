import SwiftUI

struct SaveEditScopeSheet: View {
    @Environment(\.dismiss) var dismiss
    var onJustToday: (() -> Void)? = nil
    var onPermanently: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            VStack(spacing: AuraSpacing.s3) {
                Text("Save Changes")
                    .font(AuraFont.navTitle())
                    .foregroundColor(.aura.text)
                Text("How do you want to save this edit?")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
            }
            .padding(.vertical, AuraSpacing.s4)

            VStack(spacing: AuraSpacing.s3) {
                Button {
                    onJustToday?()
                    dismiss()
                } label: {
                    HStack(spacing: AuraSpacing.s3) {
                        ZStack {
                            Circle()
                                .fill(Color.aura.accent.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.aura.accent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Just for Today")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.aura.text)
                            Text("Only affects this session")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.aura.text3)
                    }
                    .padding(AuraSpacing.s4)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                }
                .buttonStyle(.plain)

                Button {
                    onPermanently?()
                    dismiss()
                } label: {
                    HStack(spacing: AuraSpacing.s3) {
                        ZStack {
                            Circle()
                                .fill(Color.aura.blue.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "folder.fill")
                                .foregroundColor(.aura.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Permanently")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.aura.text)
                            Text("Updates your My Plans copy")
                                .font(AuraFont.secondary())
                                .foregroundColor(.aura.text2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.aura.text3)
                    }
                    .padding(AuraSpacing.s4)
                    .background(Color.aura.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                }
                .buttonStyle(.plain)

                AuraGrayButton(label: "Cancel") { dismiss() }
            }
            .padding(.horizontal, AuraSpacing.screenPad)
            .padding(.bottom, AuraSpacing.s5)
        }
        .background(Color.aura.bg)
    }
}
