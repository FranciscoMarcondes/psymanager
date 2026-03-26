import Foundation
import SwiftData

@Model
final class Gig {
    var title: String
    var city: String
    var state: String
    var date: Date
    var fee: Double
    var contactName: String
    var checklistSummary: String
    var status: String = "Confirmado" // "Confirmado", "Negociacao", "Lead"
    var addedToCalendar: Bool
    var reminderScheduled: Bool

    init(
        title: String,
        city: String,
        state: String,
        date: Date,
        fee: Double,
        contactName: String,
        checklistSummary: String,
        status: String = "Confirmado",
        addedToCalendar: Bool = false,
        reminderScheduled: Bool = false
    ) {
        self.title = title
        self.city = city
        self.state = state
        self.date = date
        self.fee = fee
        self.contactName = contactName
        self.checklistSummary = checklistSummary
        self.status = status
        self.addedToCalendar = addedToCalendar
        self.reminderScheduled = reminderScheduled
    }
}
