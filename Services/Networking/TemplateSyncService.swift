import Foundation

struct RemoteTemplateDTO: Codable {
    let id: String
    let title: String
    let body: String
    let category: String
    let isFavorite: Bool
}

struct TemplatesResponseDTO: Codable {
    let templates: [RemoteTemplateDTO]
}

struct TemplatesUpsertRequestDTO: Codable {
    let templates: [RemoteTemplateDTO]
}

enum TemplateSyncError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL de sincronização inválida."
        case .invalidResponse:
            return "Resposta inválida do servidor."
        case let .serverError(code):
            return "Falha na sincronização de templates (HTTP \(code))."
        }
    }
}

/// Serviço de sincronização de templates entre app iOS e backend web.
///
/// Endpoint esperado:
/// - GET  /api/templates -> { templates: [...] }
/// - PUT  /api/templates -> { ok: true, templatesCount: N }
///
/// Observação: para chamadas autenticadas, inclua um cookie/token de sessão
/// válido em `authHeaderValue` (ex: `Bearer <token>`), se o backend exigir.
final class TemplateSyncService {
    private let baseURL: URL
    private let session: URLSession
    private let authHeaderValue: String?

    init(
        baseURL: URL,
        session: URLSession = .shared,
        authHeaderValue: String? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authHeaderValue = authHeaderValue
    }

    func fetchTemplates() async throws -> [RemoteTemplateDTO] {
        guard let url = URL(string: "/api/templates", relativeTo: baseURL) else {
            throw TemplateSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authHeaderValue {
            request.setValue(authHeaderValue, forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TemplateSyncError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw TemplateSyncError.serverError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(TemplatesResponseDTO.self, from: data)
        return decoded.templates
    }

    func pushTemplates(_ templates: [RemoteTemplateDTO]) async throws {
        guard let url = URL(string: "/api/templates", relativeTo: baseURL) else {
            throw TemplateSyncError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authHeaderValue {
            request.setValue(authHeaderValue, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(TemplatesUpsertRequestDTO(templates: templates))

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw TemplateSyncError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw TemplateSyncError.serverError(http.statusCode)
        }
    }
}
