import SwiftUI

struct AccountDetailsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var toast = ToastCenter()
    @State private var sheet: ProfileSheet? = nil

    private var p: Binding<UserProfile> { $appState.userProfile }
    private var initials: String {
        "\(appState.userProfile.firstName.prefix(1))\(appState.userProfile.lastName.prefix(1))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Avatar + change photo
                VStack(spacing: AuraSpacing.s2) {
                    AvatarCircle(initials: initials, size: 78, fontSize: 28)
                    Button("Change photo") { toast.flash("Photo picker") }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.aura.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AuraSpacing.s4)

                // Name
                SettingsSectionLabel(title: "Name")
                HStack(spacing: AuraSpacing.s3) {
                    field("First", text: p.firstName)
                    field("Last", text: p.lastName)
                }

                // Contact
                SettingsSectionLabel(title: "Contact")
                VStack(spacing: AuraSpacing.s3) {
                    field("Email", text: p.email, keyboard: .emailAddress)
                    field("Phone", text: p.phone, keyboard: .phonePad)
                }

                // About
                SettingsSectionLabel(title: "About")
                VStack(spacing: AuraSpacing.s3) {
                    HStack(spacing: AuraSpacing.s3) {
                        dateField("Birthday", date: p.birthday)
                        selectField("Gender", selection: p.gender, options: ["Male", "Female", "Other"])
                    }
                    HStack(spacing: AuraSpacing.s3) {
                        numberField("Height (cm)", value: $appState.bodyStats.height)
                        field("Country", text: p.country)
                    }
                    HStack(spacing: AuraSpacing.s3) {
                        field("City", text: p.city)
                        field("State", text: p.state)
                    }
                }

                // Data
                SettingsSectionLabel(title: "Data")
                SettingsGroup {
                    Button { sheet = .export } label: {
                        SettingsRowLabel(icon: "arrow.up", iconColor: .aura.blue,
                                         title: "Export Data",
                                         subtitle: "Download all your workout data")
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 64)
                    Button { sheet = .reset } label: {
                        SettingsRowLabel(icon: "arrow.left.arrow.right", iconColor: .aura.text2,
                                         title: "Reset Data",
                                         subtitle: "Clear workouts or everything")
                    }
                    .buttonStyle(.plain)
                }

                SettingsGroup {
                    Button { sheet = .delete } label: {
                        HStack(spacing: AuraSpacing.s3) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Color.aura.red)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text("Delete Account")
                                .font(AuraFont.body())
                                .foregroundColor(.aura.red)
                            Spacer()
                        }
                        .padding(.horizontal, AuraSpacing.s4)
                        .padding(.vertical, 12)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, AuraSpacing.s3)

                AuraPrimaryButton(label: "Save Changes") {
                    dismiss()
                    appState.profileSaveFlash = "Account saved"
                }
                .padding(.top, AuraSpacing.s4)
            }
            .padding(.horizontal, AuraSpacing.s4)
            .padding(.bottom, AuraSpacing.tabBarClearance)
        }
        .background(Color.aura.bgGrouped.ignoresSafeArea())
        .navigationTitle("Account Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { which in
            ProfileConfirmSheet(kind: which, flash: { toast.flash($0) })
                .environmentObject(appState)
                .environmentObject(AuthService.shared)
        }
        .auraToast(toast)
    }

    // MARK: Field builders

    private func field(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.aura.text2)
            TextField(label, text: text)
                .font(AuraFont.body())
                .keyboardType(keyboard)
                .padding(.horizontal, AuraSpacing.s3)
                .frame(height: 44)
                .background(Color.aura.fill)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        }
        .frame(maxWidth: .infinity)
    }

    private func numberField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.aura.text2)
            TextField(label, value: value, format: .number)
                .font(AuraFont.body())
                .keyboardType(.decimalPad)
                .padding(.horizontal, AuraSpacing.s3)
                .frame(height: 44)
                .background(Color.aura.fill)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        }
        .frame(maxWidth: .infinity)
    }

    private func dateField(_ label: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.aura.text2)
            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AuraSpacing.s3)
                .frame(height: 44)
                .background(Color.aura.fill)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
        }
        .frame(maxWidth: .infinity)
    }

    private func selectField(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.aura.text2)
            Menu {
                Picker(label, selection: selection) {
                    ForEach(options, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue)
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.aura.text3)
                }
                .padding(.horizontal, AuraSpacing.s3)
                .frame(height: 44)
                .background(Color.aura.fill)
                .clipShape(RoundedRectangle(cornerRadius: AuraRadius.sm))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
