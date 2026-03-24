import Foundation
import SwiftData

@Model
final class SocialContentAnalytics {
    var contentPlanItemID: String
    var contentType: String
    var objective: String
    var pillar: String
    var publishedAt: Date
    
    // Raw metrics
    var likes: Int
    var comments: Int
    var shares: Int
    var reach: Int
    var impressions: Int
    var saves: Int
    
    // Captured for trend analysis
    var followersAtPublish: Int
    
    // Derived metrics (computed for convenience)
    var engagementRate: Double {
        impressions > 0 ? Double(likes + comments + shares) / Double(impressions) * 100 : 0
    }
    
    var reachPerPost: Double {
        max(1, Double(reach))
    }
    
    var captureDate: Date

    init(
        contentPlanItemID: String,
        contentType: String,
        objective: String,
        pillar: String,
        publishedAt: Date,
        likes: Int = 0,
        comments: Int = 0,
        shares: Int = 0,
        reach: Int = 0,
        impressions: Int = 0,
        saves: Int = 0,
        followersAtPublish: Int = 0,
        captureDate: Date = .now
    ) {
        self.contentPlanItemID = contentPlanItemID
        self.contentType = contentType
        self.objective = objective
        self.pillar = pillar
        self.publishedAt = publishedAt
        self.likes = likes
        self.comments = comments
        self.shares = shares
        self.reach = reach
        self.impressions = impressions
        self.saves = saves
        self.followersAtPublish = followersAtPublish
        self.captureDate = captureDate
    }
}
