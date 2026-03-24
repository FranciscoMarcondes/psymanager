import Foundation
import SwiftData

@Model
final class Conversation {
    @Attribute(.unique) var id: String
    var title: String
    var messages: [ManagerChatMessage]
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool
    var mode: String // "booking", "strategy", "bio", "reel"
    
    init(
        id: String = UUID().uuidString,
        title: String,
        messages: [ManagerChatMessage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isArchived: Bool = false,
        mode: String = "strategy"
    ) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
        self.mode = mode
    }
    
    /// Add a message to conversation and update timestamp
    func addMessage(_ message: ManagerChatMessage) {
        messages.append(message)
        updatedAt = Date()
    }
    
    /// Get conversation summary (last few messages)
    var summary: String {
        messages.suffix(2).map { $0.content }.joined(separator: " → ")
    }
}
