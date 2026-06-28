import SwiftUI

struct AccountDetailsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            Section {
                // Photo placeholder
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(Color.aura.accentSoft)
                            .frame(width: 80, height: 80)
                        Text("\(appState.userProfile.firstName.prefix(1))\(appState.userProfile.lastName.prefix(1))")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(.aura.accent)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(Color.aura.accent)
                            .clipShape(Circle())
                            .offset(x: 28, y: 28)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
                .listRowBackground(Color.aura.surface)
            }

            Section("Personal Info") {
                profileField("First Name", value: $appState.userProfile.firstName)
                profileField("Last Name",  value: $appState.userProfile.lastName)
                profileField("Email",      value: $appState.userProfile.email)
                profileField("Phone",      value: $appState.userProfile.phone)
                profileField("Gender",     value: $appState.userProfile.gender)
                profileField("Location",   value: $appState.userProfile.location)
            }
            .listRowBackground(Color.aura.surface)

            Section("Body Stats") {
                HStack {
                    Text("Height (cm)")
                    Spacer()
                    TextField("175", value: $appState.bodyStats.height, format: .number)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.aura.accent)
                        .keyboardType(.decimalPad)
                }
                HStack {
                    Text("Weight (\(appState.weightUnit))")
                    Spacer()
                    TextField("75", value: $appState.bodyStats.weight, format: .number)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.aura.accent)
                        .keyboardType(.decimalPad)
                }
                HStack {
                    Text("Age")
                    Spacer()
                    TextField("28", value: $appState.bodyStats.age, format: .number)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.aura.accent)
                        .keyboardType(.numberPad)
                }
            }
            .listRowBackground(Color.aura.surface)

            Section("Data") {
                AuraListRow(iconName: "square.and.arrow.up", iconColor: .aura.blue,
                            title: "Export Data") {}
                AuraListRow(iconName: "arrow.counterclockwise", iconColor: .aura.accent,
                            title: "Reset Workout Data") {}
            }
            .listRowBackground(Color.aura.surface)

            Section {
                Button {
                    showDeleteConfirm = true
                } label: {
                    Text("Delete Account")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.red)
                        .frame(maxWidth: .infinity)
                }
            }
            .listRowBackground(Color.aura.surface)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Account Details")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your data. This cannot be undone.")
        }
    }

    @ViewBuilder
    private func profileField(_ label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, text: value)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.aura.accent)
        }
    }
}
