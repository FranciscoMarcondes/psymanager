import Foundation
import SwiftData

@Model
final class TripPlan {
    var fromCity: String
    var fromState: String
    var toCity: String
    var toState: String
    var dateISO: String          // "yyyy-MM-dd"
    var transport: String        // "Carro", "Avião", "Ônibus"
    var budget: String
    var notes: String

    init(
        fromCity: String,
        fromState: String,
        toCity: String,
        toState: String,
        dateISO: String,
        transport: String,
        budget: String = "",
        notes: String = ""
    ) {
        self.fromCity = fromCity
        self.fromState = fromState
        self.toCity = toCity
        self.toState = toState
        self.dateISO = dateISO
        self.transport = transport
        self.budget = budget
        self.notes = notes
    }
}
