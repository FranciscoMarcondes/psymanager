import Foundation
import XCTest
@testable import PsyManager

final class CareerAreaPrioritizerTests: XCTestCase {
    func testBuildWeeklyPrioritiesReturnsAllAreas() {
        let profile = ArtistProfile(
            stageName: "DJ Test",
            genre: "Psytrance",
            city: "Sao Paulo",
            state: "SP",
            artistStage: ArtistStage.growing.rawValue,
            toneOfVoice: "Confiante",
            mainGoal: "Suporte 360",
            contentFocus: "Reels",
            visualIdentity: "Neon"
        )

        let priorities = CareerAreaPrioritizer.buildWeeklyPriorities(
            profile: profile,
            gigs: [],
            leads: [],
            negotiations: [],
            tasks: [],
            snapshots: [],
            promoters: [],
            latestCareerSnapshot: nil
        )

        XCTAssertEqual(priorities.count, CareerArea.allCases.count)
        XCTAssertEqual(Set(priorities.map { $0.area.rawValue }).count, CareerArea.allCases.count)
    }

    func testBuildWeeklyPrioritiesRaisesLogisticsWhenGigIsNear() {
        let profile = ArtistProfile(
            stageName: "DJ Test",
            genre: "Psytrance",
            city: "Sao Paulo",
            state: "SP",
            artistStage: ArtistStage.growing.rawValue,
            toneOfVoice: "Confiante",
            mainGoal: "Suporte 360",
            contentFocus: "Reels",
            visualIdentity: "Neon"
        )

        let soonGig = Gig(
            title: "Gig SP",
            city: "Campinas",
            state: "SP",
            date: Date().addingTimeInterval(60 * 60 * 24),
            fee: 3000,
            contactName: "Promoter",
            checklistSummary: ""
        )

        let priorities = CareerAreaPrioritizer.buildWeeklyPriorities(
            profile: profile,
            gigs: [soonGig],
            leads: [],
            negotiations: [],
            tasks: [],
            snapshots: [],
            promoters: [],
            latestCareerSnapshot: nil
        )

        let logistics = priorities.first { $0.area == CareerArea.logistics }
        XCTAssertNotNil(logistics)
        XCTAssertGreaterThanOrEqual(logistics?.score ?? 0, 70)
    }
}
