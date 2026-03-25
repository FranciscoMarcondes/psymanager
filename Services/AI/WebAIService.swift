import Foundation

// MARK: - Public context type for callers

struct WebAIContext {
    var leads: Int?
    var gigs: Int?
    var contentIdeas: Int?
    var radarEvents: Int?
}

// MARK: - WebAIService
// Calls the PsyManager web backend AI endpoints directly from iOS.
// No auth required for /api/manager/chat, /api/logistics/estimate, /api/logistics/toll-estimate.

actor WebAIService {

    static let shared = WebAIService()

    private static let baseURL = "https://web-app-eight-hazel.vercel.app"

    // MARK: - Request / Response types

    private struct ChatRequest: Encodable {
        let artistName: String?
        let prompt: String
        let mode: String
        let context: ChatContext?
        let history: [HistoryMessage]?

        struct ChatContext: Encodable {
            let leads: Int?
            let gigs: Int?
            let contentIdeas: Int?
            let radarEvents: Int?
        }

        struct HistoryMessage: Encodable {
            let role: String
            let text: String
        }
    }

    private struct ChatResponse: Decodable {
        let answer: String?
        let error: String?
    }

    struct LogisticsEstimateRequest: Encodable {
        let fromAddress: String
        let toAddress: String
    }

    struct LogisticsEstimateResponse: Decodable {
        let oneWayDistanceKm: Double?
        let oneWayHours: Double?
        let distanceKm: Double?
        let estimatedHours: Double?
        let source: String?
        let error: String?
    }

    struct TollEstimateRequest: Encodable {
        let fromState: String
        let toState: String
        let oneWayDistanceKm: Double
        let tripType: String
    }

    struct TollEstimateResponse: Decodable {
        let estimate: Double?
        let rationale: String?
        let error: String?
    }

    // MARK: - Manager AI

    /// Call web AI with a specific mode. Returns the text answer.
    func ask(
        artistName: String,
        prompt: String,
        mode: String = "conversation",
        context: WebAIContext? = nil,
        history: [(role: String, text: String)]? = nil
    ) async -> String {
        guard let url = URL(string: "\(Self.baseURL)/api/manager/chat") else {
            return "Serviço indisponível."
        }

        let ctxDTO: ChatRequest.ChatContext? = context.map {
            ChatRequest.ChatContext(leads: $0.leads, gigs: $0.gigs, contentIdeas: $0.contentIdeas, radarEvents: $0.radarEvents)
        }

        let body = ChatRequest(
            artistName: artistName,
            prompt: prompt,
            mode: mode,
            context: ctxDTO,
            history: history?.map { ChatRequest.HistoryMessage(role: $0.role, text: $0.text) }
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return "Erro na resposta do servidor."
            }
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            return decoded.answer ?? decoded.error ?? "Sem resposta."
        } catch {
            return "Erro ao conectar com Manager IA."
        }
    }

    // MARK: - Logistics API

    /// Estimate route distance and time by address (uses OSRM via web backend).
    func estimateRoute(fromAddress: String, toAddress: String) async -> LogisticsEstimateResponse? {
        guard let url = URL(string: "\(Self.baseURL)/api/logistics/estimate") else { return nil }

        let body = LogisticsEstimateRequest(fromAddress: fromAddress, toAddress: toAddress)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(LogisticsEstimateResponse.self, from: data)
        } catch {
            return nil
        }
    }

    /// Estimate toll cost by state pair and distance.
    func estimateToll(
        fromState: String,
        toState: String,
        oneWayDistanceKm: Double,
        tripType: String = "round-trip"
    ) async -> TollEstimateResponse? {
        guard let url = URL(string: "\(Self.baseURL)/api/logistics/toll-estimate") else { return nil }

        let body = TollEstimateRequest(
            fromState: fromState,
            toState: toState,
            oneWayDistanceKm: oneWayDistanceKm,
            tripType: tripType
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            return try JSONDecoder().decode(TollEstimateResponse.self, from: data)
        } catch {
            return nil
        }
    }
}
