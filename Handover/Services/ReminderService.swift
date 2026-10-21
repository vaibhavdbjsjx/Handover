import Foundation
import UserNotifications

/// Schedules local reminders for compliance dates. Nothing leaves the device.
enum ReminderService {
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func schedule(_ item: ComplianceItem) {
        cancel(item)
        guard let expiresAt = item.expiresAt else { return }
        let center = UNUserNotificationCenter.current()
        let propertyName = item.property?.displayName ?? "your property"

        var fireDates: [(String, Date, String)] = []
        if let early = Calendar.current.date(byAdding: .day, value: -item.reminderDaysBefore, to: expiresAt) {
            fireDates.append(("early", early, "\(item.title) for \(propertyName) is due in \(item.reminderDaysBefore) days."))
        }
        fireDates.append(("due", expiresAt, "\(item.title) for \(propertyName) is due today."))

        for (suffix, date, body) in fireDates {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
            components.hour = 9
            components.minute = 0
            guard let fire = Calendar.current.date(from: components), fire > .now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Compliance reminder"
            content.body = body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "\(item.id.uuidString)-\(suffix)", content: content, trigger: trigger)
            center.add(request)
        }
    }

    static func cancel(_ item: ComplianceItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["\(item.id.uuidString)-early", "\(item.id.uuidString)-due"])
    }
}
