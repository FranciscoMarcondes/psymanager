import SwiftData
import Foundation

/// Service for quick execution of AI suggestions - converts Manager insights into 1-tap actions
struct QuickActionService {
    
    // MARK: - Action Types
    enum ActionType: String, Codable, CaseIterable {
        case createContent = "create_content"
        case followUpLead = "follow_up_lead"
        case scheduleGig = "schedule_gig"
        case addTask = "add_task"
        case captureInsight = "capture_insight"
        case planEvent = "plan_event"
        case addExpense = "add_expense"
        case negotiateLead = "negotiate_lead"
        
        var displayName: String {
            switch self {
            case .createContent: return "Criar Conteúdo"
            case .followUpLead: return "Seguir Lead"
            case .scheduleGig: return "Agendar Gig"
            case .addTask: return "Adicionar Tarefa"
            case .captureInsight: return "Guardar Insight"
            case .planEvent: return "Planejar Evento"
            case .addExpense: return "Registrar Gasto"
            case .negotiateLead: return "Negociar Lead"
            }
        }
        
        var icon: String {
            switch self {
            case .createContent: return "pencil.and.sparkles"
            case .followUpLead: return "phone.fill"
            case .scheduleGig: return "calendar.badge.plus"
            case .addTask: return "checkmark.circle"
            case .captureInsight: return "lightbulb.fill"
            case .planEvent: return "map"
            case .addExpense: return "dollarsign.circle"
            case .negotiateLead: return "handshake.fill"
            }
        }
    }
    
    // MARK: - Quick Action Model
    struct QuickAction {
        let type: ActionType
        let title: String
        let subtitle: String?
        let extractedData: [String: String] // Key-value pairs extracted from suggestion
        let priority: Int // 1-5, higher = more important
        
        var isHighPriority: Bool { priority >= 4 }
    }
    
    // MARK: - AI Suggestion Parsing
    /// Parse Manager response to extract actionable suggestions
    static func parseActionSuggestions(from response: String) -> [QuickAction] {
        var actions: [QuickAction] = []
        
        // Pattern matching for common action suggestions
        let patterns: [(needle: String, action: ActionType)] = [
            ("criar.*conteúdo", .createContent),
            ("criar.*post", .createContent),
            ("publicar", .createContent),
            ("gravars.*vídeo", .createContent),
            ("escrever.*CapaAlbum", .createContent),
            
            ("seguir.*lead", .followUpLead),
            ("ligar.*lead", .followUpLead),
            ("entrar.*contato", .followUpLead),
            ("converse.*promoter", .followUpLead),
            
            ("agendar.*gig", .scheduleGig),
            ("marcar.*show", .scheduleGig),
            ("confirmar.*apresentação", .scheduleGig),
            
            ("adicionar.*tarefa", .addTask),
            ("você.*precisa", .addTask),
            
            ("guardar", .captureInsight),
            ("lembrar", .captureInsight),
            ("rascunho", .captureInsight),
            
            ("planejar.*viagem", .planEvent),
            ("organizar.*turnê", .planEvent),
            
            ("registro.*gasto", .addExpense),
            ("gastos.*investimento", .addExpense),
            
            ("negociar.*cachês", .negotiateLead),
            ("discutir.*valores", .negotiateLead)
        ]
        
        // Sentence segmentation
        let sentences = response.split(separator: ".").map(String.init).map { $0.trimmingCharacters(in: .whitespaces) }
        
        for (index, sentence) in sentences.enumerated() {
            let lowerSentence = sentence.lowercased()
            
            for (pattern, actionType) in patterns {
                if lowerSentence.range(of: pattern, options: .regularExpression) != nil {
                    // Extract priority based on position and keywords
                    let priority = calculatePriority(for: sentence, at: index, of: sentences.count)
                    
                    // Extract relevant data from sentence
                    let data = extractData(from: sentence, for: actionType)
                    
                    let action = QuickAction(
                        type: actionType,
                        title: actionType.displayName,
                        subtitle: extractSubtitle(from: sentence, length: 50),
                        extractedData: data,
                        priority: priority
                    )
                    
                    // Avoid duplicate types in same parse
                    if !actions.contains(where: { $0.type == actionType }) {
                        actions.append(action)
                    }
                    
                    break // Move to next sentence once matched
                }
            }
        }
        
        // Sort by priority (highest first) and limit to top 5
        return Array(actions.sorted { $0.priority > $1.priority }.prefix(5))
    }
    
    // MARK: - Quick Save to Backlog
    /// Execute quick save of suggested content to backlog (1-tap)
    static func quickSaveContent(
        title: String,
        objective: String? = nil,
        contentType: String = "Social Post",
        modelContext: ModelContext
    ) {
        let item = SocialContentPlanItem(
            title: title,
            contentType: contentType,
            objective: objective ?? title,
            status: "Rascunho",
            scheduledDate: Date().addingTimeInterval(86400 * 3), // 3 days from now
            pillar: "Engagement", // Default pillar
            hook: "",
            caption: "",
            cta: "",
            hashtags: "",
            notes: "Criado por sugestão do Manager IA"
        )
        
        modelContext.insert(item)
        try? modelContext.save()
    }
    
    /// Quick save for task/reminder
    static func quickSaveTask(
        title: String,
        description: String? = nil,
        dueDate: Date = .now.addingTimeInterval(86400),
        modelContext: ModelContext
    ) {
        let task = CareerTask(
            title: title,
            detail: description ?? "Criado por sugestão do Manager IA",
            priority: "Alta",
            dueDate: dueDate
        )
        
        modelContext.insert(task)
        try? modelContext.save()
    }
    
    /// Quick save for lead follow-up
    static func quickSaveLeadFollowUp(
        leadId: String? = nil,
        leadName: String = "Unknown",
        actionType: String = "call",
        dueDate: Date = .now.addingTimeInterval(86400),
        modelContext: ModelContext
    ) {
        // Create a task to track follow-up
        let task = CareerTask(
            title: "Follow-up: \(leadName)",
            detail: "Follow-up sugerido por Manager IA - Tipo: \(actionType)",
            priority: "Alta",
            dueDate: dueDate
        )
        
        modelContext.insert(task)
        try? modelContext.save()
    }
    
    // MARK: - Private Helpers
    
    private static func calculatePriority(for sentence: String, at index: Int, of total: Int) -> Int {
        var score = 3 // Base score
        
        // Early sentences get higher priority
        if index < total / 3 { score += 2 }
        
        // Keywords indicating importance
        let urgentKeywords = ["urgente", "hoje", "agora", "imediato", "importante", "crítico"]
        if urgentKeywords.contains(where: { sentence.lowercased().contains($0) }) {
            score += 2
        }
        
        // Commands ("você deve", "você precisa") increase priority
        if sentence.lowercased().contains("você deve") || sentence.lowercased().contains("você precisa") {
            score += 1
        }
        
        return min(score, 5) // Cap at 5
    }
    
    private static func extractData(from sentence: String, for actionType: ActionType) -> [String: String] {
        var data: [String: String] = [:]
        data["action_type"] = actionType.rawValue
        data["source_text"] = sentence.trimmingCharacters(in: .whitespaces)
        
        // Action-specific extraction
        switch actionType {
        case .createContent:
            if let type = extractBetween(sentence, start: "de ", end: " para") {
                data["content_type"] = type
            }
        case .followUpLead:
            // Try to extract contact method
            if sentence.lowercased().contains("liga") {
                data["method"] = "call"
            } else if sentence.lowercased().contains("email") {
                data["method"] = "email"
            } else if sentence.lowercased().contains("instagram") || sentence.lowercased().contains("whatsapp") {
                data["method"] = "direct_message"
            }
        case .scheduleGig:
            // Extract dates if present
            if let date = extractDate(from: sentence) {
                data["suggested_date"] = date
            }
        case .planEvent:
            // Extract location if present
            if let location = extractLocation(from: sentence) {
                data["location"] = location
            }
        default:
            break
        }
        
        return data
    }
    
    private static func extractSubtitle(from sentence: String, length: Int) -> String {
        let trimmed = sentence.trimmingCharacters(in: .whitespaces)
        if trimmed.count > length {
            return String(trimmed.prefix(length)) + "..."
        }
        return trimmed
    }
    
    private static func extractBetween(_ text: String, start: String, end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespaces)
    }
    
    private static func extractDate(from text: String) -> String? {
        // Simple date pattern - can be enhanced
        let patterns = ["hoje", "amanhã", "próxima semana", "final de semana", "próximo sábado", "próximo domingo"]
        return patterns.first { text.lowercased().contains($0) }
    }
    
    private static func extractLocation(from text: String) -> String? {
        // Extract city/venue names (simplified)
        let locationKeywords = ["em", "para", "em ", "de "]
        for keyword in locationKeywords {
            if let range = text.range(of: keyword) {
                let afterKeyword = text[range.upperBound...]
                let words = afterKeyword.split(separator: " ").prefix(3).joined(separator: " ")
                if !words.isEmpty && words.count > 2 {
                    return String(words)
                }
            }
        }
        return nil
    }
}
