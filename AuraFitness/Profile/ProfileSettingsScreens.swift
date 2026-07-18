import SwiftUI

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    /// Dark Mode toggle maps to the on/off ends of the 3-way preference.
    private var darkOn: Binding<Bool> {
        Binding(
            get: { appState.darkModePreference == .on },
            set: { appState.darkModePreference = $0 ? .on : .off }
        )
    }
    private var weekStart: Binding<String> {
        Binding(
            get: { appState.calendarStartDay == 1 ? "Mon" : "Sun" },
            set: { appState.calendarStartDay = ($0 == "Mon") ? 1 : 0 }
        )
    }
    /// Maps the seg labels (Score/Balance/Both) to the stored logDisplayMode.
    private var showOnProgress: Binding<String> {
        Binding(
            get: {
                switch appState.logDisplayMode {
                case "Strength Score":   return "Strength score"
                case "Strength Balance": return "Balance"
                default:                 return "Both"
                }
            },
            set: {
                switch $0 {
                case "Strength score": appState.logDisplayMode = "Strength Score"
                case "Balance":        appState.logDisplayMode = "Strength Balance"
                default:               appState.logDisplayMode = "Both"
                }
            }
        )
    }

    var body: some View {
        SettingsScreenScaffold(title: "General") {
            SettingsSectionLabel(title: "Appearance")
            SettingsGroup {
                SettingsControlRow(title: "Dark Mode", subtitle: "Applies across the app",
                                   iconName: "moon.fill", iconColor: .aura.purple) {
                    AuraToggle(isOn: darkOn)
                }
            }

            SettingsSectionLabel(title: "Calendar")
            SettingsGroup {
                SettingsControlRow(title: "Start week on") {
                    AuraSegmentedPicker(options: ["Sun", "Mon"], selection: weekStart)
                        .frame(width: 150)
                }
            }

            SettingsSectionLabel(title: "Log page")
            SettingsGroup {
                VStack(alignment: .leading, spacing: AuraSpacing.s3) {
                    Text("Show on progress")
                        .font(AuraFont.body())
                        .foregroundColor(.aura.text)
                    AuraSegmentedPicker(options: ["Strength score", "Balance", "Both"],
                                        selection: showOnProgress)
                }
                .padding(AuraSpacing.s4)
            }
        }
    }
}

// MARK: - Notifications

struct NotificationsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var toast = ToastCenter()

    private let sounds = ["Ding", "Alarm clock"]

    var body: some View {
        SettingsScreenScaffold(title: "Notifications", toast: toast) {
            SettingsSectionLabel(title: "Notifications")
            SettingsGroup {
                SettingsControlRow(title: "Enable notifications",
                                   subtitle: "Reminders, streaks and updates") {
                    AuraToggle(isOn: $appState.notificationsEnabled)
                        .onChange(of: appState.notificationsEnabled) { _, enabled in
                            if enabled { NotificationScheduler.requestAuthorizationIfNeeded() }
                        }
                }
            }

            SettingsSectionLabel(title: "Rest timer sound")
            SettingsGroup {
                ForEach(Array(sounds.enumerated()), id: \.element) { idx, sound in
                    Button {
                        appState.restSound = sound
                        toast.flash("\(sound) selected")
                    } label: {
                        HStack(spacing: AuraSpacing.s3) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Color.aura.blue)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "timer")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(sound)
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text)
                            Spacer()
                            if appState.restSound == sound {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.aura.accent)
                            }
                        }
                        .padding(.horizontal, AuraSpacing.s4)
                        .padding(.vertical, 12)
                        .frame(minHeight: 56)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < sounds.count - 1 { Divider().padding(.leading, 64) }
                }
            }
            // Dim + disable the whole sound list when notifications are off.
            .opacity(appState.notificationsEnabled ? 1 : 0.45)
            .allowsHitTesting(appState.notificationsEnabled)
        }
    }
}

// MARK: - Units & Measurements

struct UnitsSettingsView: View {
    @EnvironmentObject var appState: AppState

    /// Seg shows full words; storage keeps the short code.
    private var weightSel: Binding<String> {
        Binding(
            get: { appState.weightUnit == "lb" ? "Pounds" : "Kilograms" },
            set: { appState.weightUnit = ($0 == "Pounds") ? "lb" : "kg" }
        )
    }
    private var lengthSel: Binding<String> {
        Binding(
            get: { appState.lengthUnit == "in" ? "Inches" : "Centimeters" },
            set: { appState.lengthUnit = ($0 == "Inches") ? "in" : "cm" }
        )
    }

    var body: some View {
        SettingsScreenScaffold(title: "Units & Measurements") {
            SettingsSectionLabel(title: "Weight")
            SettingsGroup {
                SettingsControlRow(title: "Weight unit") {
                    AuraSegmentedPicker(options: ["Kilograms", "Pounds"], selection: weightSel)
                        .frame(width: 170)
                }
            }

            SettingsSectionLabel(title: "Length")
            SettingsGroup {
                SettingsControlRow(title: "Length unit") {
                    AuraSegmentedPicker(options: ["Centimeters", "Inches"], selection: lengthSel)
                        .frame(width: 190)
                }
            }
        }
    }
}

// MARK: - Connected Apps

struct ConnectedAppsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        SettingsScreenScaffold(title: "Connected Apps") {
            SettingsSectionLabel(title: "Health integrations")
            SettingsGroup {
                SettingsControlRow(title: "Apple Health",
                                   subtitle: appState.appleHealthConnected ? "Connected" : "Not connected",
                                   iconName: "flame.fill", iconColor: .aura.red) {
                    AuraToggle(isOn: Binding(
                        get: { appState.appleHealthConnected },
                        set: { newValue in
                            if newValue {
                                Task { await HealthKitService.shared.requestAuthorization(appState: appState) }
                            } else {
                                HealthKitService.shared.disconnect(appState: appState)
                            }
                        }
                    ))
                }
            }

            HStack(alignment: .top, spacing: AuraSpacing.s2) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.aura.text2)
                Text("Aura syncs workouts and body weight both ways with your connected health app.")
                    .font(AuraFont.secondary())
                    .foregroundColor(.aura.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AuraSpacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.aura.fill)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
            .padding(.top, AuraSpacing.s3)
        }
    }
}

// MARK: - Support

struct SupportView: View {
    @StateObject private var toast = ToastCenter()

    var body: some View {
        SettingsScreenScaffold(title: "Support", toast: toast) {
            SettingsSectionLabel(title: "Get help")
            SettingsGroup {
                supportRow("doc.text.fill", .aura.accent, "User Guides & FAQ", "Opening guides…")
                Divider().padding(.leading, 64)
                supportRow("person.fill", .aura.blue, "Contact Us", "Opening contact form…")
                Divider().padding(.leading, 64)
                supportRow("sparkles", .aura.purple, "Feature Request", "Opening request form…")
            }

            Text("Aura Fitness · v2.4.0")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text3)
                .frame(maxWidth: .infinity)
                .padding(.top, AuraSpacing.s5)
        }
    }

    private func supportRow(_ icon: String, _ color: Color, _ title: String, _ msg: String) -> some View {
        Button { toast.flash(msg) } label: {
            SettingsRowLabel(icon: icon, iconColor: color, title: title)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Settings screen scaffold

/// Common scaffold for the push-in settings screens: scroll body, grouped bg,
/// inline back-to-Profile nav, bottom tab clearance, optional toast.
struct SettingsScreenScaffold<Content: View>: View {
    let title: String
    var toast: ToastCenter? = nil
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) { content }
                .padding(.horizontal, AuraSpacing.s4)
                .padding(.bottom, AuraSpacing.tabBarClearance)
        }
        .background(Color.aura.bgGrouped.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(OptionalToast(toast: toast))
    }
}

private struct OptionalToast: ViewModifier {
    let toast: ToastCenter?
    func body(content: Content) -> some View {
        if let toast {
            content.auraToast(toast)
        } else {
            content
        }
    }
}

// MARK: - Confirm sheets (export / reset / delete / logout)

struct ProfileConfirmSheet: View {
    let kind: ProfileSheet
    let flash: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var authService: AuthService

    @State private var exportURL: URL? = nil
    @State private var busy = false
    @State private var showFullResetConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            content
                .padding(.horizontal, AuraSpacing.s4)
                .padding(.bottom, AuraSpacing.s5)
        }
        .presentationDetents([.height(detentHeight)])
        .presentationDragIndicator(.hidden)
        .background(Color.aura.surface)
        .alert("Reset everything?", isPresented: $showFullResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Everything", role: .destructive) {
                DataResetService.resetAll(workoutOnly: false, appState: appState, alsoRemote: true)
                dismiss(); flash("All data reset")
            }
        } message: {
            Text("This clears your profile, settings, and all workout data on this device and in the cloud. This cannot be undone.")
        }
    }

    private var detentHeight: CGFloat {
        switch kind {
        case .export: return 320
        case .reset:  return 360
        case .delete: return 340
        case .logout: return 320
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .export:  exportSheet
        case .reset:   resetSheet
        case .delete:  destructiveSheet(delete: true)
        case .logout:  destructiveSheet(delete: false)
        }
    }

    // Export
    private var exportSheet: some View {
        VStack(spacing: AuraSpacing.s3) {
            Text("Export Data")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.aura.text)
                .padding(.bottom, AuraSpacing.s2)
            Text("Download a full copy of your workouts, measurements and settings as a JSON archive.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
                .padding(.bottom, AuraSpacing.s2)
            if let exportURL {
                ShareLink(item: exportURL) {
                    HStack(spacing: AuraSpacing.s2) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Export Archive")
                            .font(AuraFont.body())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.aura.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                }
                .simultaneousGesture(TapGesture().onEnded { flash("Export ready") })
            } else {
                AuraPrimaryButton(label: busy ? "Preparing…" : "Export Archive", isLoading: busy) {}
                    .disabled(true)
                    .opacity(0.6)
            }
            AuraGrayButton(label: "Cancel") { dismiss() }
        }
        .task {
            guard exportURL == nil else { return }
            busy = true
            exportURL = await DataArchiveBuilder.writeTempFile(appState)
            busy = false
        }
    }

    // Reset (two options)
    private var resetSheet: some View {
        VStack(spacing: AuraSpacing.s3) {
            Text("Reset Data")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.aura.text)
                .padding(.bottom, AuraSpacing.s2)
            SettingsGroup {
                Button {
                    DataResetService.resetAll(workoutOnly: true, appState: appState, alsoRemote: true)
                    dismiss(); flash("Workout data reset")
                } label: {
                    SettingsRowLabel(icon: "dumbbell.fill", iconColor: .aura.text2,
                                     title: "Reset workout data only",
                                     subtitle: "Keeps your profile & settings",
                                     showChevron: false)
                }
                .buttonStyle(.plain)
            }
            SettingsGroup {
                Button {
                    // Recommended confirmation before a destructive full wipe.
                    showFullResetConfirm = true
                } label: {
                    HStack(spacing: AuraSpacing.s3) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(Color.aura.red)
                                .frame(width: 32, height: 32)
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text("Reset everything")
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
            AuraGrayButton(label: "Cancel") { dismiss() }
                .padding(.top, AuraSpacing.s2)
        }
    }

    // Delete / Logout (shared renderer)
    private func destructiveSheet(delete: Bool) -> some View {
        VStack(spacing: AuraSpacing.s3) {
            ZStack {
                Circle()
                    .fill(Color.aura.red.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: delete ? "trash.fill" : "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.aura.red)
            }
            .padding(.top, AuraSpacing.s2)
            Text(delete ? "Delete account?" : "Log out?")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.aura.text)
            Text(delete
                 ? "This permanently erases your account and all synced + local data. This cannot be undone."
                 : "You can log back in anytime with your email.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .padding(.bottom, AuraSpacing.s2)
            if delete {
                AuraDangerButton(label: busy ? "Deleting…" : "Delete Account") {
                    guard !busy else { return }
                    busy = true
                    Task {
                        // Remote delete (Edge Function) must SUCCEED before
                        // any local wipe or sign-out. On failure: no wipe,
                        // stay signed in, show error — wrong order orphans an
                        // account with lost local data.
                        if await authService.deleteAccount() {
                            // Edge Function's `on delete cascade` already
                            // wiped every aura_* row remotely — alsoRemote:
                            // false here to avoid a pointless post-delete
                            // network call against a user that no longer exists.
                            DataResetService.resetAll(workoutOnly: false, appState: appState, alsoRemote: false)
                            busy = false
                            dismiss(); flash("Account deleted")
                        } else {
                            busy = false
                            flash(authService.lastError ?? "Delete failed")
                        }
                    }
                }
                .disabled(busy)
                .opacity(busy ? 0.6 : 1)
            } else {
                AuraPrimaryButton(label: busy ? "Logging out…" : "Log Out") {
                    guard !busy else { return }
                    busy = true
                    Task {
                        // Do NOT wipe local data — it stays for the next
                        // login on this device and is already backed up
                        // remotely. Sign-out flips sessionState -> gate
                        // shows login.
                        await authService.signOut()
                        busy = false
                        dismiss(); flash("Logged out")
                    }
                }
                .disabled(busy)
                .opacity(busy ? 0.6 : 1)
            }
            AuraGrayButton(label: "Cancel") { dismiss() }
                .disabled(busy)
        }
    }
}
