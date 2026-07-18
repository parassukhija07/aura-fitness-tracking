import UserNotifications

/// §5.5 — local notification for rest-timer completion, gated by the
/// Profile "Notifications" toggle. Scheduled at rest-start (not fired from
/// the in-app countdown tick) so it still delivers if the app is backgrounded.
enum NotificationScheduler {
    private static let restCompleteID = "aura.rest.complete"

    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    /// Schedules (replacing any pending one) a rest-complete notification to
    /// fire `seconds` from now. No-op if notifications are disabled in
    /// settings or the user hasn't granted permission.
    static func scheduleRestComplete(in seconds: Int, sound: String, enabled: Bool) {
        cancelRestComplete()
        guard enabled, seconds > 0 else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = "Time for your next set."
            // `.defaultCritical` needs the Critical Alerts entitlement (not
            // configured for this app), so both sound choices map to the
            // standard system sound for now — the picker still records the
            // user's preference for when that entitlement is added.
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
            let request = UNNotificationRequest(identifier: restCompleteID, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelRestComplete() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restCompleteID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [restCompleteID])
    }
}
