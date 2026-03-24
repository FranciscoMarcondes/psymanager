import Foundation
import SwiftData

@Model
final class SocialInsightSnapshot {
    var periodLabel: String
    var periodStart: Date
    var periodEnd: Date
    var followersStart: Int
    var followersEnd: Int
    var reach: Int
    var impressions: Int
    var profileVisits: Int
    var reelViews: Int
    var postsPublished: Int
    var source: String
    var createdAt: Date

    init(
        periodLabel: String,
        periodStart: Date,
        periodEnd: Date,
        followersStart: Int,
        followersEnd: Int,
        reach: Int,
        impressions: Int,
        profileVisits: Int,
        reelViews: Int,
        postsPublished: Int,
        source: String = "manual",
        createdAt: Date = .now
    ) {
        self.periodLabel = periodLabel
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.followersStart = followersStart
        self.followersEnd = followersEnd
        self.reach = reach
        self.impressions = impressions
        self.profileVisits = profileVisits
        self.reelViews = reelViews
        self.postsPublished = postsPublished
        self.source = source
        self.createdAt = createdAt
    }
}

