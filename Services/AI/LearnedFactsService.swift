import Foundation

/// LearnedFactsService — Extract, manage, and sync learned facts from Manager AI conversations
class LearnedFactsService {
    static let shared = LearnedFactsService()
    
    private let baseURL = UserDefaults.standard.string(forKey: "webaiServiceURL") ?? "http://localhost:3000"
    private let learningPatterns: [LearnedFactPattern] = [
        // Preference patterns
        LearnedFactPattern(
            regex: "(?i)(prefer|prefere|gosta de|melhor).*(small|pequen|inti|intimate|close).+(venue|espaço|local|show)",
            category: "preference",
            template: "Prefers small/intimate venues"
        ),
        LearnedFactPattern(
            regex: "(?i)(prefer|prefere|gosta de).*(large|grand|big).+(venue|espaço|local|show)",
            category: "preference",
            template: "Prefers large/grand venues"
        ),
        
        // Pricing patterns
        LearnedFactPattern(
            regex: "(?i)(negotiat|negocia).+(R\\$?\\s*\\d+)|(never below|nunca abaixo)",
            category: "pricing",
            template: "Has specific pricing thresholds"
        ),
        LearnedFactPattern(
            regex: "(?i)(double|dobro|triplica|2x|3x).+(rate|valor|preço|fee)",
            category: "pricing",
            template: "Applies multipliers for special event types"
        ),
        
        // Location patterns
        LearnedFactPattern(
            regex: "(?i)(active|ativo|trabalha).+(São Paulo|SP|Rio|RJ|Minas|MG|Brasília)",
            category: "location",
            template: "Active specific regions"
        ),
        LearnedFactPattern(
            regex: "(?i)(avoid|evita|não.*vai).+(city|cidade|state|estado)",
            category: "location",
            template: "Avoids certain cities/regions"
        ),
        
        // Availability patterns
        LearnedFactPattern(
            regex: "(?i)(avoid|evita|não.*sexta).+(friday|sexta)",
            category: "availability",
            template: "Friday bookings avoided"
        ),
        LearnedFactPattern(
            regex: "(?i)(prefer|melhor).+(weekend|fim de semana|weekday)",
            category: "availability",
            template: "Prefers specific days of week"
        ),
        
        // Technical/Equipment patterns
        LearnedFactPattern(
            regex: "(?i)(require|require|precisa|needs?).+(sound|som|equipment|PA|lights|iluminação)",
            category: "technical",
            template: "Has specific technical requirements"
        ),
    ]
    
    private struct LearnedFactPattern {
        let regex: String
        let category: String
        let template: String
    }
    
    /// Extract learned facts from Manager AI response text
    /// - Parameter responseText: The full response text from manager AI
    /// - Returns: Array of extracted LearnedFact objects (not yet persisted)
    func extractFactsFromResponse(_ responseText: String) async -> [LearnedFact] {
        var extracted: [LearnedFact] = []
        
        for pattern in learningPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern.regex, options: [])
                let range = NSRange(responseText.startIndex..<responseText.endIndex, in: responseText)
                let matches = regex.matches(in: responseText, range: range)
                
                if !matches.isEmpty {
                    // Found a match - extract detail context
                    for match in matches {
                        if let matchRange = Range(match.range, in: responseText) {
                            let matchedText = String(responseText[matchRange])
                            
                            // Create fact with extracted text
                            let fact = LearnedFact(
                                content: matchedText.trimmingCharacters(in: .whitespaces),
                                category: pattern.category,
                                confidence: min(0.6 + Double(matches.count) * 0.1, 0.95),
                                source: "chat_history",
                                extractedAt: .now
                            )
                            extracted.append(fact)
                        }
                    }
                }
            } catch {
                print("[LearnedFacts] Regex error: \(error)")
                continue
            }
        }
        
        return extracted
    }
    
    /// Sync all learned facts to backend
    /// - Parameter facts: Array of LearnedFact to sync
    /// - Parameter userId: User ID for backend sync
    func syncFactsToBackend(_ facts: [LearnedFact], userId: String) async {
        guard !facts.isEmpty else { return }
        
        let factDTOs = facts.map { fact in
            [
                "content": fact.content,
                "category": fact.category,
                "confidence": fact.confidence,
                "source": fact.source,
                "extractedAt": ISO8601DateFormatter().string(from: fact.extractedAt)
            ] as [String: Any]
        }
        
        let payload = [
            "userId": userId,
            "facts": factDTOs
        ] as [String: Any]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            print("[LearnedFacts] Failed to serialize payload")
            return
        }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/api/manager/facts")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[LearnedFacts] Invalid response type")
                return
            }
            
            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                print("[LearnedFacts] Synced \(facts.count) facts successfully")
            } else {
                let text = String(data: data, encoding: .utf8) ?? ""
                print("[LearnedFacts] Sync failed (\(httpResponse.statusCode)): \(text)")
            }
        } catch {
            print("[LearnedFacts] Sync error: \(error)")
        }
    }
    
    /// Get all learned facts sorted by recency
    /// - Returns: Array of LearnedFact sorted by creation date (newest first)
    func getAllFacts(from modelContext: ModelContext? = nil) -> [LearnedFact] {
        // This would typically fetch from modelContext @Query in the view
        // For now, returning empty - actual implementation in view layer
        return []
    }
    
    /// Get facts by category
    /// - Parameter category: "preference", "pricing", "location", "availability", "technical"
    /// - Returns: Filtered facts
    func getFactsByCategory(_ category: String) -> [LearnedFact] {
        // Filtered fetch - implement in model context
        return []
    }
}
