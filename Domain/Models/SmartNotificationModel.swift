import Foundation

struct SmartNotificationModel: Identifiable {
    let id: UUID = UUID()
    let activityId: UUID
    let title: String
    let description: String
    let type: NotificationType
    let createdAt: Date = Date()
    
    enum NotificationType {
        case alert
        case info
        case success
        case warning
    }
}
