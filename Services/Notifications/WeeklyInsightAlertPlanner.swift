import Foundation
import UserNotifications

@MainActor
final class WeeklyInsightAlertPlanner {
    func scheduleWeeklySummaryNotification(recommendation: String) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Resumo semanal do PsyManager"
        content.body = recommendation
        content.sound = .default

        var components = DateComponents()
        components.weekday = 2
        components.hour = 10
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly-insight-summary", content: content, trigger: trigger)
        try await center.add(request)
    }

    func removeWeeklySummaryNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["weekly-insight-summary"])
    }
}
