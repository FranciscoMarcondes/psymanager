import Foundation
import SwiftData

@Model
final class ManagerChatMessage {
    var role: String
    var text: String
    var createdAt: Date

    init(role: String, text: String, createdAt: Date = .now) {
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}
