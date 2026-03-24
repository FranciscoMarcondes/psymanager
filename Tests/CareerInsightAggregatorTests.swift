import XCTest
@testable import PsyManager

final class CareerInsightAggregatorTests: XCTestCase {
    func testBuildCareerSnapshotAggregatesTotalsCorrectly() {
        let insights = [
            PlatformInsight(platform: "Spotify", followers: 400, reach: 300, impressions: 600, streams: 1000, likes: 20, comments: 4, shares: 2, trackCount: 3),
            PlatformInsight(platform: "YouTube", followers: 600, reach: 700, impressions: 1400, streams: 2000, likes: 60, comments: 12, shares: 8, trackCount: 5),
        ]

        let snapshot = CareerInsightAggregator.buildCareerSnapshot(from: insights)

        XCTAssertEqual(snapshot.totalFollowers, 1000)
        XCTAssertEqual(snapshot.totalStreams, 3000)
        XCTAssertEqual(snapshot.totalReach, 1000)
        XCTAssertEqual(snapshot.totalImpressions, 2000)
        XCTAssertEqual(snapshot.totalTracks, 8)
        XCTAssertEqual(snapshot.careerStage, "Growing")
        XCTAssertEqual(snapshot.dominantPlatform, "YouTube")
    }

    func testBuildCareerSnapshotReturnsEmergingForLowFollowers() {
        let insights = [
            PlatformInsight(platform: "Spotify", followers: 300, streams: 1200),
            PlatformInsight(platform: "SoundCloud", followers: 250, streams: 800),
        ]

        let snapshot = CareerInsightAggregator.buildCareerSnapshot(from: insights)

        XCTAssertEqual(snapshot.totalFollowers, 550)
        XCTAssertEqual(snapshot.careerStage, "Emerging")
    }

    func testBuildCareerSnapshotReturnsEstablishedForMidScaleFollowers() {
        let insights = [
            PlatformInsight(platform: "Spotify", followers: 7000, streams: 40000),
            PlatformInsight(platform: "YouTube", followers: 5500, streams: 70000),
        ]

        let snapshot = CareerInsightAggregator.buildCareerSnapshot(from: insights)

        XCTAssertEqual(snapshot.totalFollowers, 12500)
        XCTAssertEqual(snapshot.careerStage, "Established")
    }
}
