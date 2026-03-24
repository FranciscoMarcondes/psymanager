import Foundation
import SwiftData

@Model
final class RadarEvent {
    var eventName: String
    var city: String
    var state: String
    var dateISO: String          // "yyyy-MM-dd"
    var instagramHandle: String

    init(
        eventName: String,
        city: String,
        state: String,
        dateISO: String,
        instagramHandle: String = ""
    ) {
        self.eventName = eventName
        self.city = city
        self.state = state
        self.dateISO = dateISO
        self.instagramHandle = instagramHandle
    }
}
