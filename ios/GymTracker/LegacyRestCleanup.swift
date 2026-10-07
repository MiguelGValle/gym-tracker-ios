import Foundation
import UserNotifications

/// Cancel timers scheduled by an older build without touching workout data.
enum LegacyRestCleanup {
    static func clear(defaults: UserDefaults = .standard) {
        let savedRequest = defaults.string(forKey: "gymtracker.rest.request")
        let identifiers = ["gymtracker.rest.finished"] + (savedRequest.map { [$0] } ?? [])
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        for key in ["gymtracker.rest.deadline", "gymtracker.rest.exercise", "gymtracker.rest.request"] {
            defaults.removeObject(forKey: key)
        }
    }
}
