import EventKit
import Foundation

@MainActor
final class CalendarService {
    private let eventStore = EKEventStore()

    func createGigEvent(for gig: Gig) async throws {
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = gig.title
        event.startDate = gig.date
        event.endDate = gig.date.addingTimeInterval(2 * 60 * 60)
        event.notes = "Contato: \(gig.contactName)\nChecklist: \(gig.checklistSummary)"
        event.calendar = eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent)
    }
}
