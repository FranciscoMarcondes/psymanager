import Foundation
import SwiftData

// MARK: - Bidirectional Data Sync Service
actor DataSyncService {
    private static let baseURL = "https://web-app-eight-hazel.vercel.app"
    private static let syncEndpoints = [
        "profile": "/api/profile",
        "expenses": "/api/expenses",
        "leads": "/api/leads",
        "insights": "/api/insights"
    ]
    
    enum SyncError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case decodingError
        case unauthorized
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "URL de sincronização inválida"
            case .networkError: return "Erro de conexão com servidor"
            case .decodingError: return "Erro ao processar dados do servidor"
            case .unauthorized: return "Não autorizado para sincronizar"
            }
        }
    }
    
    // MARK: - Pull (Web → iOS)
    
    /// Fetch profile from web and update local
    func pullProfile(webToken: String?) async throws -> ArtistProfile? {
        guard let url = URL(string: "\(Self.baseURL)\(Self.syncEndpoints["profile"] ?? "")")
        else { throw SyncError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = webToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { throw SyncError.networkError(URLError(.unknown)) }
            
            if httpResponse.statusCode == 401 { throw SyncError.unauthorized }
            guard (200...299).contains(httpResponse.statusCode) else { throw SyncError.networkError(URLError(.badServerResponse)) }
            
            let profile = try JSONDecoder().decode(ArtistProfile.self, from: data)
            return profile
        } catch is DecodingError {
            throw SyncError.decodingError
        }
    }
    
    /// Fetch expenses from web
    func pullExpenses(webToken: String?) async throws -> [ExpenseDTO] {
        guard let url = URL(string: "\(Self.baseURL)\(Self.syncEndpoints["expenses"] ?? "")")
        else { throw SyncError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = webToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else { throw SyncError.networkError(URLError(.badServerResponse)) }
        
        let decoded = try JSONDecoder().decode([ExpenseDTO].self, from: data)
        return decoded
    }
    
    /// Fetch insights from web (read-only)
    func pullInsights(webToken: String?) async throws -> [InsightDTO] {
        guard let url = URL(string: "\(Self.baseURL)\(Self.syncEndpoints["insights"] ?? "")")
        else { throw SyncError.invalidURL }
        
        var request = URLRequest(url: url)
        if let token = webToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([InsightDTO].self, from: data)
    }
    
    // MARK: - Push (iOS → Web)
    
    /// Push local expenses to web
    @MainActor
    func pushExpenses(_ expenses: [Expense], webToken: String?) async throws {
        guard let url = URL(string: "\(Self.baseURL)\(Self.syncEndpoints["expenses"] ?? "")")
        else { throw SyncError.invalidURL }
        
        let dtos = expenses.map { exp -> ExpenseDTO in
            ExpenseDTO(
                id: UUID().uuidString,
                date: exp.dateISO,
                description: exp.description,
                amount: exp.amount,
                category: exp.category,
                notes: exp.notes
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = webToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONEncoder().encode(dtos)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else { throw SyncError.networkError(URLError(.badServerResponse)) }
    }
    
    // MARK: - Merge Logic
    
    /// Merge pulled expenses with local, avoiding duplicates
    @MainActor
    func mergeExpenses(remote: [ExpenseDTO], local: [Expense], into context: ModelContext) throws {
        let remoteSet = Set(remote.map { $0.id })
        let localIds = Set(local.map { $0.id ?? "" }.filter { !$0.isEmpty })
        
        // Add remote expenses not in local
        for dto in remote where !localIds.contains(dto.id) {
            let expense = Expense(
                dateISO: dto.date,
                description: dto.description,
                amount: dto.amount,
                category: dto.category,
                notes: dto.notes
            )
            context.insert(expense)
        }
    }
}

// MARK: - DTOs for API Communication
struct ExpenseDTO: Codable {
    let id: String
    let date: String
    let description: String
    let amount: Double
    let category: String
    let notes: String?
}

struct InsightDTO: Codable {
    let period: String
    let followers: Int
    let reach: Int
    let engagement: Double
}
