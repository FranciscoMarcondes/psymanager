import XCTest
@testable import PsyManager

final class BookingNegotiationCoachTests: XCTestCase {
    func testCoachingBriefSuggestsCounterOfferAboveLowOffer() {
        let lead = EventLead(
            name: "Forest Ritual",
            city: "Sao Paulo",
            state: "SP",
            eventDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date(),
            venue: "Hangar Stage",
            instagramHandle: "@forest",
            status: LeadStatus.negotiating.rawValue,
            notes: ""
        )

        let negotiation = Negotiation(
            stage: LeadStatus.negotiating.rawValue,
            offeredFee: 1000,
            desiredFee: 2000,
            notes: "sem resposta",
            nextActionDate: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            lead: lead
        )

        let brief = BookingNegotiationCoach.coachingBrief(for: negotiation, lead: lead)

        XCTAssertGreaterThan(brief.suggestedCounterOffer, 1000)
        XCTAssertTrue(["Médio", "Alto"].contains(brief.riskLevel))
        XCTAssertTrue(brief.suggestedReply.contains("R$"))
    }

    func testSuggestedMessagesIncludeWhyForEveryStatus() {
        let lead = EventLead(
            name: "Nebula Stage",
            city: "Campinas",
            state: "SP",
            eventDate: Calendar.current.date(byAdding: .day, value: 20, to: Date()) ?? Date(),
            venue: "Arena",
            instagramHandle: "@nebula",
            status: LeadStatus.notContacted.rawValue,
            notes: ""
        )

        let statuses = [
            LeadStatus.notContacted.rawValue,
            LeadStatus.waitingReply.rawValue,
            LeadStatus.negotiating.rawValue,
        ]

        for status in statuses {
            let suggestions = BookingNegotiationCoach.suggestedMessages(for: lead, status: status)
            XCTAssertFalse(suggestions.isEmpty)
            XCTAssertTrue(suggestions.allSatisfy { !$0.text.isEmpty && !$0.why.isEmpty })
        }
    }
}
