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
    func pullProfile(webToken: String?) async throws -> ArtistProfileDTO? {
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
            
            let profile = try JSONDecoder().decode(ArtistProfileDTO.self, from: data)
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
                descriptionText: exp.descriptionText,
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
        let localKeys = Set(local.map { "\($0.dateISO)|\($0.descriptionText)|\($0.amount)|\($0.category)" })
        
        // Add remote expenses not in local (using key to avoid duplicate based on core fields)
        for dto in remote {
            let key = "\(dto.date)|\(dto.descriptionText)|\(dto.amount)|\(dto.category)"
            guard !localKeys.contains(key) else { continue }
            let expense = Expense(
                dateISO: dto.date,
                descriptionText: dto.descriptionText,
                amount: dto.amount,
                category: dto.category,
                notes: dto.notes ?? ""
            )
            context.insert(expense)
        }
    }
}

// MARK: - DTOs for API Communication
struct ExpenseDTO: Codable {
    let id: String
    let date: String
    let descriptionText: String
    let amount: Double
    let category: String
    let notes: String?

    init(id: String, date: String, descriptionText: String, amount: Double, category: String, notes: String? = nil) {
        self.id = id
        self.date = date
        self.descriptionText = descriptionText
        self.amount = amount
        self.category = category
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case descriptionText
        case amount
        case category
        case notes
        case description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)

        if let text = try? container.decode(String.self, forKey: .descriptionText) {
            descriptionText = text
        } else if let text = try? container.decode(String.self, forKey: .description) {
            descriptionText = text
        } else {
            descriptionText = ""
        }

        amount = try container.decode(Double.self, forKey: .amount)
        category = try container.decode(String.self, forKey: .category)
        notes = try? container.decode(String.self, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(descriptionText, forKey: .descriptionText)
        try container.encode(amount, forKey: .amount)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

struct InsightDTO: Codable {
    let period: String
    let followers: Int
    let reach: Int
    let engagement: Double
}

struct ArtistProfileDTO: Codable {
    let stageName: String
    let genre: String
    let city: String
    let state: String
    let artistStage: String
    let toneOfVoice: String
    let mainGoal: String
    let contentFocus: String
    let visualIdentity: String
    let instagramHandle: String?
    let spotifyHandle: String?
    let soundCloudHandle: String?
    let youTubeHandle: String?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Workspace Sync DTOs (mirrors web WorkspaceData schema)

struct WorkspaceGigDTO: Codable {
    let id: String
    var title: String?
    var city: String
    var state: String?
    var venue: String
    var dateISO: String
    var fee: Double?
    var contactName: String?
    var notes: String?
    var status: String
    var logisticsRequired: Bool?
    var totalLogisticsCost: Double?
    var logisticsUpdatedAtISO: String?
    var localTransportMode: String?
    var localTransportEstimatedCost: Double?
}

struct WorkspaceLeadDTO: Codable {
    let id: String
    var eventName: String
    var city: String?
    var instagram: String
    var status: String
    var notes: String?
    var nextFollowUpISO: String
    var promoterId: String?
}

struct WorkspacePromoterDTO: Codable {
    let id: String
    var name: String
    var city: String
    var state: String
    var instagramHandle: String
    var phone: String?
    var email: String?
    var notes: String?
}

struct WorkspaceTemplateDTO: Codable {
    let id: String
    var title: String
    var body: String
    var category: String
    var isFavorite: Bool
}

struct WorkspaceTripPlanDTO: Codable {
    let id: String
    var fromCity: String
    var toCity: String
    var dateISO: String
    var transport: String
    var budget: String
    var gigLabel: String?
}

struct WorkspaceContentPlanItemDTO: Codable {
    let id: String
    var title: String
    var contentType: String
    var objective: String
    var pillar: String
    var scheduledDateISO: String
    var status: String
    var gigLabel: String?
}

struct WorkspaceManagerKnowledgeDTO: Codable {
    var artistBio: String
    var achievements: String
    var citiesPlayed: String
    var venuesPlayed: String
    var styleAndPositioning: String
    var baseFeeRange: String
    var negotiationRules: String
}

struct WorkspaceExpenseDTO: Codable {
    let id: String
    var dateISO: String
    var description: String
    var amount: Double
    var category: String
    var notes: String?
}

/// Full workspace payload — subset of web WorkspaceData that iOS syncs.
struct WorkspaceSyncPayload: Codable {
    var gigs: [WorkspaceGigDTO]?
    var leads: [WorkspaceLeadDTO]?
    var promoters: [WorkspacePromoterDTO]?
    var messageTemplates: [WorkspaceTemplateDTO]?
    var tripPlans: [WorkspaceTripPlanDTO]?
    var contentPlan: [WorkspaceContentPlanItemDTO]?
    var expenses: [WorkspaceExpenseDTO]?
    var managerLearnedFacts: [String]?
    var managerKnowledge: WorkspaceManagerKnowledgeDTO?
}

struct WorkspaceSyncRequest: Codable {
    let payload: WorkspaceSyncPayload
}

struct WorkspaceSyncGetResponse: Codable {
    let payload: WorkspaceSyncPayload?
}

// MARK: - MobileSyncService
// Uses /api/mobile/sync — requires MOBILE_SYNC_SECRET Bearer auth configured by user.

actor MobileSyncService {
    private static let baseURL = "https://web-app-eight-hazel.vercel.app"
    private static let endpoint = "/api/mobile/sync"

    enum SyncError: LocalizedError {
        case notConfigured
        case invalidURL
        case networkError(Error)
        case serverError(Int)
        case decodingError

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Sync não configurado. Configure o token em Perfil > Integração Web."
            case .invalidURL: return "URL inválida."
            case .networkError(let e): return "Erro de rede: \(e.localizedDescription)"
            case .serverError(let code): return "Erro no servidor (HTTP \(code))."
            case .decodingError: return "Erro ao processar dados do servidor."
            }
        }
    }

    private func authHeader() -> String? {
        guard let secret = PlatformAPISecrets.webSyncAuthHeader,
              !secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        // If already has "Bearer " prefix, return as-is; otherwise add it
        if secret.lowercased().hasPrefix("bearer ") { return secret }
        return "Bearer \(secret)"
    }

    // MARK: - Pull workspace from web → iOS

    func pullWorkspace() async throws -> WorkspaceSyncPayload {
        guard let auth = authHeader() else { throw SyncError.notConfigured }
        guard let url = URL(string: "\(Self.baseURL)\(Self.endpoint)") else { throw SyncError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SyncError.networkError(URLError(.unknown)) }
            guard (200...299).contains(http.statusCode) else { throw SyncError.serverError(http.statusCode) }

            let decoded = try JSONDecoder().decode(WorkspaceSyncGetResponse.self, from: data)
            return decoded.payload ?? WorkspaceSyncPayload()
        } catch is DecodingError {
            throw SyncError.decodingError
        }
    }

    // MARK: - Push workspace iOS → web (additive merge on server)

    func pushWorkspace(payload: WorkspaceSyncPayload) async throws {
        guard let auth = authHeader() else { throw SyncError.notConfigured }
        guard let url = URL(string: "\(Self.baseURL)\(Self.endpoint)") else { throw SyncError.invalidURL }

        let bodyData = try JSONEncoder().encode(WorkspaceSyncRequest(payload: payload))

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw SyncError.networkError(URLError(.unknown)) }
            guard (200...299).contains(http.statusCode) else { throw SyncError.serverError(http.statusCode) }
        }
    }

    // MARK: - Serialize iOS SwiftData entities → WorkspaceSyncPayload

    @MainActor
    static func buildPayload(
        gigs: [Gig],
        leads: [EventLead],
        promoters: [PromoterContact],
        templates: [MessageTemplate],
        tripPlans: [TripPlan],
        contentPlan: [SocialContentPlanItem],
        expenses: [Expense],
        learnedFacts: [String],
        profile: ArtistProfile?
    ) -> WorkspaceSyncPayload {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]

        let gigDTOs = gigs.map { g in
            WorkspaceGigDTO(
                id: UUID().uuidString,
                title: g.title,
                city: g.city,
                state: g.state,
                venue: g.title,
                dateISO: isoFormatter.string(from: g.date),
                fee: g.fee,
                contactName: g.contactName,
                notes: g.checklistSummary.isEmpty ? nil : g.checklistSummary,
                status: g.status,
                logisticsRequired: g.logisticsRequired,
                totalLogisticsCost: g.totalLogisticsCost,
                logisticsUpdatedAtISO: g.logisticsUpdatedAt.map { isoFormatter.string(from: $0) },
                localTransportMode: g.localTransportMode?.rawValue,
                localTransportEstimatedCost: g.localTransportEstimatedCost
            )
        }

        let leadDTOs = leads.map { l in
            WorkspaceLeadDTO(
                id: UUID().uuidString,
                eventName: l.name,
                city: l.city,
                instagram: l.instagramHandle,
                status: l.status,
                notes: l.notes.isEmpty ? nil : l.notes,
                nextFollowUpISO: isoFormatter.string(from: l.eventDate),
                promoterId: nil
            )
        }

        let promoterDTOs = promoters.map { p in
            WorkspacePromoterDTO(
                id: UUID().uuidString,
                name: p.name,
                city: p.city,
                state: p.state,
                instagramHandle: p.instagramHandle,
                phone: p.phone.isEmpty ? nil : p.phone,
                email: p.email.isEmpty ? nil : p.email,
                notes: p.notes.isEmpty ? nil : p.notes
            )
        }

        let templateDTOs = templates.map { t in
            WorkspaceTemplateDTO(
                id: UUID().uuidString,
                title: t.title,
                body: t.body,
                category: t.category,
                isFavorite: t.isFavorite
            )
        }

        let tripDTOs = tripPlans.map { tr in
            WorkspaceTripPlanDTO(
                id: UUID().uuidString,
                fromCity: tr.fromCity,
                toCity: tr.toCity,
                dateISO: tr.dateISO,
                transport: tr.transport,
                budget: tr.budget,
                gigLabel: tr.linkedGigLabel.isEmpty ? nil : tr.linkedGigLabel
            )
        }

        let contentDTOs = contentPlan.map { c in
            WorkspaceContentPlanItemDTO(
                id: UUID().uuidString,
                title: c.title,
                contentType: c.contentType,
                objective: c.objective,
                pillar: c.pillar,
                scheduledDateISO: isoFormatter.string(from: c.scheduledDate),
                status: c.status,
                gigLabel: c.linkedGigLabel.isEmpty ? nil : c.linkedGigLabel
            )
        }

        let expenseDTOs = expenses.map { e in
            WorkspaceExpenseDTO(
                id: UUID().uuidString,
                dateISO: e.dateISO,
                description: e.descriptionText,
                amount: e.amount,
                category: e.category,
                notes: e.notes.isEmpty ? nil : e.notes
            )
        }

        var knowledge: WorkspaceManagerKnowledgeDTO? = nil
        if let p = profile {
            knowledge = WorkspaceManagerKnowledgeDTO(
                artistBio: p.stageName + " — " + p.genre,
                achievements: "",
                citiesPlayed: p.city,
                venuesPlayed: "",
                styleAndPositioning: p.visualIdentity,
                baseFeeRange: "",
                negotiationRules: p.toneOfVoice
            )
        }

        return WorkspaceSyncPayload(
            gigs: gigDTOs,
            leads: leadDTOs,
            promoters: promoterDTOs,
            messageTemplates: templateDTOs,
            tripPlans: tripDTOs,
            contentPlan: contentDTOs,
            expenses: expenseDTOs,
            managerLearnedFacts: learnedFacts.isEmpty ? nil : learnedFacts,
            managerKnowledge: knowledge
        )
    }

    // MARK: - Merge remote payload into iOS SwiftData

    @MainActor
    static func mergeWorkspace(
        remote: WorkspaceSyncPayload,
        localGigs: [Gig],
        localLeads: [EventLead],
        localPromoters: [PromoterContact],
        localTemplates: [MessageTemplate],
        localTripPlans: [TripPlan],
        localContentPlan: [SocialContentPlanItem],
        localExpenses: [Expense],
        context: ModelContext
    ) -> [String] {
        var mergedFacts: [String] = []

        let isoFormatter = ISO8601DateFormatter()
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")

        func parseDate(_ raw: String) -> Date {
            if let d = isoFormatter.date(from: raw) { return d }
            if let d = dayFormatter.date(from: raw) { return d }
            return .now
        }

        let existingGigKeys = Set(localGigs.map { "\($0.title)|\($0.city)|\($0.date.timeIntervalSince1970)" })
        for dto in remote.gigs ?? [] {
            let date = parseDate(dto.dateISO)
            let title = dto.title ?? dto.venue
            let key = "\(title)|\(dto.city)|\(date.timeIntervalSince1970)"
            if let existingGig = localGigs.first(where: {
                $0.title == title
                && $0.city == dto.city
                && $0.date.timeIntervalSince1970 == date.timeIntervalSince1970
            }) {
                existingGig.title = title
                existingGig.city = dto.city
                existingGig.state = dto.state ?? dto.venue
                existingGig.date = date
                existingGig.fee = dto.fee ?? existingGig.fee
                existingGig.contactName = dto.contactName ?? existingGig.contactName
                existingGig.checklistSummary = dto.notes ?? existingGig.checklistSummary
                existingGig.status = dto.status
                existingGig.logisticsRequired = dto.logisticsRequired ?? existingGig.logisticsRequired
                existingGig.totalLogisticsCost = dto.totalLogisticsCost ?? existingGig.totalLogisticsCost
                existingGig.logisticsUpdatedAt = dto.logisticsUpdatedAtISO.map(parseDate) ?? existingGig.logisticsUpdatedAt
                existingGig.localTransportMode = dto.localTransportMode.flatMap(TransportMode.init(rawValue:)) ?? existingGig.localTransportMode
                existingGig.localTransportEstimatedCost = dto.localTransportEstimatedCost ?? existingGig.localTransportEstimatedCost
            } else if !existingGigKeys.contains(key) {
                let newGig = Gig(
                    title: title,
                    city: dto.city,
                    state: dto.state ?? dto.venue,
                    date: date,
                    fee: dto.fee ?? 0,
                    contactName: dto.contactName ?? "",
                    checklistSummary: dto.notes ?? ""
                )
                newGig.status = dto.status
                newGig.logisticsRequired = dto.logisticsRequired ?? false
                newGig.totalLogisticsCost = dto.totalLogisticsCost
                newGig.logisticsUpdatedAt = dto.logisticsUpdatedAtISO.map(parseDate)
                newGig.localTransportMode = dto.localTransportMode.flatMap(TransportMode.init(rawValue:))
                newGig.localTransportEstimatedCost = dto.localTransportEstimatedCost
                context.insert(newGig)
            }
        }

        let existingLeadKeys = Set(localLeads.map { "\($0.name)|\($0.city)|\($0.instagramHandle)" })
        for dto in remote.leads ?? [] {
            let key = "\(dto.eventName)|\(dto.city ?? "")|\(dto.instagram)"
            if !existingLeadKeys.contains(key) {
                context.insert(EventLead(
                    name: dto.eventName,
                    city: dto.city ?? "",
                    state: "",
                    eventDate: parseDate(dto.nextFollowUpISO),
                    venue: "",
                    instagramHandle: dto.instagram,
                    status: dto.status,
                    notes: dto.notes ?? ""
                ))
            }
        }

        let existingPromoterKeys = Set(localPromoters.map { "\($0.name)|\($0.city)|\($0.instagramHandle)" })
        for dto in remote.promoters ?? [] {
            let key = "\(dto.name)|\(dto.city)|\(dto.instagramHandle)"
            if !existingPromoterKeys.contains(key) {
                context.insert(PromoterContact(
                    name: dto.name,
                    city: dto.city,
                    state: dto.state,
                    instagramHandle: dto.instagramHandle,
                    phone: dto.phone ?? "",
                    email: dto.email ?? "",
                    notes: dto.notes ?? ""
                ))
            }
        }

        // Merge message templates (by title+category key)
        let existingTplKeys = Set(localTemplates.map { "\($0.title)|\($0.category)" })
        for dto in remote.messageTemplates ?? [] {
            let key = "\(dto.title)|\(dto.category)"
            if !existingTplKeys.contains(key) {
                context.insert(MessageTemplate(
                    title: dto.title,
                    body: dto.body,
                    category: dto.category,
                    isFavorite: dto.isFavorite
                ))
            }
        }

        // Merge trip plans (by fromCity+toCity+dateISO key)
        let existingTripKeys = Set(localTripPlans.map { "\($0.fromCity)|\($0.toCity)|\($0.dateISO)" })
        for dto in remote.tripPlans ?? [] {
            let key = "\(dto.fromCity)|\(dto.toCity)|\(dto.dateISO)"
            if !existingTripKeys.contains(key) {
                context.insert(TripPlan(
                    fromCity: dto.fromCity,
                    fromState: "",
                    toCity: dto.toCity,
                    toState: "",
                    dateISO: dto.dateISO,
                    transport: dto.transport,
                    budget: dto.budget,
                    linkedGigLabel: dto.gigLabel ?? ""
                ))
            }
        }

        let existingContentKeys = Set(localContentPlan.map { "\($0.title)|\($0.contentType)|\($0.scheduledDate.timeIntervalSince1970)" })
        for dto in remote.contentPlan ?? [] {
            let schedule = parseDate(dto.scheduledDateISO)
            let key = "\(dto.title)|\(dto.contentType)|\(schedule.timeIntervalSince1970)"
            if !existingContentKeys.contains(key) {
                context.insert(SocialContentPlanItem(
                    title: dto.title,
                    contentType: dto.contentType,
                    objective: dto.objective,
                    status: dto.status,
                    scheduledDate: schedule,
                    pillar: dto.pillar,
                    hook: "",
                    caption: "",
                    cta: "",
                    hashtags: "",
                    linkedGigLabel: dto.gigLabel ?? ""
                ))
            }
        }

        let existingExpenseKeys = Set(localExpenses.map { "\($0.dateISO)|\($0.descriptionText)|\($0.amount)|\($0.category)" })
        for dto in remote.expenses ?? [] {
            let key = "\(dto.dateISO)|\(dto.description)|\(dto.amount)|\(dto.category)"
            if !existingExpenseKeys.contains(key) {
                context.insert(Expense(
                    dateISO: dto.dateISO,
                    descriptionText: dto.description,
                    amount: dto.amount,
                    category: dto.category,
                    notes: dto.notes ?? ""
                ))
            }
        }

        // Collect learned facts
        mergedFacts = remote.managerLearnedFacts ?? []

        try? context.save()
        return mergedFacts
    }
}
