import Foundation
import SwiftData

// MARK: - ViewModel for simplified dashboard state management
@MainActor
class DashboardViewModel: ObservableObject {
    @Published var dashboardMode: DashboardMode = .focus
    
    // Consolidated data queries
    var gigs: [Gig]
    var tasks: [CareerTask]
    var leads: [EventLead]
    var negotiations: [Negotiation]
    var insights: [SocialInsightSnapshot]
    
    init(
        gigs: [Gig],
        tasks: [CareerTask],
        leads: [EventLead],
        negotiations: [Negotiation],
        insights: [SocialInsightSnapshot]
    ) {
        self.gigs = gigs
        self.tasks = tasks
        self.leads = leads
        self.negotiations = negotiations
        self.insights = insights
    }
    
    // MARK: - Computed Properties (simplified metrics)
    
    var outreachLeadsCount: Int {
        leads.filter { $0.status != LeadStatus.notContacted.rawValue }.count
    }
    
    var responseRateText: String {
        guard outreachLeadsCount > 0 else { return "0%" }
        let responded = leads.filter {
            $0.status == LeadStatus.waitingReply.rawValue ||
            $0.status == LeadStatus.negotiating.rawValue ||
            $0.status == LeadStatus.closed.rawValue
        }.count
        let value = Double(responded) / Double(outreachLeadsCount) * 100
        return "\(Int(value.rounded()))%"
    }
    
    var closedDealsCount: Int {
        negotiations.filter { $0.stage == LeadStatus.closed.rawValue }.count
    }
    
    var overdueFollowupsCount: Int {
        negotiations.filter { $0.nextActionDate < Date() && $0.stage != LeadStatus.closed.rawValue }.count
    }
    
    var todayTaskItems: [String] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()
        
        var items: [String] = []
        
        let dueTodayTasks = tasks.filter { $0.dueDate >= startOfToday && $0.dueDate < endOfToday && !$0.completed }
        items.append(contentsOf: dueTodayTasks.map { "Concluir: \($0.title)" })
        
        let overdueNegotiations = negotiations.filter { $0.nextActionDate < Date() && $0.stage != LeadStatus.closed.rawValue }
        items.append(contentsOf: overdueNegotiations.prefix(2).map { _ in "Enviar follow-up pendente" })
        
        if let nearGig = gigs.first(where: { $0.date < calendar.date(byAdding: .hour, value: 36, to: Date()) ?? Date.distantFuture }) {
            items.append("Revisar: \(nearGig.title)")
        }
        
        if items.isEmpty {
            items.append("Sem urgências. Avance em prospecção.")
        }
        
        return Array(items.prefix(4))
    }
    
    var nextUpcomingGig: Gig? {
        gigs.sorted { $0.date < $1.date }.first(where: { $0.date > Date() })
    }
    
    var weeklySeries: [WeeklyPoint] {
        let calendar = Calendar.current
        return (0 ..< 4).compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -(3 - offset), to: calendar.startOfDay(for: Date())),
                  let end = calendar.date(byAdding: .day, value: 7, to: start)
            else { return nil }
            
            let weeklyLeads = leads.filter { $0.eventDate >= start && $0.eventDate < end }.count
            let weeklyClosed = negotiations.filter {
                $0.createdAt >= start &&
                $0.createdAt < end &&
                $0.stage == LeadStatus.closed.rawValue
            }.count
            
            return WeeklyPoint(label: "S\(offset + 1)", leads: weeklyLeads, closed: weeklyClosed)
        }
    }
    
    enum DashboardMode: String, CaseIterable, Identifiable {
        case focus = "Foco"
        case complete = "Completo"
        var id: String { rawValue }
    }
}

// MARK: - Data Models
struct WeeklyPoint: Identifiable {
    let id = UUID()
    let label: String
    let leads: Int
    let closed: Int
}

struct BookingOpportunity: Identifiable {
    let id = UUID()
    let leadName: String
    let opportunity: String
    let priority: String
}
