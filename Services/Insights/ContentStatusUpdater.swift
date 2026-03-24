import Foundation
import SwiftData

enum ContentStatusUpdater {
    
    static let validStatuses = ["Rascunho", "Planejado", "Publicado", "Concluído"]
    
    // MARK: - Status Transitions
    
    static func moveToPublished(
        item: SocialContentPlanItem,
        publishedAt: Date = .now,
        modelContext: ModelContext,
        initialEngagement: (likes: Int, comments: Int, shares: Int, reach: Int, impressions: Int, saves: Int, followers: Int)? = nil
    ) throws {
        item.status = "Publicado"
        item.publishedAt = publishedAt
        
        // If engagement data provided, create analytics record
        if let engagement = initialEngagement {
            let analytics = SocialContentAnalytics(
                contentPlanItemID: UUID().uuidString,
                contentType: item.contentType,
                objective: item.objective,
                pillar: item.pillar,
                publishedAt: publishedAt,
                likes: engagement.likes,
                comments: engagement.comments,
                shares: engagement.shares,
                reach: engagement.reach,
                impressions: engagement.impressions,
                saves: engagement.saves,
                followersAtPublish: engagement.followers,
                captureDate: .now
            )
            modelContext.insert(analytics)
        }
        
        try modelContext.save()
    }
    
    static func moveToScheduled(
        item: SocialContentPlanItem,
        scheduledDate: Date,
        modelContext: ModelContext
    ) throws {
        item.status = "Planejado"
        item.scheduledDate = scheduledDate
        try modelContext.save()
    }
    
    static func moveToCompleted(
        item: SocialContentPlanItem,
        completedAt: Date = .now,
        modelContext: ModelContext
    ) throws {
        item.status = "Concluído"
        item.completedAt = completedAt
        try modelContext.save()
    }
    
    static func moveToDraft(
        item: SocialContentPlanItem,
        modelContext: ModelContext
    ) throws {
        item.status = "Rascunho"
        try modelContext.save()
    }
    
    // MARK: - Status Queries
    
    static func canTransitionTo(_ fromStatus: String, _ toStatus: String) -> Bool {
        let transitions: [String: [String]] = [
            "Rascunho": ["Planejado", "Publicado"],
            "Planejado": ["Rascunho", "Publicado", "Concluído"],
            "Publicado": ["Concluído"],
            "Concluído": []
        ]
        
        return transitions[fromStatus]?.contains(toStatus) ?? false
    }
    
    static func statusColor(_ status: String) -> String {
        switch status {
        case "Rascunho":
            return "secondary"
        case "Planejado":
            return "accent"
        case "Publicado":
            return "success"
        case "Concluído":
            return "primary"
        default:
            return "secondary"
        }
    }
    
    static func statusIcon(_ status: String) -> String {
        switch status {
        case "Rascunho":
            return "doc.text"
        case "Planejado":
            return "calendar"
        case "Publicado":
            return "paperplane.fill"
        case "Concluído":
            return "checkmark.circle.fill"
        default:
            return "questionmark"
        }
    }
    
    static func daysPublished(_ item: SocialContentPlanItem) -> Int? {
        guard let publishedAt = item.publishedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: publishedAt, to: .now).day
    }
}
