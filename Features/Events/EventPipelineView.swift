import UIKit
import CoreLocation
import SwiftData
import SwiftUI

private enum TemplateSyncConfig {
    static let baseURLKey = "psy.web.baseURL"
    static let authHeaderKey = "psy.web.authHeader"
    static let defaultBaseURL = "https://web-app-eight-hazel.vercel.app"
}

private enum TemplateSyncBridge {
    private struct EventTemplateDTO: Codable {
        let id: String
        let title: String
        let body: String
        let category: String
        let isFavorite: Bool
    }

    private struct EventTemplatesResponseDTO: Codable {
        let templates: [EventTemplateDTO]
    }

    private struct EventTemplatesUpsertRequestDTO: Codable {
        let templates: [EventTemplateDTO]
    }

    static func credentials() -> (baseURL: URL, authHeader: String?)? {
        let rawBase = UserDefaults.standard.string(forKey: TemplateSyncConfig.baseURLKey)
            ?? TemplateSyncConfig.defaultBaseURL
        guard let baseURL = URL(string: rawBase) else {
            return nil
        }
        let authHeader = PlatformAPISecrets.webSyncAuthHeader
            ?? UserDefaults.standard.string(forKey: TemplateSyncConfig.authHeaderKey)
        return (baseURL, authHeader)
    }

    private static func fetchTemplates(baseURL: URL, authHeader: String?) async throws -> [EventTemplateDTO] {
        let endpoint = baseURL.appendingPathComponent("api/templates")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authHeader, !authHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(EventTemplatesResponseDTO.self, from: data)
        return decoded.templates
    }

    private static func pushTemplates(baseURL: URL, authHeader: String?, templates: [EventTemplateDTO]) async throws {
        let endpoint = baseURL.appendingPathComponent("api/templates")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authHeader, !authHeader.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(EventTemplatesUpsertRequestDTO(templates: templates))

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    static func key(title: String, body: String, category: String) -> String {
        "\(title.lowercased())|\(body.lowercased())|\(category.lowercased())"
    }

    @MainActor
    static func pullIntoLocal(modelContext: ModelContext, templates: [MessageTemplate]) async -> String {
        guard let credentials = credentials() else {
            return "Sync remoto indisponível (URL inválida)."
        }

        do {
            let remote = try await fetchTemplates(baseURL: credentials.baseURL, authHeader: credentials.authHeader)
            let remoteByKey = Dictionary(uniqueKeysWithValues: remote.map { dto in
                (key(title: dto.title, body: dto.body, category: dto.category), dto)
            })
            let localByKey = Dictionary(uniqueKeysWithValues: templates.map { local in
                (key(title: local.title, body: local.body, category: local.category), local)
            })

            // Upsert/refresh local items from remote
            for dto in remote {
                let itemKey = key(title: dto.title, body: dto.body, category: dto.category)
                if let local = localByKey[itemKey] {
                    local.title = dto.title
                    local.body = dto.body
                    local.category = dto.category
                    local.isFavorite = dto.isFavorite
                } else {
                    modelContext.insert(MessageTemplate(
                        title: dto.title,
                        body: dto.body,
                        category: dto.category,
                        isFavorite: dto.isFavorite
                    ))
                }
            }

            // Remove local items not present in remote snapshot
            for local in templates {
                let itemKey = key(title: local.title, body: local.body, category: local.category)
                if remoteByKey[itemKey] == nil {
                    modelContext.delete(local)
                }
            }

            try? modelContext.save()
            return "Templates atualizados da nuvem (\(remote.count))."
        } catch {
            return "Falha ao carregar templates da nuvem."
        }
    }

    static func pushFromLocal(templates: [MessageTemplate]) async -> String {
        guard let credentials = credentials() else {
            return "Sync remoto indisponível (URL inválida)."
        }

        let payload = templates.map { item in
            EventTemplateDTO(
                id: UUID().uuidString,
                title: item.title,
                body: item.body,
                category: item.category,
                isFavorite: item.isFavorite
            )
        }

        do {
            try await pushTemplates(baseURL: credentials.baseURL, authHeader: credentials.authHeader, templates: payload)
            return "Templates enviados para nuvem (\(payload.count))."
        } catch {
            return "Falha ao enviar templates para nuvem."
        }
    }
}

struct EventPipelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EventLead.eventDate) private var leads: [EventLead]
    @Query(sort: \PromoterContact.name) private var promoters: [PromoterContact]
    @Query(sort: \Negotiation.nextActionDate) private var negotiations: [Negotiation]
    @Query(sort: \MessageTemplate.createdAt, order: .reverse) private var templates: [MessageTemplate]
    @Query(sort: \Gig.date) private var gigs: [Gig]
    @Query(sort: \RadarEvent.dateISO) private var radarEvents: [RadarEvent]
    @Query(sort: \TripPlan.dateISO) private var tripPlans: [TripPlan]

    @State private var selectedTab = 0
    @State private var showingLeadForm = false
    @State private var showingPromoterForm = false
    @State private var showingGigForm = false
    @State private var showingRadarForm = false
    @State private var showingTripForm = false
    @State private var feedbackMessage = ""
    @State private var bookingAdvisorResult = ""
    @State private var isRunningAdvisor = false

    private let calendarService = CalendarService()
    private let notificationPlanner = NotificationPlanner()

        // Leads Frios
        @State private var coldLeadMessages: [String: String] = [:]  // leadId → generated message
        @State private var generatingColdLeadId: String? = nil

        private var coldLeads: [EventLead] {
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            return leads.filter {
                $0.eventDate < cutoff
                    && $0.status != LeadStatus.closed.rawValue
                    && $0.status != LeadStatus.scheduled.rawValue
            }
        }

    private var sectionSummaryTitle: String {
        switch selectedTab {
        case 0: return "Prospecção"
        case 1: return "Gigs"
        case 2: return "CRM"
        case 3: return "Radar"
        case 4: return "Logística"
        default: return "Calculadora"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    PsyCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Painel de eventos")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Área atual: \(sectionSummaryTitle)")
                                .font(.subheadline)
                                .foregroundStyle(PsyTheme.textSecondary)

                            HStack(spacing: 8) {
                                PsyStatusPill(text: "Leads \(leads.count)", color: PsyTheme.primary)
                                PsyStatusPill(text: "Gigs \(gigs.count)", color: PsyTheme.secondary)
                                PsyStatusPill(text: "Radar \(radarEvents.count)", color: PsyTheme.warning)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color.clear)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        tabButton(title: "Prospec", index: 0)
                        tabButton(title: "Gigs", index: 1)
                        tabButton(title: "CRM", index: 2)
                        tabButton(title: "Radar", index: 3)
                        tabButton(title: "Trips", index: 4)
                        tabButton(title: "Calc", index: 5)
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color.clear)

                if !feedbackMessage.isEmpty {
                    Section {
                        PsyCard {
                            Text(feedbackMessage)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                if selectedTab == 0 {
                    Section {
                        PsyCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundStyle(PsyTheme.accent)
                                    Text("Assessor IA de Booking")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                }
                                Text("Receba sugestões de fee, follow-up e estratégia de negociação baseadas no seu perfil.")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)
                                Button(action: runBookingAdvisor) {
                                    HStack {
                                        if isRunningAdvisor { ProgressView().tint(.white).controlSize(.small) }
                                        Text(isRunningAdvisor ? "Analisando..." : "Consultar assessor IA")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(PsyTheme.accent)
                                .disabled(isRunningAdvisor)
                                if !bookingAdvisorResult.isEmpty {
                                    Text(bookingAdvisorResult)
                                        .font(.caption)
                                        .foregroundStyle(PsyTheme.textSecondary)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                    .listRowBackground(Color.clear)

                    Section("Pipeline") {
                        ForEach(leads, id: \.persistentModelID) { lead in
                            Group {
                                if lead.status == LeadStatus.scheduled.rawValue {
                                    Button {
                                        selectedTab = 1
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(lead.name)
                                                .font(.headline)
                                            Text("\(lead.city) • \(lead.venue)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            HStack {
                                                Text(lead.instagramHandle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Label(lead.status, systemImage: "calendar")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.green)
                                            }
                                            if let promoterName = lead.promoter?.name {
                                                Text("Promoter: \(promoterName)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(lead.notes)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(PsyTheme.surfaceAlt.opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    NavigationLink {
                                        LeadDetailView(lead: lead)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(lead.name)
                                                .font(.headline)
                                            Text("\(lead.city) • \(lead.venue)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            HStack {
                                                Text(lead.instagramHandle)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Text(lead.status)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.blue)
                                            }
                                            if let promoterName = lead.promoter?.name {
                                                Text("Promoter: \(promoterName)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Text(lead.notes)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(PsyTheme.surfaceAlt.opacity(0.6))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                        }
                    }
                } else if selectedTab == 1 {
                    Section("Minhas gigs") {
                        if !coldLeads.isEmpty {
                            Section("🧊 Leads Frios (\(coldLeads.count))") {
                                ForEach(coldLeads, id: \.persistentModelID) { lead in
                                    let leadId = lead.persistentModelID.hashValue.description
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(lead.name)
                                                    .font(.headline)
                                                Text("\(lead.city) • \(lead.venue)")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text("Sem contato há +30 dias")
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                            }
                                            Spacer()
                                            Button {
                                                Task { await generateReactivationMessage(lead: lead, leadId: leadId) }
                                            } label: {
                                                if generatingColdLeadId == leadId {
                                                    ProgressView().controlSize(.small)
                                                } else {
                                                    Label("Gerar msg", systemImage: "sparkles")
                                                        .font(.caption)
                                                }
                                            }
                                            .buttonStyle(.bordered)
                                            .tint(.orange)
                                            .disabled(generatingColdLeadId != nil)
                                        }

                                        if let msg = coldLeadMessages[leadId], !msg.isEmpty {
                                            Text(msg)
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .padding(8)
                                                .background(Color.orange.opacity(0.12))
                                                .cornerRadius(8)

                                            Button {
                                                UIPasteboard.general.string = msg
                                            } label: {
                                                Label("Copiar mensagem", systemImage: "doc.on.doc")
                                                    .font(.caption2)
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(PsyTheme.surfaceAlt.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                }
                            }
                            .listRowBackground(Color.clear)
                        }

                        ForEach(gigs, id: \.persistentModelID) { gig in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(gig.title)
                                    .font(.headline)
                                Text("\(gig.city) • \(gig.state) • R$ \(Int(gig.fee))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(gig.checklistSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Button(gig.addedToCalendar ? "No calendário" : "Adicionar ao calendário") {
                                        addToCalendar(gig)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(gig.addedToCalendar)

                                    Button(gig.reminderScheduled ? "Lembrete criado" : "Criar lembrete") {
                                        scheduleReminder(gig)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(PsyTheme.primary)
                                    .disabled(gig.reminderScheduled)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(PsyTheme.surfaceAlt.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                            .contentShape(Rectangle())
                        }
                    }
                } else {
                    if selectedTab == 2 {
                    Section("Templates favoritos") {
                        let favoriteTemplates = templates.filter { $0.isFavorite }
                        if favoriteTemplates.isEmpty {
                            Text("Nenhum template favorito ainda.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(favoriteTemplates, id: \.persistentModelID) { template in
                            NavigationLink {
                                TemplateDetailView(template: template)
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(template.title)
                                        .font(.headline)
                                    Text(template.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(template.body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(PsyTheme.surfaceAlt.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                        NavigationLink("Ver biblioteca completa") {
                            TemplateLibraryView()
                        }
                    }

                    Section("Promoters") {
                        ForEach(promoters, id: \.persistentModelID) { promoter in
                            NavigationLink {
                                PromoterDetailView(promoter: promoter)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(promoter.name)
                                        .font(.headline)
                                    Text("\(promoter.city) • \(promoter.instagramHandle)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("Leads: \(promoterLeadsCount(promoter)) • Negociações: \(promoterNegotiationsCount(promoter))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(PsyTheme.surfaceAlt.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                    }
                    } else if selectedTab == 3 {
                        Section("Radar de eventos") {
                            EventRadarWithDateFilter()
                                .frame(minHeight: 360)
                                .listRowInsets(EdgeInsets())

                            NavigationLink {
                                RadarSearchView()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Abrir Radar completo")
                                        .font(.headline)
                                    Text("Busca inteligente com IA, filtros e links de contato.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(PsyTheme.surfaceAlt.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .contentShape(Rectangle())
                            }
                        }
                    } else if selectedTab == 4 {
                        LogisticsCostCalculatorView(leads: leads)
                            .listRowBackground(Color.clear)
                        // ── Trip Planner ──
                        Section("Planejamento de viagens") {
                            if tripPlans.isEmpty {
                                Text("Nenhuma viagem planejada. Toque em \"+ Viagem\".")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(tripPlans, id: \.persistentModelID) { trip in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("\(trip.fromCity)/\(trip.fromState) → \(trip.toCity)/\(trip.toState)")
                                        .font(.headline)
                                    HStack {
                                        Text(trip.dateISO)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(trip.transport)
                                            .font(.caption.bold())
                                            .foregroundStyle(PsyTheme.primary)
                                    }
                                    if !trip.budget.isEmpty {
                                        Text("Orçamento: R$ \(trip.budget)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !trip.notes.isEmpty {
                                        Text(trip.notes)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(PsyTheme.surfaceAlt.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                )
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(trip)
                                        try? modelContext.save()
                                    } label: {
                                        Label("Excluir", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } else if selectedTab == 5 {
                        Section("Calculadora avulsa") {
                            NavigationLink {
                                QuickLogisticsCalculatorView()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Abrir Calculadora completa")
                                        .font(.headline)
                                    Text("Estimativa por rota local e endereço (web) em tela dedicada.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(PsyTheme.surfaceAlt.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PsyTheme.background)
            .navigationTitle("Eventos")
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
            .sensoryFeedback(.selection, trigger: selectedTab)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if selectedTab == 0 {
                        Button("Novo lead") { showingLeadForm = true }
                    } else if selectedTab == 1 {
                        Button("Nova gig") { showingGigForm = true }
                    } else if selectedTab == 2 {
                        Button("Novo promoter") { showingPromoterForm = true }
                    } else if selectedTab == 3 {
                        Button("+ Evento") { showingRadarForm = true }
                    } else if selectedTab == 4 {
                        Button("+ Viagem") { showingTripForm = true }
                    }
                }
            }
            .sheet(isPresented: $showingLeadForm) {
                LeadFormView { lead in
                    modelContext.insert(lead)
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showingGigForm) {
                GigFormView { gig in
                    modelContext.insert(gig)
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showingPromoterForm) {
                PromoterFormView { promoter in
                    modelContext.insert(promoter)
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showingRadarForm) {
                RadarEventFormView { ev in
                    modelContext.insert(ev)
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showingTripForm) {
                TripPlanFormView { trip in
                    modelContext.insert(trip)
                    try? modelContext.save()
                }
            }
        }
    }

    private func tabButton(title: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedTab == index ? Color.black : PsyTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selectedTab == index ? PsyTheme.primary : PsyTheme.surfaceAlt)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func promoterNegotiationsCount(_ promoter: PromoterContact) -> Int {
        negotiations.filter { $0.promoter?.persistentModelID == promoter.persistentModelID }.count
    }

    private func promoterLeadsCount(_ promoter: PromoterContact) -> Int {
        leads.filter { $0.promoter?.persistentModelID == promoter.persistentModelID }.count
    }

    private func addToCalendar(_ gig: Gig) {
        Task {
            do {
                try await calendarService.createGigEvent(for: gig)
                gig.addedToCalendar = true
                try? modelContext.save()
                feedbackMessage = "Gig adicionada ao calendário do iPhone."
            } catch {
                feedbackMessage = "Não foi possível adicionar ao calendário agora."
            }
        }
    }

    private func scheduleReminder(_ gig: Gig) {
        Task {
            do {
                try await notificationPlanner.scheduleGigReminder(for: gig)
                gig.reminderScheduled = true
                try? modelContext.save()
                feedbackMessage = "Lembrete configurado para a gig."
            } catch {
                feedbackMessage = "Não foi possível criar o lembrete agora."
            }
        }
    }

    private func runBookingAdvisor() {
        isRunningAdvisor = true
        bookingAdvisorResult = ""
        Task {
            let activeLeads = leads.filter { $0.status != "Fechado" }.count
            let prompt = "Sou um DJ de \(leads.first?.city ?? "São Paulo"). Tenho \(leads.count) leads ativos, \(gigs.count) gigs confirmadas. Me dê: 1) sugestão de faixa de cache para esse nível, 2) estratégia de follow-up para leads frios, 3) 3 dicas de negociação com promoters."
            let userMessage = ManagerChatMessage(
                role: "user",
                text: "[Assessor IA de Booking] \(prompt)"
            )
            let result = await WebAIService.shared.ask(
                artistName: leads.first?.name ?? "DJ",
                prompt: prompt,
                mode: "booking",
                context: WebAIContext(
                    leads: activeLeads,
                    gigs: gigs.count,
                    contentIdeas: nil,
                    radarEvents: radarEvents.count
                )
            )
            await MainActor.run {
                modelContext.insert(userMessage)
                modelContext.insert(
                    ManagerChatMessage(
                        role: "assistant",
                        text: "[Assessor IA de Booking] \(result)"
                    )
                )
                try? modelContext.save()
                bookingAdvisorResult = result
                isRunningAdvisor = false
            }
        }
    }
}

        @MainActor
        private func generateReactivationMessage(lead: EventLead, leadId: String) async {
            generatingColdLeadId = leadId
            let prompt = """
            Crie uma mensagem de reaquecimento curta e profissional em português para o promoter "\(lead.name)" \
            da venue "\(lead.venue)" em \(lead.city)/\(lead.state). \
            O contato ficou parado por mais de 30 dias. \
            Objetivo: retomar a conversa sobre uma possível parceria de show. \
            Máximo 4 linhas. Não inclua saudações formais.
            """
            let message = await WebAIService.shared.ask(
                artistName: lead.name,
                prompt: prompt,
                mode: "followup"
            )
            coldLeadMessages[leadId] = message
            generatingColdLeadId = nil
        }

private struct LogisticsCostCalculatorView: View {
    let leads: [EventLead]

    @StateObject private var locationResolver = LocationResolver()

    @State private var selectedLeadId: PersistentIdentifier?
    @State private var originCity = ""
    @State private var originState = ""
    @State private var destinationCity = ""
    @State private var destinationState = ""
    @State private var eventDate = Date().addingTimeInterval(60 * 60 * 24 * 14)
    @State private var returnDate = Date().addingTimeInterval(60 * 60 * 24 * 15)

    @State private var fuelPrice = "6.20"
    @State private var vehicleKmPerLiter = "10"
    @State private var tollCost = "120"
    @State private var extraRoadCosts = "0"

    @State private var estimate: LogisticsEstimate?
    @State private var calculatorMessage = ""

    var body: some View {
        Section("Calculadora de logística") {
            if leads.isEmpty {
                Text("Cadastre ao menos um lead para estimar custo de deslocamento.")
                    .foregroundStyle(.secondary)
            }

            if !leads.isEmpty {
                Picker("Evento", selection: $selectedLeadId) {
                    Text("Selecionar evento").tag(Optional<PersistentIdentifier>.none)
                    ForEach(leads, id: \.persistentModelID) { lead in
                        Text("\(lead.name) • \(lead.city)-\(lead.state)")
                            .tag(Optional(lead.persistentModelID))
                    }
                }
                .onChange(of: selectedLeadId) {
                    guard let selected = leads.first(where: { $0.persistentModelID == selectedLeadId }) else { return }
                    destinationCity = selected.city
                    destinationState = selected.state
                    eventDate = selected.eventDate
                    returnDate = Calendar.current.date(byAdding: .day, value: 1, to: selected.eventDate) ?? selected.eventDate
                }
            }

            Button("Usar localização atual") {
                locationResolver.requestCurrentLocation()
            }
            .buttonStyle(.bordered)

            if !locationResolver.statusMessage.isEmpty {
                Text(locationResolver.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            TextField("Origem - cidade", text: $originCity)
            TextField("Origem - UF", text: $originState)
            TextField("Destino - cidade", text: $destinationCity)
            TextField("Destino - UF", text: $destinationState)

            DatePicker("Data do evento", selection: $eventDate, displayedComponents: [.date])
            DatePicker("Retorno", selection: $returnDate, displayedComponents: [.date])

            TextField("Preço combustível (R$/L)", text: $fuelPrice)
                .keyboardType(.decimalPad)
            TextField("Consumo do veículo (km/L)", text: $vehicleKmPerLiter)
                .keyboardType(.decimalPad)
            TextField("Pedágios totais (R$)", text: $tollCost)
                .keyboardType(.decimalPad)
            TextField("Custos extras estrada (R$)", text: $extraRoadCosts)
                .keyboardType(.decimalPad)

            Button("Calcular logística") {
                calculateLogistics()
            }
            .buttonStyle(.borderedProminent)
            .tint(PsyTheme.primary)

            if !calculatorMessage.isEmpty {
                Text(calculatorMessage)
                    .font(.caption)
                    .foregroundStyle(PsyTheme.primary)
            }
        }
        .onChange(of: locationResolver.city) {
            if !locationResolver.city.isEmpty {
                originCity = locationResolver.city
            }
        }
        .onChange(of: locationResolver.state) {
            if !locationResolver.state.isEmpty {
                originState = locationResolver.state
            }
        }

        if let estimate {
            Section("Resultado") {
                Text("Modal recomendado: \(estimate.recommendedMode)")
                    .font(.headline)
                Text(estimate.recommendationReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Estrada")
                        .font(.headline)
                    Text("Distância estimada: \(Int(estimate.road.distanceKm.rounded())) km")
                    Text("Tempo estimado: \(String(format: "%.1f", estimate.road.estimatedTravelHours)) h")
                    Text("Combustível: \(String(format: "%.1f", estimate.road.fuelLiters)) L • R$ \(Int(estimate.road.fuelCost.rounded()))")
                    Text("Pedágio: R$ \(Int(estimate.road.tollCost.rounded()))")
                    Text("Extras estrada: R$ \(Int(estimate.road.extraCosts.rounded()))")
                    Text("Total rodoviário: R$ \(Int(estimate.road.totalRoadCost.rounded()))")
                        .foregroundStyle(PsyTheme.primary)
                }
                .font(.caption)

                if let flight = estimate.flight {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Aéreo")
                            .font(.headline)
                        Text("Aeroporto origem: \(flight.originAirport.code) - \(flight.originAirport.name)")
                        Text("Aeroporto destino: \(flight.destinationAirport.code) - \(flight.destinationAirport.name)")
                        Text("Média ida: R$ \(Int(flight.oneWayFare.rounded()))")
                        Text("Média ida/volta: R$ \(Int(flight.roundTripFare.rounded()))")
                        Text("Bagagem + transfers: R$ \(Int(flight.baggageAndTransfers.rounded()))")
                        Text("Total aéreo: R$ \(Int(flight.totalAirCost.rounded()))")
                            .foregroundStyle(PsyTheme.primary)
                    }
                    .font(.caption)
                } else {
                    Text("Sem simulação aérea: origem e destino na mesma UF.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                let destinationAirports = ArtistLogisticsEstimator.airportOptions(for: destinationState)
                if !destinationAirports.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Opções de aeroporto no destino")
                            .font(.headline)
                        ForEach(destinationAirports) { airport in
                            Text("• \(airport.code) - \(airport.name) (\(airport.city))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func calculateLogistics() {
        guard !originCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !originState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !destinationCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !destinationState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            calculatorMessage = "Preencha origem e destino para calcular."
            return
        }

        let fuel = Double(fuelPrice) ?? 0
        let kmPerLiter = Double(vehicleKmPerLiter) ?? 0
        let toll = Double(tollCost) ?? 0
        let extras = Double(extraRoadCosts) ?? 0

        estimate = ArtistLogisticsEstimator.estimate(
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState,
            eventDate: eventDate,
            returnDate: returnDate,
            vehicleKmPerLiter: kmPerLiter,
            fuelPricePerLiter: fuel,
            tollCost: toll,
            extraRoadCosts: extras
        )
        calculatorMessage = "Estimativa atualizada."
    }
}

private struct LeadFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    @State private var venue = ""
    @State private var instagramHandle = ""
    @State private var notes = ""
    @State private var eventDate = Date().addingTimeInterval(60 * 60 * 24 * 14)

    let onSave: (EventLead) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Novo lead")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Cadastre evento, local e contexto para iniciar o funil de booking.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }

                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Nome do evento", text: $name)
                                .textFieldStyle(.roundedBorder)
                            TextField("Cidade", text: $city)
                                .textFieldStyle(.roundedBorder)
                            TextField("UF", text: $state)
                                .textFieldStyle(.roundedBorder)
                            TextField("Local", text: $venue)
                                .textFieldStyle(.roundedBorder)
                            TextField("Instagram", text: $instagramHandle)
                                .textFieldStyle(.roundedBorder)
                            DatePicker("Data", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                                .tint(PsyTheme.primary)
                            TextField("Observações", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Novo lead")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(EventLead(
                            name: name,
                            city: city,
                            state: state,
                            eventDate: eventDate,
                            venue: venue,
                            instagramHandle: instagramHandle,
                            status: LeadStatus.notContacted.rawValue,
                            notes: notes
                        ))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct PromoterFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var city = ""
    @State private var state = ""
    @State private var instagramHandle = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var notes = ""

    let onSave: (PromoterContact) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Novo promoter")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Organize contatos estratégicos para acelerar respostas e fechamentos.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }

                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Nome do promoter", text: $name)
                                .textFieldStyle(.roundedBorder)
                            TextField("Cidade", text: $city)
                                .textFieldStyle(.roundedBorder)
                            TextField("UF", text: $state)
                                .textFieldStyle(.roundedBorder)
                            TextField("Instagram", text: $instagramHandle)
                                .textFieldStyle(.roundedBorder)
                            TextField("Telefone", text: $phone)
                                .textFieldStyle(.roundedBorder)
                            TextField("E-mail", text: $email)
                                .textFieldStyle(.roundedBorder)
                            TextField("Observações", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Novo promoter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(PromoterContact(
                            name: name,
                            city: city,
                            state: state,
                            instagramHandle: instagramHandle,
                            phone: phone,
                            email: email,
                            notes: notes
                        ))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct LeadDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PromoterContact.name) private var promoters: [PromoterContact]
    @Query(sort: \MessageTemplate.createdAt, order: .reverse) private var templates: [MessageTemplate]
    @Query private var profiles: [ArtistProfile]

    let lead: EventLead
    @State private var selectedStatus: String
    @State private var selectedPromoterId: PersistentIdentifier?
    @State private var showingNegotiationForm = false
    @State private var aiFollowUp = ""
    @State private var isLoadingAI = false
    @State private var leadNegotiations: [Negotiation] = []
    private let engine = CareerManagerEngine()

    init(lead: EventLead) {
        self.lead = lead
        _selectedStatus = State(initialValue: lead.status)
        _selectedPromoterId = State(initialValue: lead.promoter?.persistentModelID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PsyCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(lead.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("\(lead.city) • \(lead.venue)")
                            .foregroundStyle(.secondary)
                        Text(lead.instagramHandle)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                        if !lead.notes.isEmpty {
                            Text(lead.notes)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                }

                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Status")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Picker("Fase", selection: $selectedStatus) {
                            ForEach(LeadStatus.allCases) { status in
                                Text(status.rawValue).tag(status.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedStatus) { oldValue, newValue in
                            lead.status = newValue
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                try? modelContext.save()
                            }
                        }
                    }
                }

                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Promoter")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Picker("Contato", selection: $selectedPromoterId) {
                            Text("Sem promoter").tag(Optional<PersistentIdentifier>.none)
                            ForEach(promoters, id: \.persistentModelID) { promoter in
                                Text(promoter.name).tag(Optional(promoter.persistentModelID))
                            }
                        }
                        .onChange(of: selectedPromoterId) { oldValue, newValue in
                            let selected = promoters.first { $0.persistentModelID == newValue }
                            lead.promoter = selected
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                try? modelContext.save()
                            }
                        }
                    }
                }

                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Mensagens sugeridas")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ForEach(suggestedMessages(for: selectedStatus)) { suggestion in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(suggestion.text)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                Text("Por que: \(suggestion.why)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Button(hasTemplate(for: suggestion.text) ? "Salvo" : "Salvar") {
                                        saveTemplate(suggestion.text)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(hasTemplate(for: suggestion.text))
                                    Button("Copiar") {
                                        UIPasteboard.general.string = suggestion.text
                                    }
                                    .buttonStyle(.bordered)
                                    Spacer()
                                }
                            }
                            .padding(10)
                            .background(PsyTheme.surfaceAlt.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }

                // AI follow-up suggestion card
                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(PsyTheme.primary)
                            Text("Follow-up com IA")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Button {
                                generateAIFollowUp()
                            } label: {
                                if isLoadingAI {
                                    ProgressView().controlSize(.small).tint(PsyTheme.primary)
                                } else {
                                    Text("Gerar")
                                        .font(.caption.bold())
                                        .foregroundStyle(PsyTheme.primary)
                                }
                            }
                            .disabled(isLoadingAI)
                        }
                        if aiFollowUp.isEmpty && !isLoadingAI {
                            Text("Toque em \"Gerar\" para o Manager IA criar uma mensagem de follow-up personalizada para este lead.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        } else if isLoadingAI {
                            PsySkeletonLine()
                            PsySkeletonLine(width: 200)
                        } else {
                            Text(aiFollowUp)
                                .font(.caption)
                                .foregroundStyle(.white)
                            HStack {
                                Button("Copiar") {
                                    UIPasteboard.general.string = aiFollowUp
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Button("Salvar template") {
                                    saveTemplate(aiFollowUp)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(PsyTheme.primary)
                                .controlSize(.small)
                                .disabled(hasTemplate(for: aiFollowUp))
                            }
                        }
                    }
                }

                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Negociações")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Button("Registrar") {
                                showingNegotiationForm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PsyTheme.primary)
                            .controlSize(.small)
                        }

                        if leadNegotiations.isEmpty {
                            Text("Nenhuma negociação registrada.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(leadNegotiations, id: \.persistentModelID) { negotiation in
                            let brief = BookingNegotiationCoach.coachingBrief(for: negotiation, lead: lead)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(negotiation.stage)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Oferta R$ \(Int(negotiation.offeredFee)) • Desejado R$ \(Int(negotiation.desiredFee))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Fechamento: \(brief.closeProbability)% • Risco: \(brief.riskLevel)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("Sugestão: \(brief.suggestedReply)")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                                Button("Copiar resposta") {
                                    UIPasteboard.general.string = brief.suggestedReply
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(10)
                            .background(PsyTheme.surfaceAlt.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(PsyTheme.background.ignoresSafeArea())
        .navigationTitle("Lead")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNegotiationForm) {
            NegotiationFormView(lead: lead, promoter: lead.promoter) { negotiation in
                modelContext.insert(negotiation)
                try? modelContext.save()
            }
        }
    }

    private func suggestedMessages(for status: String) -> [BookingMessageSuggestion] {
        BookingNegotiationCoach.suggestedMessages(for: lead, status: status)
    }

    private func hasTemplate(for text: String) -> Bool {
        templates.contains { $0.body == text }
    }

    private func saveTemplate(_ text: String) {
        guard !hasTemplate(for: text) else { return }
        modelContext.insert(MessageTemplate(
            title: "Template \(selectedStatus)",
            body: text,
            category: selectedStatus,
            isFavorite: true
        ))
        try? modelContext.save()
        Task {
            _ = await TemplateSyncBridge.pushFromLocal(templates: templates)
        }
    }

    private func generateAIFollowUp() {
        guard let profile = profiles.first else { return }
        isLoadingAI = true
        aiFollowUp = ""
        Task {
            let prompt = """
            Crie uma mensagem de follow-up profissional e personalizada para este lead de booking:
            - Evento: \(lead.name)
            - Local: \(lead.city), \(lead.state)
            - Venue: \(lead.venue)
            - Instagram: \(lead.instagramHandle)
            - Status atual: \(lead.status)
            - Notas: \(lead.notes)
            
            A mensagem deve ser direta, em português brasileiro, com tom persuasivo mas respeitoso.
            Máximo 3 parágrafos curtos. Não use saudações genéricas.
            """
            let result = await engine.ask(prompt: prompt, profile: profile)
            await MainActor.run {
                aiFollowUp = result
                isLoadingAI = false
            }
        }
    }
}

private struct TemplateLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MessageTemplate.createdAt, order: .reverse) private var templates: [MessageTemplate]
    @AppStorage("psy.templates.lastSyncAt") private var lastSyncAtISO = ""
    @AppStorage("psy.templates.lastSyncDirection") private var lastSyncDirection = "-"
    @AppStorage("psy.templates.lastSyncStatus") private var lastSyncStatus = "-"

    @State private var syncMessage = ""
    @State private var isSyncing = false
    @State private var isApplyingRemote = false

    private var templatesSignature: String {
        templates
            .map { "\($0.title)|\($0.body)|\($0.category)|\($0.isFavorite)" }
            .joined(separator: "||")
    }

    var body: some View {
        List {
            if templates.isEmpty {
                Section {
                    PsyCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Biblioteca vazia")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Favorite respostas no funil de eventos para montar seus templates de follow-up.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(templates, id: \.persistentModelID) { template in
                    NavigationLink {
                        TemplateDetailView(template: template)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(template.title)
                                    .font(.headline)
                                Spacer()
                                if template.isFavorite {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                }
                            }
                            Text(template.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(template.body)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PsyTheme.surfaceAlt.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(PsyTheme.background)
        .navigationTitle("Templates")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(isSyncing ? "Sincronizando..." : "Puxar") {
                    Task {
                        await pullFromCloud()
                    }
                }
                .disabled(isSyncing)

                Button(isSyncing ? "Sincronizando..." : "Enviar") {
                    Task {
                        await pushToCloud()
                    }
                }
                .disabled(isSyncing)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if let syncContext = lastSyncContext {
                    Text(syncContext)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !syncMessage.isEmpty {
                    Text(syncMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
        .task {
            await pullFromCloud()
        }
        .animation(.easeInOut(duration: 0.2), value: templates.count)
        .onChange(of: templatesSignature) {
            if isApplyingRemote || templates.isEmpty { return }
            Task {
                let status = await TemplateSyncBridge.pushFromLocal(templates: templates)
                await MainActor.run {
                    syncMessage = status
                    registerSyncResult(status: status, direction: "local->nuvem (auto)")
                }
            }
        }
    }

    private func deleteTemplates(at indexSet: IndexSet) {
        for index in indexSet {
            modelContext.delete(templates[index])
        }
        try? modelContext.save()
        Task {
            let status = await TemplateSyncBridge.pushFromLocal(templates: templates)
            await MainActor.run {
                syncMessage = status
                registerSyncResult(status: status, direction: "local->nuvem (delete)")
            }
        }
    }

    @MainActor
    private func pullFromCloud() async {
        isSyncing = true
        isApplyingRemote = true
        syncMessage = "Carregando templates da nuvem..."
        let status = await TemplateSyncBridge.pullIntoLocal(modelContext: modelContext, templates: templates)
        syncMessage = status
        registerSyncResult(status: status, direction: "nuvem->local")
        isApplyingRemote = false
        isSyncing = false
    }

    @MainActor
    private func pushToCloud() async {
        isSyncing = true
        syncMessage = "Enviando templates para nuvem..."
        let status = await TemplateSyncBridge.pushFromLocal(templates: templates)
        syncMessage = status
        registerSyncResult(status: status, direction: "local->nuvem")
        isSyncing = false
    }

    private var lastSyncContext: String? {
        guard let date = ISO8601DateFormatter().date(from: lastSyncAtISO) else {
            return nil
        }
        let relative = relativeFormatter.localizedString(for: date, relativeTo: .now)
        return "Último sync: \(relative) · origem: \(lastSyncDirection) · status: \(lastSyncStatus)"
    }

    private var relativeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }

    private func registerSyncResult(status: String, direction: String) {
        lastSyncDirection = direction
        lastSyncStatus = status.lowercased().contains("falha") ? "falha" : "ok"
        lastSyncAtISO = ISO8601DateFormatter().string(from: .now)
    }
}

private struct TemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MessageTemplate.createdAt, order: .reverse) private var allTemplates: [MessageTemplate]
    @Bindable var template: MessageTemplate
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PsyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.title)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(template.category)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }

                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Texto")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(template.body)
                            .font(.body)
                            .foregroundStyle(.white)

                        Button(copied ? "Copiado" : "Copiar texto") {
                            UIPasteboard.general.string = template.body
                            copied = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PsyTheme.primary)
                    }
                }

                PsyCard {
                    Toggle("Favorito", isOn: $template.isFavorite)
                        .tint(PsyTheme.primary)
                        .onChange(of: template.isFavorite) {
                            try? modelContext.save()
                            Task {
                                _ = await TemplateSyncBridge.pushFromLocal(templates: allTemplates)
                            }
                        }
                }
            }
            .padding(20)
        }
        .background(PsyTheme.background.ignoresSafeArea())
        .navigationTitle("Template")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            try? modelContext.save()
            Task {
                _ = await TemplateSyncBridge.pushFromLocal(templates: allTemplates)
            }
        }
    }
}

private struct PromoterDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Negotiation.nextActionDate) private var allNegotiations: [Negotiation]
    @Query(sort: \EventLead.eventDate) private var allLeads: [EventLead]

    let promoter: PromoterContact
    @State private var showingNegotiationForm = false

    private var promoterNegotiations: [Negotiation] {
        allNegotiations.filter { $0.promoter?.persistentModelID == promoter.persistentModelID }
    }

    private var promoterLeads: [EventLead] {
        allLeads.filter { $0.promoter?.persistentModelID == promoter.persistentModelID }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PsyCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(promoter.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(promoter.instagramHandle)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                        if !promoter.email.isEmpty {
                            Text(promoter.email)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        if !promoter.phone.isEmpty {
                            Text(promoter.phone)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                }

                PsyCard {
                    HStack(spacing: 8) {
                        PsyStatusPill(text: "Leads \(promoterLeads.count)", color: PsyTheme.secondary)
                        PsyStatusPill(text: "Negociações \(promoterNegotiations.count)", color: PsyTheme.primary)
                        PsyStatusPill(text: "Fechadas \(promoterNegotiations.filter { $0.stage == LeadStatus.closed.rawValue }.count)", color: PsyTheme.warning)
                    }
                }

                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Negociações")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Button("Nova") {
                                showingNegotiationForm = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PsyTheme.primary)
                            .controlSize(.small)
                        }

                        if promoterNegotiations.isEmpty {
                            Text("Nenhuma negociação com este promoter.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(promoterNegotiations, id: \.persistentModelID) { negotiation in
                            let brief = BookingNegotiationCoach.coachingBrief(for: negotiation, lead: negotiation.lead)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(negotiation.stage)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                if let leadName = negotiation.lead?.name {
                                    Text("Evento: \(leadName)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Fechamento \(brief.closeProbability)% • Risco \(brief.riskLevel)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("Resposta: \(brief.suggestedReply)")
                                    .font(.caption2)
                                    .foregroundStyle(.white)
                            }
                            .padding(10)
                            .background(PsyTheme.surfaceAlt.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(PsyTheme.background.ignoresSafeArea())
        .navigationTitle("Promoter")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNegotiationForm) {
            NegotiationFormView(lead: promoterLeads.first, promoter: promoter) { negotiation in
                modelContext.insert(negotiation)
                try? modelContext.save()
            }
        }
    }
}

private struct NegotiationFormView: View {
    @Environment(\.dismiss) private var dismiss

    let lead: EventLead?
    let promoter: PromoterContact?
    let onSave: (Negotiation) -> Void

    @State private var stage = LeadStatus.negotiating.rawValue
    @State private var offeredFee = "1000"
    @State private var desiredFee = "1500"
    @State private var notes = ""
    @State private var nextActionDate = Date().addingTimeInterval(60 * 60 * 24 * 2)

    private var offeredFeeValue: Double {
        Double(offeredFee) ?? 0
    }

    private var desiredFeeValue: Double {
        Double(desiredFee) ?? 0
    }

    private var coachingPreview: NegotiationCoachingBrief {
        let draft = Negotiation(
            stage: stage,
            offeredFee: offeredFeeValue,
            desiredFee: desiredFeeValue,
            notes: notes,
            nextActionDate: nextActionDate,
            promoter: promoter,
            lead: lead
        )
        return BookingNegotiationCoach.coachingBrief(for: draft, lead: lead)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Negociação")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Registre valores e use a IA para calibrar contra-proposta.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }

                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Fase", selection: $stage) {
                                ForEach([LeadStatus.waitingReply.rawValue, LeadStatus.negotiating.rawValue, LeadStatus.closed.rawValue], id: \.self) { value in
                                    Text(value).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)

                            TextField("Fee ofertado", text: $offeredFee)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            TextField("Fee desejado", text: $desiredFee)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            DatePicker("Próxima ação", selection: $nextActionDate, displayedComponents: [.date, .hourAndMinute])
                                .tint(PsyTheme.primary)
                            TextField("Notas", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                    }

                    PsyCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Assistente de negociação")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Fechamento estimado: \(coachingPreview.closeProbability)%")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Text("Risco: \(coachingPreview.riskLevel) • \(coachingPreview.riskReason)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Valor sugerido: R$ \(Int(coachingPreview.suggestedCounterOffer.rounded()))")
                                .foregroundStyle(PsyTheme.primary)
                            Text("Mínimo aceitável: R$ \(Int(coachingPreview.minimumAcceptable.rounded())) • Ideal: R$ \(Int(coachingPreview.idealTarget.rounded()))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Resposta sugerida: \(coachingPreview.suggestedReply)")
                                .font(.caption)
                                .foregroundStyle(.white)
                            Text("Por que: \(coachingPreview.rationale)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Negociação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(Negotiation(
                            stage: stage,
                            offeredFee: Double(offeredFee) ?? 0,
                            desiredFee: Double(desiredFee) ?? 0,
                            notes: notes,
                            nextActionDate: nextActionDate,
                            promoter: promoter,
                            lead: lead
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct GigFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var city = ""
    @State private var state = ""
    @State private var contactName = ""
    @State private var checklistSummary = "Pendrive, projeto atualizado, roupa, transporte"
    @State private var fee = "1500"
    @State private var date = Date().addingTimeInterval(60 * 60 * 24 * 10)

    let onSave: (Gig) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nova gig")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Registre dados operacionais e checklist para execução sem fricção.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }

                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Nome da gig", text: $title)
                                .textFieldStyle(.roundedBorder)
                            TextField("Cidade", text: $city)
                                .textFieldStyle(.roundedBorder)
                            TextField("UF", text: $state)
                                .textFieldStyle(.roundedBorder)
                            TextField("Contratante", text: $contactName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Fee", text: $fee)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            DatePicker("Data", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                .tint(PsyTheme.primary)
                            TextField("Checklist", text: $checklistSummary, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(3...6)
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Nova gig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(Gig(
                            title: title,
                            city: city,
                            state: state,
                            date: date,
                            fee: Double(fee) ?? 0,
                            contactName: contactName,
                            checklistSummary: checklistSummary
                        ))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - RadarEventFormView

private struct RadarEventFormView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (RadarEvent) -> Void

    @State private var eventName = ""
    @State private var city = ""
    @State private var state = ""
    @State private var instagram = ""
    @State private var eventDate = Date().addingTimeInterval(60 * 60 * 24 * 30)

    private var dateISO: String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return df.string(from: eventDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Radar de eventos")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Mapeie eventos locais para prospectar oportunidades de booking.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Nome do evento *", text: $eventName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Cidade *", text: $city)
                                .textFieldStyle(.roundedBorder)
                            TextField("UF (ex: SP) *", text: $state)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.characters)
                            TextField("Instagram do evento", text: $instagram)
                                .textFieldStyle(.roundedBorder)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                            DatePicker("Data do evento", selection: $eventDate, displayedComponents: [.date])
                                .tint(PsyTheme.primary)
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Novo evento no radar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(RadarEvent(
                            eventName: eventName.trimmingCharacters(in: .whitespaces),
                            city: city.trimmingCharacters(in: .whitespaces),
                            state: state.trimmingCharacters(in: .whitespaces).uppercased(),
                            dateISO: dateISO,
                            instagramHandle: instagram.trimmingCharacters(in: .whitespaces)
                        ))
                        dismiss()
                    }
                    .disabled(eventName.trimmingCharacters(in: .whitespaces).isEmpty ||
                              city.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - TripPlanFormView

private struct TripPlanFormView: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (TripPlan) -> Void

    @State private var fromCity = ""
    @State private var fromState = ""
    @State private var toCity = ""
    @State private var toState = ""
    @State private var transport = "Carro"
    @State private var budget = ""
    @State private var notes = ""
    @State private var tripDate = Date().addingTimeInterval(60 * 60 * 24 * 14)

    private let transportOptions = ["Carro", "Avião", "Ônibus", "Van", "Moto"]

    private var dateISO: String {
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        return df.string(from: tripDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Planejar viagem")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Registre o trajeto, modal de transporte e orçamento previsto.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                TextField("Origem - cidade *", text: $fromCity)
                                    .textFieldStyle(.roundedBorder)
                                TextField("UF *", text: $fromState)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 60)
                                    .textInputAutocapitalization(.characters)
                            }
                            HStack(spacing: 10) {
                                TextField("Destino - cidade *", text: $toCity)
                                    .textFieldStyle(.roundedBorder)
                                TextField("UF *", text: $toState)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 60)
                                    .textInputAutocapitalization(.characters)
                            }
                            DatePicker("Data", selection: $tripDate, displayedComponents: [.date])
                                .tint(PsyTheme.primary)
                            Picker("Transporte", selection: $transport) {
                                ForEach(transportOptions, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(PsyTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            TextField("Orçamento (R$)", text: $budget)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            TextField("Observações", text: $notes, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Nova viagem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(TripPlan(
                            fromCity: fromCity.trimmingCharacters(in: .whitespaces),
                            fromState: fromState.trimmingCharacters(in: .whitespaces).uppercased(),
                            toCity: toCity.trimmingCharacters(in: .whitespaces),
                            toState: toState.trimmingCharacters(in: .whitespaces).uppercased(),
                            dateISO: dateISO,
                            transport: transport,
                            budget: budget.trimmingCharacters(in: .whitespaces),
                            notes: notes.trimmingCharacters(in: .whitespaces)
                        ))
                        dismiss()
                    }
                    .disabled(fromCity.trimmingCharacters(in: .whitespaces).isEmpty ||
                              toCity.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
