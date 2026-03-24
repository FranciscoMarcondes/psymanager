import Foundation
import SwiftData

@Model
final class PlatformInsight {
    var platform: String // "Instagram", "Spotify", "SoundCloud", "YouTube", "Apple Music", "BeatPort"
    var followers: Int
    var reach: Int
    var impressions: Int
    var streams: Int? // Para plataformas de streaming
    var likes: Int
    var comments: Int
    var shares: Int
    var saves: Int
    var profileViews: Int
    var trackCount: Int? // Quantas faixas publicadas
    var totalMinutesStreamed: Int? // Minutos totais ouvidos
    var averageListenerAge: String? // Faixa de idade do público
    var topCountries: String? // Top 3 countries (JSON ou string)
    var monthlyListeners: Int? // Para Spotify
    var playlistInclusions: Int? // Em quantas playlists
    var capturedAt: Date
    var platformProfileUrl: String?
    
    init(
        platform: String,
        followers: Int = 0,
        reach: Int = 0,
        impressions: Int = 0,
        streams: Int? = nil,
        likes: Int = 0,
        comments: Int = 0,
        shares: Int = 0,
        saves: Int = 0,
        profileViews: Int = 0,
        trackCount: Int? = nil,
        totalMinutesStreamed: Int? = nil,
        averageListenerAge: String? = nil,
        topCountries: String? = nil,
        monthlyListeners: Int? = nil,
        playlistInclusions: Int? = nil,
        capturedAt: Date = .now,
        platformProfileUrl: String? = nil
    ) {
        self.platform = platform
        self.followers = followers
        self.reach = reach
        self.impressions = impressions
        self.streams = streams
        self.likes = likes
        self.comments = comments
        self.shares = shares
        self.saves = saves
        self.profileViews = profileViews
        self.trackCount = trackCount
        self.totalMinutesStreamed = totalMinutesStreamed
        self.averageListenerAge = averageListenerAge
        self.topCountries = topCountries
        self.monthlyListeners = monthlyListeners
        self.playlistInclusions = playlistInclusions
        self.capturedAt = capturedAt
        self.platformProfileUrl = platformProfileUrl
    }
}

@Model
final class ArtistCareerSnapshot {
    var capturedAt: Date
    
    // Aggregated metrics across all platforms
    var totalFollowers: Int
    var totalReach: Int
    var totalImpressions: Int
    var totalStreams: Int
    var totalListenerMinutes: Int
    var totalTracks: Int
    
    // Growth rates
    var followerGrowthRate: Double // % week-over-week
    var streamGrowthRate: Double
    var engagementRate: Double // (likes + comments + shares) / impressions
    
    // Platform breakdown (JSON string or normalized data)
    var platformBreakdown: String // JSON: {"Instagram": {data}, "Spotify": {data}, ...}
    
    // Career stage assessment
    var careerStage: String // "Emerging", "Growing", "Established", "Scaling"
    var dominantPlatform: String // Where they have most traction
    
    // Recommendations
    var nextMilestones: String // JSON array of recommendations
    var areasOfFocus: String // JSON: focus areas with reasoning
    
    // Audience insights
    var averageAudienceAge: String? // Aggregated across platforms
    var topCountries: String? // Top 3 countries
    var totalUniqueFans: Int? // Estimate across platforms
    
    init(
        totalFollowers: Int,
        totalReach: Int,
        totalImpressions: Int,
        totalStreams: Int,
        totalListenerMinutes: Int,
        totalTracks: Int,
        followerGrowthRate: Double = 0,
        streamGrowthRate: Double = 0,
        engagementRate: Double = 0,
        platformBreakdown: String = "{}",
        careerStage: String = "Emerging",
        dominantPlatform: String = "Unknown",
        nextMilestones: String = "[]",
        areasOfFocus: String = "{}",
        averageAudienceAge: String? = nil,
        topCountries: String? = nil,
        totalUniqueFans: Int? = nil,
        capturedAt: Date = .now
    ) {
        self.totalFollowers = totalFollowers
        self.totalReach = totalReach
        self.totalImpressions = totalImpressions
        self.totalStreams = totalStreams
        self.totalListenerMinutes = totalListenerMinutes
        self.totalTracks = totalTracks
        self.followerGrowthRate = followerGrowthRate
        self.streamGrowthRate = streamGrowthRate
        self.engagementRate = engagementRate
        self.platformBreakdown = platformBreakdown
        self.careerStage = careerStage
        self.dominantPlatform = dominantPlatform
        self.nextMilestones = nextMilestones
        self.areasOfFocus = areasOfFocus
        self.averageAudienceAge = averageAudienceAge
        self.topCountries = topCountries
        self.totalUniqueFans = totalUniqueFans
        self.capturedAt = capturedAt
    }
}

