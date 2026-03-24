import Foundation
import SwiftData

@Model
final class Expense {
    var dateISO: String          // "yyyy-MM-dd"
    var descriptionText: String
    var amount: Double
    var category: String
    var notes: String

    init(
        dateISO: String,
        descriptionText: String,
        amount: Double,
        category: String,
        notes: String = ""
    ) {
        self.dateISO = dateISO
        self.descriptionText = descriptionText
        self.amount = amount
        self.category = category
        self.notes = notes
    }
}
