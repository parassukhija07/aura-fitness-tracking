import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    /// The scheme actually on screen. With the preference on `.auto` — the
    /// default until the user picks a side — `preferredColorScheme` is nil and
    /// the app follows the system, so this is the only thing that knows whether
    /// the app is currently rendering dark.
    @Environment(\.colorScheme) private var colorScheme

    /// Dark Mode is a 2-way toggle over a 3-way preference, so `.auto` has to
    /// resolve to whichever side it is currently rendering as. Reading
    /// `== .on` instead made a fresh install on a dark phone show a dark app
    /// with the switch off, and the first tap then appeared to do nothing —
    /// it moved `.auto` → `.on`, which looks identical. Only the second tap,
    /// to `.off`, visibly changed anything.
    ///
    /// Writing always commits an explicit `.on`/`.off`: once the user has
    /// touched the switch the choice is theirs, and it should stop tracking
    /// the system.
    private var darkOn: Binding<Bool> {
        Binding(
            get: {
                switch appState.darkModePreference {
                case .on:   return true
                case .off:  return false
                case .auto: return colorScheme == .dark
                }
            },
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
    @State private var showPermissionAlert = false

    private let sounds = ["Ding", "Alarm clock"]

    /// Enabling the toggle is only honoured if the OS actually grants (or has
    /// already granted) permission. On `.denied` — or a fresh prompt the user
    /// refuses — the toggle snaps back off and we point them at iOS Settings,
    /// since the app cannot re-prompt once permission is denied.
    private func handleNotificationsToggle(_ enabled: Bool) {
        guard enabled else { return }
        // Declared before the closures that capture it — a local function used
        // ahead of its declaration does not compile.
        let revokeToggle = {
            DispatchQueue.main.async {
                appState.notificationsEnabled = false
                showPermissionAlert = true
            }
        }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if !granted { revokeToggle() }
                }
            case .denied:
                revokeToggle()
            default:
                break   // .authorized / .provisional / .ephemeral — keep it on.
            }
        }
    }

    var body: some View {
        SettingsScreenScaffold(title: "Notifications", toast: toast) {
            SettingsSectionLabel(title: "Notifications")
            SettingsGroup {
                SettingsControlRow(title: "Enable notifications",
                                   subtitle: "Reminders, streaks and updates") {
                    AuraToggle(isOn: $appState.notificationsEnabled)
                        .onChange(of: appState.notificationsEnabled) { _, enabled in
                            handleNotificationsToggle(enabled)
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
                                    .font(AuraFont.jakarta(14, .semibold))
                                    .foregroundColor(.white)
                            }
                            Text(sound)
                                .font(AuraFont.body())
                                .foregroundColor(.aura.text)
                            Spacer()
                            if appState.restSound == sound {
                                Image(systemName: "checkmark")
                                    .font(AuraFont.jakarta(15, .bold))
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
            // Dim + disable the whole sound list when notifications are off
            // (shown, never hidden). `.disabled` over `.allowsHitTesting` so
            // assistive tech reports the rows as unavailable too.
            .opacity(appState.notificationsEnabled ? 1 : 0.45)
            .disabled(!appState.notificationsEnabled)
        }
        .alert("Notifications are turned off", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Allow notifications for Aura in iOS Settings to get rest-timer alerts.")
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
                    .font(AuraFont.jakarta(16))
                    .foregroundColor(.aura.text2)
                Text("Aura syncs workouts and body weight two-way with Apple Health.")
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

    /// Real marketing version from the bundle — never hardcode the number.
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

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

            Text("Aura Fitness · v\(appVersion)")
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
    @State private var csvExportURL: URL? = nil
    @State private var busy = false
    @State private var csvBusy = false
    @State private var showFullResetConfirm = false
    @State private var showWorkoutResetConfirm = false
    @State private var showFileImporter = false
    @State private var importBusy = false

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
        .alert("Reset workout data?", isPresented: $showWorkoutResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset Workouts", role: .destructive) {
                DataResetService.resetAll(workoutOnly: true, appState: appState, alsoRemote: true)
                dismiss(); flash("Workout data reset")
            }
        } message: {
            Text("This clears all logged workouts on this device and in the cloud. Your profile and settings are kept. This cannot be undone.")
        }
    }

    private var detentHeight: CGFloat {
        switch kind {
        case .export:     return 320
        case .reset:      return 360
        case .delete:     return 340
        case .logout:     return 320
        case .importData: return 360
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .export:     exportSheet
        case .reset:      resetSheet
        case .delete:     destructiveSheet(delete: true)
        case .logout:     destructiveSheet(delete: false)
        case .importData: importSheet
        }
    }

    // Export
    private var exportSheet: some View {
        VStack(spacing: AuraSpacing.s3) {
            Text("Export Data")
                .font(AuraFont.jakarta(17, .bold))
                .foregroundColor(.aura.text)
                .padding(.bottom, AuraSpacing.s2)
            Text("CSV + JSON archive of all your data.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
                .padding(.bottom, AuraSpacing.s2)
            if let exportURL {
                ShareLink(item: exportURL) {
                    HStack(spacing: AuraSpacing.s2) {
                        Image(systemName: "square.and.arrow.up")
                            .font(AuraFont.jakarta(16, .semibold))
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
            if let csvExportURL {
                ShareLink(item: csvExportURL) {
                    HStack(spacing: AuraSpacing.s2) {
                        Image(systemName: "tablecells")
                            .font(AuraFont.jakarta(16, .semibold))
                        Text("Export as CSV")
                            .font(AuraFont.body())
                    }
                    .foregroundColor(.aura.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.aura.fill)
                    .clipShape(RoundedRectangle(cornerRadius: AuraRadius.md))
                }
                .simultaneousGesture(TapGesture().onEnded { flash("CSV export ready") })
            } else {
                AuraGrayButton(label: csvBusy ? "Preparing…" : "Export as CSV") {}
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
        .task {
            guard csvExportURL == nil else { return }
            csvBusy = true
            csvExportURL = await CSVArchiveBuilder.writeTempZip(appState)
            csvBusy = false
        }
    }

    // Import
    private var importSheet: some View {
        VStack(spacing: AuraSpacing.s3) {
            Text("Import Data")
                .font(AuraFont.jakarta(17, .bold))
                .foregroundColor(.aura.text)
                .padding(.bottom, AuraSpacing.s2)
            Text("Import a JSON archive or CSV files exported from Aura.")
                .font(AuraFont.secondary())
                .foregroundColor(.aura.text2)
                .multilineTextAlignment(.center)
                .padding(.bottom, AuraSpacing.s2)
            AuraPrimaryButton(label: importBusy ? "Importing…" : "Choose File", isLoading: importBusy) {
                showFileImporter = true
            }
            .disabled(importBusy)
            .opacity(importBusy ? 0.6 : 1)
            AuraGrayButton(label: "Cancel") { dismiss() }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.json, .commaSeparatedText, .zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                importBusy = true
                Task {
                    let summary = await DataImportService.importFile(at: url, appState: appState)
                    importBusy = false
                    dismiss()
                    flash(summary)
                }
            case .failure:
                flash("Couldn't read that file")
            }
        }
    }

    // Reset (two options)
    private var resetSheet: some View {
        VStack(spacing: AuraSpacing.s3) {
            Text("Reset Data")
                .font(AuraFont.jakarta(17, .bold))
                .foregroundColor(.aura.text)
                .padding(.bottom, AuraSpacing.s2)
            SettingsGroup {
                Button {
                    // Confirm before executing, same as the full-wipe option.
                    showWorkoutResetConfirm = true
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
                                .font(AuraFont.jakarta(14, .semibold))
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
                    .font(AuraFont.jakarta(22, .semibold))
                    .foregroundColor(.aura.red)
            }
            .padding(.top, AuraSpacing.s2)
            Text(delete ? "Delete account?" : "Log out?")
                .font(AuraFont.jakarta(18, .bold))
                .foregroundColor(.aura.text)
            Text(delete
                 ? "This permanently erases your account and all synced + local data. This cannot be undone."
                 : "You can log back in anytime.")
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
