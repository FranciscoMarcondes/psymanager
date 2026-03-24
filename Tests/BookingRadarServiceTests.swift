import XCTest
@testable import PsyManager

final class BookingRadarServiceTests: XCTestCase {
    func testTopOpportunitiesReturnsSortedScores() {
        let profile = ArtistProfile(
            stageName: "Demo Artist",
            genre: "Psytrance",
            city: "Sao Paulo",
            state: "SP",
            artistStage: "Em crescimento",
            toneOfVoice: "Direto",
            mainGoal: "Booking",
            contentFocus: "Reels",
            visualIdentity: "Neon"
        )

        let nearLead = EventLead(
            name: "Psy Gate",
            city: "Sao Paulo",
            state: "SP",
            eventDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date(),
            venue: "Arena",
            instagramHandle: "@psygate",
            status: LeadStatus.notContacted.rawValue,
            notes: "publico psy"
        )

        let farLead = EventLead(
            name: "Trance Desert",
            city: "Rio",
            state: "RJ",
            eventDate: Calendar.current.date(byAdding: .day, value: 120, to: Date()) ?? Date(),
            venue: "Open Air",
            instagramHandle: "@trancedesert",
            status: LeadStatus.messageSent.rawValue,
            notes: ""
        )

        let opportunities = BookingRadarService.topOpportunities(
            profile: profile,
            leads: [nearLead, farLead],
            negotiations: [],
            limit: 5
        )

        XCTAssertEqual(opportunities.count, 2)
        XCTAssertEqual(opportunities.first?.lead.name, "Psy Gate")
        XCTAssertTrue((opportunities.first?.score ?? 0) >= (opportunities.last?.score ?? 0))
    }

    func testNegotiationSignalsReflectStageAndFeeGap() {
        let lead = EventLead(
            name: "Open Psy",
            city: "Campinas",
            state: "SP",
            eventDate: Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date(),
            venue: "Hangar",
            instagramHandle: "@openpsy",
            status: LeadStatus.negotiating.rawValue,
            notes: ""
        )

        let strong = Negotiation(
            stage: LeadStatus.negotiating.rawValue,
            offeredFee: 1500,
            desiredFee: 1400,
            notes: "ok para fechar",
            nextActionDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            lead: lead
        )

        let weak = Negotiation(
            stage: LeadStatus.waitingReply.rawValue,
            offeredFee: 700,
            desiredFee: 1500,
            notes: "sem resposta",
            nextActionDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            lead: lead
        )

        let signals = BookingRadarService.negotiationSignals([strong, weak])

        XCTAssertEqual(signals.count, 2)
        XCTAssertTrue(signals[0].probability >= signals[1].probability)
    }

    func testBuildTaskDraftUsesHighPriorityWhenCloseProbabilityIsHigh() {
        let lead = EventLead(
            name: "Solar Trance",
            city: "Sao Paulo",
            state: "SP",
            eventDate: Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date(),
            venue: "Main Stage",
            instagramHandle: "@solartrance",
            status: LeadStatus.negotiating.rawValue,
            notes: ""
        )

        let opportunity = BookingOpportunity(
            id: lead.persistentModelID,
            lead: lead,
            score: 82,
            closeProbability: 78,
            action: "Enviar proposta final"
        )

        let draft = BookingRadarService.buildTaskDraft(for: opportunity, referenceDate: Date())

        XCTAssertEqual(draft.title, "Booking: Solar Trance")
        XCTAssertEqual(draft.priority, TaskPriority.high.rawValue)
        XCTAssertTrue(draft.detail.contains("Main Stage"))
    }
}
