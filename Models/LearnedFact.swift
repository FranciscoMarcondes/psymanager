import Foundation
import SwiftData

/// LearnedFact — Persistent insights learned during Manager AI conversations
/// Categories: preference, pricing, location, availability, technical
@Model
final class LearnedFact {
    @Attribute(.unique) var id: String
    var content: String
    var category: String
    var confidence: Double // 0.0-1.0
    var source: String // chat_history, user_explicit, manual_entry
    var extractedAt: Date
    var lastUsedInChat: Date?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        content: String,
        category: String,
        confidence: Double = 0.7,
        source: String = "chat_history",
        extractedAt: Date = .now,
        createdAt: Date = .now
    ) {
        self.id = id
        self.content = content
        self.category = category
        self.confidence = confidence
        self.source = source
        self.extractedAt = extractedAt
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.lastUsedInChat = nil
    }
    
    /// Refresh last used timestamp
    func markAsUsed() {
        self.lastUsedInChat = .now
        self.updatedAt = .now
    }
}
