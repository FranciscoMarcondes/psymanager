import Foundation
import UserNotifications

@MainActor
final class NotificationPlanner {
    func scheduleGigReminder(for gig: Gig) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Gig chegando"
        content.body = "Revise checklist e contato de \(gig.title) em \(gig.city)."
        content.sound = .default

        let reminderDate = Calendar.current.date(byAdding: .hour, value: -24, to: gig.date) ?? gig.date
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        try await center.add(request)
    }

    func scheduleTaskReminder(for task: CareerTask) async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "Follow-up de booking"
        content.body = "Tarefa: \(task.title). \(task.detail)"
        content.sound = .default

        let now = Date()
        let preferredReminder = Calendar.current.date(byAdding: .hour, value: -2, to: task.dueDate) ?? task.dueDate
        let minimumFuture = Calendar.current.date(byAdding: .minute, value: 1, to: now) ?? now
        let reminderDate = max(preferredReminder, minimumFuture)

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "task-\(task.persistentModelID)", content: content, trigger: trigger)
        try await center.add(request)
    }
}
