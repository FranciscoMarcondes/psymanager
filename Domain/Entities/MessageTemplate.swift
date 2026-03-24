import Foundation
import SwiftData

@Model
final class MessageTemplate {
    var title: String
    var body: String
    var category: String
    var isFavorite: Bool
    var createdAt: Date

    init(
        title: String,
        body: String,
        category: String,
        isFavorite: Bool = false,
        createdAt: Date = .now
    ) {
        self.title = title
        self.body = body
        self.category = category
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }
}