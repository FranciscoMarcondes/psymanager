import SwiftUI
import SwiftData

/// Service for deep-linking from AI actions to relevant modules with context pre-filled
/// Enables insight → action execution in <1 tap through navigation state
struct NavigationActionService {
    
    enum ActionDestination {
        case createContent(title: String, pillar: String)
        case editLead(leadName: String)
        case scheduleGig(eventName: String)
        case addTask(taskTitle: String)
        case reviewInsight(title: String)
        case planTrip(destination: String)
        case recordExpense(amount: Double, category: String)
        case negotiateLead(leadName: String, amount: Double)
        
        var description: String {
            switch self {
            case .createContent(let title, _): return "Criar: \(title)"
            case .editLead(let name): return "Contatar: \(name)"
            case .scheduleGig(let event): return "Agendar: \(event)"
            case .addTask(let title): return "Tarefa: \(title)"
            case .reviewInsight(let title): return "Insight: \(title)"
            case .planTrip(let dest): return "Viagem: \(dest)"
            case .recordExpense(let amt, _): return "Gasto: R$ \(String(format: "%.2f", amt))"
            case .negotiateLead(let name, let amt): return "Negociar \(name) - R$ \(String(format: "%.2f", amt))"
            }
        }
    }
    
    // MARK: - Navigation State Management
    
    static func navigateToAction(_ action: QuickActionService.QuickAction, modelContext: ModelContext) {
        let destination = extractDestination(from: action, modelContext: modelContext)
        applyNavigation(destination)
    }
    
    // MARK: - Extract Destination from Action
    
    private static func extractDestination(
        from action: QuickActionService.QuickAction,
        modelContext: ModelContext
    ) -> ActionDestination {
        switch action.type {
        case .createContent:
            let contentType = action.extractedData["content_type"] ?? "Post"
            let pillar = action.extractedData["pillar"] ?? "Engagement"
            return .createContent(title: contentType, pillar: pillar)
            
        case .followUpLead:
            let leadName = action.extractedData["lead_name"] ?? "Lead"
            return .editLead(leadName: leadName)
            
        case .scheduleGig:
            let eventName = action.extractedData["event_name"] ?? "Show"
            return .scheduleGig(eventName: eventName)
            
        case .addTask:
            let title = action.extractedData["source_text"] ?? "Nova tarefa"
            return .addTask(taskTitle: title)
            
        case .captureInsight:
            let insight = action.extractedData["insight"] ?? action.title
            return .reviewInsight(title: insight)
            
        case .planEvent:
            let location = action.extractedData["location"] ?? "Próximo destino"
            return .planTrip(destination: location)
            
        case .addExpense:
            let amount = Double(action.extractedData["amount"] ?? "0") ?? 0
            let category = action.extractedData["category"] ?? "Investimento"
            return .recordExpense(amount: amount, category: category)
            
        case .negotiateLead:
            let leadName = action.extractedData["lead_name"] ?? "Lead"
            let amount = Double(action.extractedData["amount"] ?? "0") ?? 0
            return .negotiateLead(leadName: leadName, amount: amount)
        }
    }
    
    private static func applyNavigation(_ destination: ActionDestination) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.3)) {
                switch destination {
                case .createContent(let title, let pillar):
                    // Navigate to Creation Studio with prefilled data
                    let context: [String: String] = [
                        "title": title,
                        "pillar": pillar,
                        "source": "manager_suggestion"
                    ]
                    NotificationCenter.default.post(
                        name: NSNotification.Name("navigateWithContext"),
                        object: nil,
                        userInfo: ["destination": "studio", "context": context]
                    )
                    
                case .editLead(let leadName):
                    // Navigate to Events/Leads with search/filter
                    NotificationCenter.default.post(
                        name: NSNotification.Name("navigateWithContext"),
                        object: nil,
                        userInfo: [
                            "destination": "events",
                            "context": ["searchTerm": leadName, "tab": "leads"]
                        ]
                    )
                    
                case .scheduleGig(let eventName):
                    // Navigate to Events with create gig mode
                    NotificationCenter.default.post(
                        name: NSNotification.Name("navigateWithContext"),
                        object: nil,
                        userInfo: [
                            "destination": "events",
                            "context": ["action": "create_gig", "eventName": eventName]
                        ]
                    )
                    
                case .addTask(let taskTitle):
                    // Navigate to Dashboard with quick-add modal
                    NotificationCenter.default.post(
                        name: NSNotification.Name("navigateWithContext"),
                        object: nil,
                        userInfo: [
                            "destination": "dashboard",
                            "context": ["showQuickTask": "true", "taskTitle": taskTitle]
                        ]
                    )
                    
                case .reviewInsight(let title):
                    // Navigate to Creation Studio backlog filtered to insights
                    NotificationCenter.default.post(
                        name: NSNotification.Name("navigateWithContext"),
                        object: nil,
                        userInfo: [
                            "destination": "studio",
                            "context": ["filter": "insights", "searchText": title]
                        ]
                    )
                    
                case .planTrip(let destination):
                    // Navigate to Events/Trips with new trip mode
                    NotificationCenter.default.post(
                        name: NSNotification.Name("navigateWithContext"),
                        object: nil,
                        userInfo: [
                            "destination": "events",
                            "context": ["action": "create_trip", "destination": destination]
                        ]
                    )
                    
                case .recordExpense(let amount, let category):
                    // Navigate to Dashboard with expense entry mode
                    NotificationCenter.default.post(
                        name: NSNotification.Name("navigateWithContext"),
                        object: nil,
                        userInfo: [
                            "destination": "dashboard",
                            "context": ["showExpense": "true", "amount": "\(amount)", "category": category]
                        ]
                    )
                    
                case .negotiateLead(let leadName, let amount):
                    // Navigate to Events with negotiation mode for specific lead
                    NotificationCenter.default.post(
                        name: NSNotification.Name("navigateWithContext"),
                        object: nil,
                        userInfo: [
                            "destination": "events",
                            "context": ["action": "negotiate", "leadName": leadName, "suggestedAmount": "\(amount)"]
                        ]
                    )
                }
            }
        }
    }
}

// MARK: - Navigation State Observer
class NavigationState: ObservableObject {
    static let shared = NavigationState()
    
    @Published var currentDestination: String?
    @Published var contextData: [String: String] = [:]
    @Published var shouldNavigate = false
    
    private init() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("navigateWithContext"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo else { return }
            
            self.currentDestination = userInfo["destination"] as? String
            self.contextData = userInfo["context"] as? [String: String] ?? [:]
            self.shouldNavigate = true
            
            // Auto-reset navigation after 0.1s to allow view to process
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.shouldNavigate = false
            }
        }
    }
}

extension Notification.Name {
    static let navigateToAction = Notification.Name("navigateToAction")
    static let navigateWithContext = Notification.Name("navigateWithContext")
}
