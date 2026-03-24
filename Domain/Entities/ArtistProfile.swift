import Foundation
import SwiftData

@Model
final class ArtistProfile {
    var stageName: String
    var genre: String
    var city: String
    var state: String
    var artistStage: String
    var toneOfVoice: String
    var mainGoal: String
    var contentFocus: String
    var visualIdentity: String
    var instagramHandle: String
    var spotifyHandle: String
    var soundCloudHandle: String
    var youTubeHandle: String
    var createdAt: Date
    var updatedAt: Date

    init(
        stageName: String,
        genre: String,
        city: String,
        state: String,
        artistStage: String,
        toneOfVoice: String,
        mainGoal: String,
        contentFocus: String,
        visualIdentity: String,
        instagramHandle: String = "",
        spotifyHandle: String = "",
        soundCloudHandle: String = "",
        youTubeHandle: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.stageName = stageName
        self.genre = genre
        self.city = city
        self.state = state
        self.artistStage = artistStage
        self.toneOfVoice = toneOfVoice
        self.mainGoal = mainGoal
        self.contentFocus = contentFocus
        self.visualIdentity = visualIdentity
        self.instagramHandle = instagramHandle
        self.spotifyHandle = spotifyHandle
        self.soundCloudHandle = soundCloudHandle
        self.youTubeHandle = youTubeHandle
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
