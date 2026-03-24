import Foundation
import SwiftData

@Model
final class CareerTask {
    var title: String
    var detail: String
    var priority: String
    var dueDate: Date
    var completed: Bool

    init(
        title: String,
        detail: String,
        priority: String,
        dueDate: Date,
        completed: Bool = false
    ) {
        self.title = title
        self.detail = detail
        self.priority = priority
        self.dueDate = dueDate
        self.completed = completed
    }
}
