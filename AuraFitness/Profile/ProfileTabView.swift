import SwiftUI

/// Which settings sub-screen the Profile mini-router is pushing (nil = root hub).
enum ProfileScreen: Hashable {
    case general, workout, account, notifications, units, connected, support
}

/// Which confirm sheet is open on Profile.
enum ProfileSheet: Identifiable {
    case export, reset, delete, logout
    var id: Int { hashValue }
}

/// Format a rest interval like the prototype's `fmtRest`: "45 s", "1 min", "1 min 30 s".
func fmtRest(_ s: Int) -> String {
    if s < 60 { return "\(s) s" }
    if s % 60 == 0 { return "\(s / 60) min" }
    return "\(s / 60) min \(s % 60) s"
}

struct ProfileTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var toast = ToastCenter()
    @State private var sheet: ProfileSheet? = nil

    // MARK: Derived stats
    var totalSessions: Int { appState.workoutLogs.count }
    var totalPRs: Int { appState.personalRecords.count }
    var streak: Int {
        var count = 0
        var day = Date()
        let cal = Calendar.current
        while appState.hasLog(for: day) {
            count += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return count
    }

    private var profile: UserProfile { appState.userProfile }
    private var initials: String {
        "\(profile.firstName.prefix(1))\(profile.lastName.prefix(1))"
    }
    private var identitySubtitle: String {
        let age = appState.bodyStats.age
        let h = UnitFormatter.length(appState.bodyStats.height, unit: appState.lengthUnit)
        let w = UnitFormatter.weight(appState.bodyStats.weight, unit: appState.weightUnit)
        return "\(age) · \(h) · \(w) · \(profile.gender)"
    }
    private var unitsSubtitle: String { "\(appState.weightUnit) · \(appState.lengthUnit)" }
    private var connectedSubtitle: String {
        appState.appleHealthConnected ? "Apple Health connected" : "None connected"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AuraSpacing.s4) {
                    identityCard
                    statTiles
                    groupGeneral
                    groupAccount
                    groupSupport
                    AuraDangerButton(label: "Log Out", icon: "rectangle.portrait.and.arrow.right") {
                        sheet = .logout
                    }
                    versionFooter
                }
                .padding(.horizontal, AuraSpacing.s4)
                .padding(.top, AuraSpacing.s3)
                .padding(.bottom, AuraSpacing.tabBarClearance)
            }
            .background(Color.aura.bgGrouped.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: ProfileScreen.self) { screen in
                switch screen {
                case .general:       GeneralSettingsView()
                case .workout:       WorkoutSettingsView()
                case .account:       AccountDetailsView()
                case .notifications: NotificationsSettingsView()
                case .units:         UnitsSettingsView()
                case .connected:     ConnectedAppsView()
                case .support:       SupportView()
                }
            }
            .sheet(item: $sheet) { which in
                ProfileConfirmSheet(kind: which, flash: { toast.flash($0) })
                    .environmentObject(appState)
                    .environmentObject(AuthService.shared)
            }
            .auraToast(toast)
            .onChange(of: appState.profileSaveFlash) { _, msg in
                if let msg {
                    toast.flash(msg)
                    appState.profileSaveFlash = nil
                }
            }
        }
    }

    // MARK: Identity card (tap → Account)
    private var identityCard: some View {
        NavigationLink(value: ProfileScreen.account) {
            HStack(spacing: AuraSpacing.s4) {
                AvatarCircle(initials: initials, size: 60, fontSize: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(profile.firstName) \(profile.lastName)")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.aura.text)
                    Text(identitySubtitle)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.aura.text3)
            }
            .padding(AuraSpacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(Color.aura.surface)
        .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
        .auraShadowSm()
    }

    // MARK: Three stat tiles
    private var statTiles: some View {
        HStack(spacing: AuraSpacing.s3) {
            StatTile(value: "\(totalSessions)", label: "Sessions")
            StatTile(value: "\(totalPRs)", label: "PRs")
            StatTile(value: "\(streak)", label: "Week streak")
        }
    }

    // MARK: Setting groups
    private var groupGeneral: some View {
        SettingsGroup {
            navRow("moon.fill", .aura.purple, "General", "Appearance, calendar, log page", .general)
            Divider().padding(.leading, 64)
            navRow("dumbbell.fill", .aura.accent, "Workout", "Targets, rest timer, display", .workout)
            Divider().padding(.leading, 64)
            navRow("bell.fill", .aura.blue, "Notifications", "Reminders & rest sounds", .notifications)
        }
    }

    private var groupAccount: some View {
        SettingsGroup {
            navRow("person.fill", .aura.text2, "Account Details", "Name, contact, export, delete", .account)
            Divider().padding(.leading, 64)
            navRow("ruler.fill", .aura.green, "Units & Measurements", unitsSubtitle, .units)
            Divider().padding(.leading, 64)
            navRow("flame.fill", .aura.red, "Connected Apps", connectedSubtitle, .connected)
        }
    }

    private var groupSupport: some View {
        SettingsGroup {
            navRow("info.circle.fill", .aura.text2, "Support", "Guides, FAQ, contact", .support)
        }
    }

    private func navRow(_ icon: String, _ color: Color, _ title: String, _ sub: String, _ dest: ProfileScreen) -> some View {
        NavigationLink(value: dest) {
            SettingsRowLabel(icon: icon, iconColor: color, title: title, subtitle: sub)
        }
        .buttonStyle(.plain)
    }

    private var versionFooter: some View {
        Text("Aura Fitness · v2.4.0")
            .font(AuraFont.secondary())
            .foregroundColor(.aura.text3)
            .frame(maxWidth: .infinity)
            .padding(.top, AuraSpacing.s2)
    }
}

// MARK: - Shared Profile building blocks

/// Gradient initials avatar (accent → warm orange), matching the prototype.
struct AvatarCircle: View {
    let initials: String
    var size: CGFloat = 60
    var fontSize: CGFloat = 22

    var body: some View {
        Text(initials)
            .font(.system(size: fontSize, weight: .heavy))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [.aura.accent, Color(hex: "#D9722E")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }
}

/// A grouped settings card (surface, rounded, shadow) wrapping its rows.
struct SettingsGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color.aura.surface)
            .clipShape(RoundedRectangle(cornerRadius: AuraRadius.lg))
            .auraShadowSm()
    }
}

/// A leading-icon settings row label (no built-in action — wrap in NavigationLink/Button).
struct SettingsRowLabel: View {
    let icon: String
    var iconColor: Color = .aura.accent
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: AuraSpacing.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconColor)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AuraFont.body())
                    .foregroundColor(.aura.text)
                if let subtitle {
                    Text(subtitle)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
            }
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.aura.text3)
            }
        }
        .padding(.horizontal, AuraSpacing.s4)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

/// Section label used inside settings sub-screens.
struct SettingsSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.aura.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AuraSpacing.s4)
            .padding(.bottom, AuraSpacing.s2)
    }
}

/// A plain value/title row inside a settings card (for toggles, segs, steppers).
struct SettingsControlRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var iconName: String? = nil
    var iconColor: Color = .aura.accent
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: AuraSpacing.s3) {
            if let iconName {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(iconColor)
                        .frame(width: 32, height: 32)
                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AuraFont.body())
                    .foregroundColor(.aura.text)
                if let subtitle {
                    Text(subtitle)
                        .font(AuraFont.secondary())
                        .foregroundColor(.aura.text2)
                }
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, AuraSpacing.s4)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}
