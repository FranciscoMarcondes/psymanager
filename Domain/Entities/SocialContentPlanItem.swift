import Foundation
import SwiftData

@Model
final class SocialContentPlanItem {
    var title: String
    var contentType: String
    var objective: String
    var status: String // "Rascunho", "Planejado", "Publicado", "Concluído"
    var scheduledDate: Date
    var pillar: String
    var hook: String
    var caption: String
    var cta: String
    var hashtags: String
    var notes: String
    var linkedGigLabel: String
    var createdAt: Date
    var publishedAt: Date?
    var completedAt: Date?

    init(
        title: String,
        contentType: String,
        objective: String,
        status: String,
        scheduledDate: Date,
        pillar: String,
        hook: String,
        caption: String,
        cta: String,
        hashtags: String,
        notes: String = "",
        linkedGigLabel: String = "",
        createdAt: Date = .now,
        publishedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.title = title
        self.contentType = contentType
        self.objective = objective
        self.status = status
        self.scheduledDate = scheduledDate
        self.pillar = pillar
        self.hook = hook
        self.caption = caption
        self.cta = cta
        self.hashtags = hashtags
        self.notes = notes
        self.linkedGigLabel = linkedGigLabel
        self.createdAt = createdAt
        self.publishedAt = publishedAt
        self.completedAt = completedAt
    }
}