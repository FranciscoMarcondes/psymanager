import Foundation
import SwiftData

@Model
final class Negotiation {
    var stage: String
    var offeredFee: Double
    var desiredFee: Double
    var notes: String
    var nextActionDate: Date
    var createdAt: Date
    var promoter: PromoterContact?
    var lead: EventLead?

    init(
        stage: String,
        offeredFee: Double,
        desiredFee: Double,
        notes: String,
        nextActionDate: Date,
        createdAt: Date = .now,
        promoter: PromoterContact? = nil,
        lead: EventLead? = nil
    ) {
        self.stage = stage
        self.offeredFee = offeredFee
        self.desiredFee = desiredFee
        self.notes = notes
        self.nextActionDate = nextActionDate
        self.createdAt = createdAt
        self.promoter = promoter
        self.lead = lead
    }
}