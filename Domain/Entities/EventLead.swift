import Foundation
import SwiftData

@Model
final class EventLead {
    var name: String
    var city: String
    var state: String
    var eventDate: Date
    var venue: String
    var instagramHandle: String
    var status: String
    var notes: String
    var promoter: PromoterContact?

    init(
        name: String,
        city: String,
        state: String,
        eventDate: Date,
        venue: String,
        instagramHandle: String,
        status: String,
        notes: String,
        promoter: PromoterContact? = nil
    ) {
        self.name = name
        self.city = city
        self.state = state
        self.eventDate = eventDate
        self.venue = venue
        self.instagramHandle = instagramHandle
        self.status = status
        self.notes = notes
        self.promoter = promoter
    }
}
