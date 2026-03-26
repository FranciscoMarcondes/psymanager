import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    let profile: ArtistProfile
    let onQuickAction: (RootTab) -> Void

    @Query(sort: \Gig.date) private var gigs: [Gig]
    @Query(sort: \CareerTask.dueDate) private var tasks: [CareerTask]
    @Query(sort: \SocialContentPlanItem.createdAt, order: .reverse) private var contentPlanItems: [SocialContentPlanItem]
    @Query(sort: \ManagerChatMessage.createdAt, order: .reverse) private var managerMessages: [ManagerChatMessage]
    @Query(sort: \EventLead.eventDate) private var leads: [EventLead]
    @Query(sort: \Negotiation.createdAt) private var negotiations: [Negotiation]
    @Query(sort: \SocialInsightSnapshot.periodEnd, order: .reverse) private var insights: [SocialInsightSnapshot]
    @Query(sort: \ArtistCareerSnapshot.capturedAt, order: .reverse) private var careerSnapshots: [ArtistCareerSnapshot]
    @Query(sort: \PromoterContact.name) private var promoters: [PromoterContact]
    @Query(sort: \TripPlan.dateISO) private var tripPlans: [TripPlan]
    @Query(sort: \Expense.dateISO, order: .reverse) private var expenses: [Expense]

    @State private var plannerMessage = ""
    @State private var bookingRadarMessage = ""
    @State private var playbookMessage = ""
    @State private var postShowMessage = ""
    @State private var isRefreshingCareer360 = false
    @State private var refreshCareerMessage = ""
    @AppStorage("career360LastSourceLabel") private var career360LastSourceLabel = "Mock fallback"
    @AppStorage("career360LastSyncAt") private var career360LastSyncAtISO = ""
    @AppStorage("psy.spotify.connectionStatus") private var spotifyConnectionStatus = "Não testado"
    @AppStorage("psy.youtube.connectionStatus") private var youtubeConnectionStatus = "Não testado"
    @AppStorage("psy.soundcloud.connectionStatus") private var soundCloudConnectionStatus = "Não testado"
    @AppStorage("psy.spotify.lastCheckedAt") private var spotifyLastCheckedAtISO = ""
    @AppStorage("psy.youtube.lastCheckedAt") private var youtubeLastCheckedAtISO = ""
    @AppStorage("psy.soundcloud.lastCheckedAt") private var soundCloudLastCheckedAtISO = ""
    @AppStorage("psy.dashboard.lastAutoPostShowKey") private var lastAutoPostShowKey = ""
    @State private var dashboardMode: DashboardMode = .focus
    @State private var dismissedSmartNotificationTitles: Set<String> = []
    @State private var showExpandedDashboard = false

    private let notificationPlanner = NotificationPlanner()

        // Social sync
        @AppStorage("instagramInsightsBackendURL") private var instagramBackendURL = ""
        @AppStorage("instagramHandle.artist") private var instagramArtistHandle = ""
        @AppStorage("instagramLastInsightsSyncAt") private var instagramLastSyncAt = ""
        @State private var isSyncingInsights = false
        @State private var syncInsightsFeedback = ""

    private enum DashboardMode: String, CaseIterable, Identifiable {
        case focus = "Foco"
        case complete = "Completo"

        var id: String { rawValue }
    }

    private var outreachLeadsCount: Int {
        leads.filter { $0.status != LeadStatus.notContacted.rawValue }.count
    }

    private var respondedLeadsCount: Int {
        leads.filter {
            $0.status == LeadStatus.waitingReply.rawValue ||
                $0.status == LeadStatus.negotiating.rawValue ||
                $0.status == LeadStatus.closed.rawValue
        }.count
    }

    private var responseRateText: String {
        guard outreachLeadsCount > 0 else { return "0%" }
        let value = Double(respondedLeadsCount) / Double(outreachLeadsCount) * 100
        return "\(Int(value.rounded()))%"
    }

    private var closedDealsCount: Int {
        negotiations.filter { $0.stage == LeadStatus.closed.rawValue }.count
    }

    private var closeRateText: String {
        guard outreachLeadsCount > 0 else { return "0%" }
        let value = Double(closedDealsCount) / Double(outreachLeadsCount) * 100
        return "\(Int(value.rounded()))%"
    }

    private var latestInsight: SocialInsightSnapshot? {
        insights.sorted(by: { $0.periodEnd > $1.periodEnd }).first
    }

    private var socialGrowthText: String {
        guard let latestInsight else { return "Sem baseline" }
        let growth = latestInsight.followersEnd - latestInsight.followersStart
        return growth >= 0 ? "+\(growth) seguidores" : "\(growth) seguidores"
    }

    private var socialReachText: String {
        guard let latestInsight else { return "Sem dados" }
        let perPost = latestInsight.postsPublished > 0 ? latestInsight.reach / latestInsight.postsPublished : latestInsight.reach
        return "\(perPost) alcance/post"
    }

    private var socialFocusText: String {
        let report = SocialMediaStrategist.buildReport(profile: profile, snapshots: insights)
        return report.weeklyPlan.first?.title ?? "Registrar insights para liberar plano social"
    }

    private var latestCareerSnapshot: ArtistCareerSnapshot? {
        careerSnapshots.first
    }

    private var careerMilestones: [String] {
        guard let raw = latestCareerSnapshot?.nextMilestones,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? [String]
        else { return [] }
        return decoded
    }

    private var focusAreas: [String] {
        guard let raw = latestCareerSnapshot?.areasOfFocus,
              let data = raw.data(using: .utf8),
              let decoded = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [] }
        return decoded.map { "\($0.key): \($0.value)" }
    }

    private var weeklyPriorities: [CareerAreaPriority] {
        CareerAreaPrioritizer.buildWeeklyPriorities(
            profile: profile,
            gigs: gigs,
            leads: leads,
            negotiations: negotiations,
            tasks: tasks,
            snapshots: insights,
            promoters: promoters,
            latestCareerSnapshot: latestCareerSnapshot
        )
    }

    private var topWeeklyPriorities: [CareerAreaPriority] {
        Array(weeklyPriorities.prefix(3))
    }

    private var dataHealthScore: Int {
        var score = 40
        let statuses = [spotifyConnectionStatus, youtubeConnectionStatus, soundCloudConnectionStatus]
        score += statuses.filter { $0 == "Conectado" }.count * 15

        let now = Date()
        let dates = [spotifyLastCheckedAtISO, youtubeLastCheckedAtISO, soundCloudLastCheckedAtISO]
            .compactMap { ISO8601DateFormatter().date(from: $0) }
        let freshChecks = dates.filter { now.timeIntervalSince($0) <= 60 * 60 * 24 }.count
        score += freshChecks * 5

        return min(score, 100)
    }

    private var healthLabel: String {
        if dataHealthScore >= 80 { return "Excelente" }
        if dataHealthScore >= 60 { return "Bom" }
        return "Atenção"
    }

    private var overdueFollowupsCount: Int {
        negotiations.filter { $0.nextActionDate < Date() && $0.stage != LeadStatus.closed.rawValue }.count
    }

    private var upcomingGigs72h: [Gig] {
        let now = Date()
        let cutoff = Calendar.current.date(byAdding: .hour, value: 72, to: now) ?? now
        return gigs.filter { $0.date >= now && $0.date <= cutoff }
    }

    private var nextGigForPlaybook: Gig? {
        gigs.first { $0.date >= Date() }
    }

    private var nextGigPlaybookDays: Int? {
        guard let nextGig = nextGigForPlaybook else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let gigDay = Calendar.current.startOfDay(for: nextGig.date)
        let components = Calendar.current.dateComponents([.day], from: today, to: gigDay)
        guard let day = components.day else { return nil }
        return max(0, day)
    }

    private var nextGigPlaybookStage: String? {
        guard let days = nextGigPlaybookDays else { return nil }
        if days == 0 { return "D0" }
        if days == 1 { return "D-1" }
        if days <= 3 { return "D-3" }
        return nil
    }

    private var nextGigPlaybookTasks: [String] {
        switch nextGigPlaybookStage {
        case "D-3":
            return [
                "Confirmar logística (rota, horários e custos)",
                "Atualizar break-even da gig com custos reais",
                "Publicar conteúdo de aquecimento da data"
            ]
        case "D-1":
            return [
                "Revisar setlist e checklist técnico",
                "Enviar confirmação final para promoter",
                "Programar lembrete financeiro pós-show"
            ]
        case "D0":
            return [
                "Checar deslocamento e horário de passagem de som",
                "Confirmar materiais de divulgação ao vivo",
                "Registrar custos reais da operação da gig"
            ]
        default:
            return []
        }
    }

    private var nextGigPlaybookTaskPrefix: String? {
        guard let stage = nextGigPlaybookStage, let gig = nextGigForPlaybook else { return nil }
        return "[Playbook \(stage)] \(gig.title)"
    }

    private var nextGigPlaybookGeneratedCount: Int {
        guard let prefix = nextGigPlaybookTaskPrefix else { return 0 }
        return tasks.filter { $0.title.hasPrefix(prefix) }.count
    }

    private var nextGigPlaybookMissingTasks: Bool {
        nextGigPlaybookTaskPrefix != nil && nextGigPlaybookGeneratedCount == 0
    }

    private var recentGigForPostShow: Gig? {
        let today = Calendar.current.startOfDay(for: Date())
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return nil }
        return gigs
            .filter { $0.date >= yesterday && $0.date < today }
            .sorted { $0.date > $1.date }
            .first
    }

    private var postShowPlaybookTasks: [String] {
        [
            "Registrar fechamento financeiro real da gig",
            "Enviar follow-up e agradecimento ao promoter",
            "Publicar recap com melhores momentos"
        ]
    }

    private var postShowPlaybookTaskPrefix: String? {
        guard let gig = recentGigForPostShow else { return nil }
        return "[Playbook D+1] \(gig.title)"
    }

    private var postShowPlaybookGeneratedCount: Int {
        guard let prefix = postShowPlaybookTaskPrefix else { return 0 }
        return tasks.filter { $0.title.hasPrefix(prefix) }.count
    }

    private var postShowPlaybookMissingTasks: Bool {
        postShowPlaybookTaskPrefix != nil && postShowPlaybookGeneratedCount == 0
    }

    private struct PlaybookExecutionMetric: Identifiable {
        let id = UUID()
        let stage: String
        let total: Int
        let completed: Int

        var percentage: Int {
            guard total > 0 else { return 0 }
            return Int((Double(completed) / Double(total) * 100).rounded())
        }
    }

    private var playbookExecutionMetrics: [PlaybookExecutionMetric] {
        ["D-3", "D-1", "D0", "D+1"].map { stage in
            let prefix = "[Playbook \(stage)]"
            let stageTasks = tasks.filter { $0.title.hasPrefix(prefix) }
            let stageCompleted = stageTasks.filter(\.completed).count
            return PlaybookExecutionMetric(
                stage: stage,
                total: stageTasks.count,
                completed: stageCompleted
            )
        }
    }

    private var playbookExecutionTotal: Int {
        playbookExecutionMetrics.reduce(0) { $0 + $1.total }
    }

    private var playbookExecutionCompleted: Int {
        playbookExecutionMetrics.reduce(0) { $0 + $1.completed }
    }

    private var playbookExecutionPercentage: Int {
        guard playbookExecutionTotal > 0 else { return 0 }
        return Int((Double(playbookExecutionCompleted) / Double(playbookExecutionTotal) * 100).rounded())
    }

    private struct PlaybookWeeklyPoint: Identifiable {
        let id = UUID()
        let label: String
        let pct: Double
        let total: Int
        let completed: Int
    }

    private var playbookWeeklyTrend: [PlaybookWeeklyPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysToMonday = (weekday == 1) ? 6 : weekday - 2
        guard let currentMonday = calendar.date(byAdding: .day, value: -daysToMonday, to: today) else { return [] }
        return (0..<4).map { offset in
            guard
                let weekStart = calendar.date(byAdding: .weekOfYear, value: offset - 3, to: currentMonday),
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
            else { return PlaybookWeeklyPoint(label: "S\(offset+1)", pct: 0, total: 0, completed: 0) }
            let label = offset == 3 ? "Sem." : "S-\(3 - offset)"
            let weekTasks = tasks.filter { $0.title.hasPrefix("[Playbook") && $0.dueDate >= weekStart && $0.dueDate < weekEnd }
            let done = weekTasks.filter(\.completed).count
            let pct = weekTasks.isEmpty ? 0.0 : Double(done) / Double(weekTasks.count) * 100
            return PlaybookWeeklyPoint(label: label, pct: pct, total: weekTasks.count, completed: done)
        }
    }

    private var hasPlaybookTrendData: Bool {
        playbookWeeklyTrend.contains { $0.total > 0 }
    }

    private var gigs72hMissingTripCount: Int {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        return upcomingGigs72h.filter { gig in
            let gigDateISO = dateFormatter.string(from: gig.date)
            let gigTitle = gig.title.lowercased()
            return !tripPlans.contains { trip in
                let byDateCity = trip.dateISO == gigDateISO && trip.toCity.lowercased() == gig.city.lowercased()
                let byLabel = !trip.linkedGigLabel.isEmpty && trip.linkedGigLabel.lowercased().contains(gigTitle)
                return byDateCity || byLabel
            }
        }.count
    }

    private var cashHealthPct: Int? {
        let revenue = gigs.reduce(0) { $0 + $1.fee }
        guard revenue > 0 else { return nil }
        let costs = expenses.reduce(0) { $0 + $1.amount }
        return Int(((revenue - costs) / revenue) * 100)
    }

    private var smartNotifications: [SmartNotificationModel] {
        var items: [SmartNotificationModel] = []

        if overdueFollowupsCount > 0 {
            items.append(
                SmartNotificationModel(
                    activityId: UUID(),
                    title: "Follow-up pendente",
                    description: "\(overdueFollowupsCount) negociação(ões) estão com ação atrasada.",
                    type: .warning
                )
            )
        }

        if let topOpportunity = topBookingOpportunities.first {
            items.append(
                SmartNotificationModel(
                    activityId: UUID(),
                    title: "Oportunidade no radar",
                    description: "\(topOpportunity.lead.name) em \(topOpportunity.lead.city) com alto potencial.",
                    type: .info
                )
            )
        }

        if !todayTaskItems.isEmpty, todayTaskItems.first != "Sem urgências hoje. Avance em prospecção e conteúdo." {
            items.append(
                SmartNotificationModel(
                    activityId: UUID(),
                    title: "Prioridade do dia",
                    description: todayTaskItems[0],
                    type: .success
                )
            )
        }

        if gigs72hMissingTripCount > 0 {
            items.append(
                SmartNotificationModel(
                    activityId: UUID(),
                    title: "Logística 72h",
                    description: "\(gigs72hMissingTripCount) show(s) em até 72h sem viagem planejada.",
                    type: .warning
                )
            )
        }

        if let cashHealthPct, cashHealthPct < 20, !upcomingGigs72h.isEmpty {
            items.append(
                SmartNotificationModel(
                    activityId: UUID(),
                    title: "Caixa em risco",
                    description: "Saúde financeira em \(cashHealthPct)% com show próximo. Revise break-even hoje.",
                    type: .warning
                )
            )
        }

        if let stage = nextGigPlaybookStage, let gig = nextGigForPlaybook, nextGigPlaybookMissingTasks {
            items.append(
                SmartNotificationModel(
                    activityId: UUID(),
                    title: "Playbook da próxima gig sem tarefas",
                    description: "Playbook \(stage) de \(gig.title) ainda não foi gerado.",
                    type: .warning
                )
            )
        } else if let stage = nextGigPlaybookStage, let gig = nextGigForPlaybook {
            items.append(
                SmartNotificationModel(
                    activityId: UUID(),
                    title: "Playbook da próxima gig",
                    description: "Playbook \(stage) pronto para \(gig.title).",
                    type: .info
                )
            )
        }

        if let recentGig = recentGigForPostShow, postShowPlaybookMissingTasks {
            items.append(
                SmartNotificationModel(
                    activityId: UUID(),
                    title: "Playbook pós-show sem tarefas",
                    description: "Checklist D+1 de \(recentGig.title) ainda não foi gerado.",
                    type: .warning
                )
            )
        } else if let recentGig = recentGigForPostShow {
            items.append(
                SmartNotificationModel(
                    activityId: UUID(),
                    title: "Playbook pós-show",
                    description: "Checklist D+1 disponível para \(recentGig.title).",
                    type: .warning
                )
            )
        }

        return items.filter { !dismissedSmartNotificationTitles.contains($0.title) }
    }

    private var topBookingOpportunities: [BookingOpportunity] {
        BookingRadarService.topOpportunities(
            profile: profile,
            leads: leads,
            negotiations: negotiations,
            limit: 5
        )
    }

    private var topNegotiationSignals: [NegotiationCloseSignal] {
        BookingRadarService.negotiationSignals(negotiations)
            .prefix(3)
            .map { $0 }
    }

private var weeklySeries: [DashboardWeeklyPoint] {
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
            
            return DashboardWeeklyPoint(label: "S\(offset + 1)", leads: weeklyLeads, closed: weeklyClosed)
        }
    }

    private var todayTaskItems: [String] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? Date()

        var items: [String] = []

        let dueTodayTasks = tasks.filter { $0.dueDate >= startOfToday && $0.dueDate < endOfToday && !$0.completed }
        items.append(contentsOf: dueTodayTasks.map { "Concluir: \($0.title)" })

        let overdueNegotiations = negotiations.filter { $0.nextActionDate < Date() && $0.stage != LeadStatus.closed.rawValue }
        items.append(contentsOf: overdueNegotiations.prefix(2).map { _ in "Enviar follow-up de negociação pendente" })

        if let nearGig = gigs.first(where: { $0.date < calendar.date(byAdding: .hour, value: 36, to: Date()) ?? Date.distantFuture }) {
            items.append("Revisar checklist da gig: \(nearGig.title)")
        }

        if items.isEmpty {
            items.append("Sem urgências hoje. Avance em prospecção e conteúdo.")
        }

        return Array(items.prefix(4))
    }

    private struct ReadinessCheck: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let isDone: Bool
        let target: RootTab
    }

    private var commercialReadinessChecks: [ReadinessCheck] {
        let profileComplete = !profile.stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !profile.genre.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !profile.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !profile.mainGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let connectedPlatforms = [spotifyConnectionStatus, youtubeConnectionStatus, soundCloudConnectionStatus]
            .filter { $0 == "Conectado" }
            .count

        let recentContent = contentPlanItems.filter {
            Date().timeIntervalSince($0.createdAt) <= 60 * 60 * 24 * 14
        }.count

        let openPipeline = leads.filter { $0.status != LeadStatus.notContacted.rawValue }.count

        return [
            ReadinessCheck(
                title: "Perfil comercial completo",
                detail: "Palco, gênero, cidade e objetivo definidos.",
                isDone: profileComplete,
                target: .profile
            ),
            ReadinessCheck(
                title: "Conexões de distribuição",
                detail: "Pelo menos 2 plataformas conectadas.",
                isDone: connectedPlatforms >= 2,
                target: .profile
            ),
            ReadinessCheck(
                title: "Cadência de conteúdo ativa",
                detail: "3+ ideias/publicações criadas nos últimos 14 dias.",
                isDone: recentContent >= 3,
                target: .creation
            ),
            ReadinessCheck(
                title: "Pipeline de eventos vivo",
                detail: "5+ leads em andamento sem follow-up travado.",
                isDone: openPipeline >= 5 && overdueFollowupsCount == 0,
                target: .events
            ),
            ReadinessCheck(
                title: "Ritual com manager IA",
                detail: "5+ interações recentes para orientar decisões.",
                isDone: managerMessages.count >= 5,
                target: .manager
            )
        ]
    }

    private var commercialReadinessScore: Int {
        guard !commercialReadinessChecks.isEmpty else { return 0 }
        let done = commercialReadinessChecks.filter(\.isDone).count
        return Int((Double(done) / Double(commercialReadinessChecks.count) * 100).rounded())
    }

    private var commercialReadinessLabel: String {
        switch commercialReadinessScore {
        case 85...100: return "Pronto para escalar"
        case 60..<85: return "Quase pronto"
        default: return "Ajustes críticos"
        }
    }

    private var commercialReadinessColor: Color {
        switch commercialReadinessScore {
        case 85...100: return .green
        case 60..<85: return PsyTheme.warning
        default: return PsyTheme.primary
        }
    }

    private var criticalReadinessGaps: [ReadinessCheck] {
        commercialReadinessChecks.filter { !$0.isDone }
    }

    // ─── Score de Saúde Operacional ───
    private var operationalHealthScore: Int {
        var score = 0
        let futureGigs = gigs.filter { $0.date > Date() }.count
        score += futureGigs >= 3 ? 25 : futureGigs >= 2 ? 20 : futureGigs == 1 ? 12 : 0
        let activeContent = contentPlanItems.filter { $0.status != "Publicado" && $0.status != "Concluído" }.count
        score += activeContent >= 5 ? 25 : activeContent >= 3 ? 18 : activeContent >= 1 ? 10 : 0
        if let health = cashHealthPct {
            score += health >= 60 ? 25 : health >= 30 ? 15 : health > 0 ? 8 : 0
        } else {
            score += !gigs.isEmpty ? 5 : 0
        }
        let activeLeadsCount = leads.filter { $0.status != LeadStatus.closed.rawValue }.count
        score += (overdueFollowupsCount == 0 && activeLeadsCount >= 5) ? 25 : (overdueFollowupsCount == 0 && activeLeadsCount >= 2) ? 18 : activeLeadsCount >= 1 ? 8 : 0
        return min(score, 100)
    }

    private var operationalHealthLabel: String {
        operationalHealthScore >= 80 ? "Operação saudável" : operationalHealthScore >= 55 ? "Atenção necessária" : "Operação crítica"
    }

    private var operationalHealthColor: Color {
        operationalHealthScore >= 80 ? .green : operationalHealthScore >= 55 ? PsyTheme.warning : PsyTheme.primary
    }

    private var weeklySummaryText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        let dateStr = formatter.string(from: Date())
        let futureGigsCount = gigs.filter { $0.date > Date() }.count
        let activeLeadsCount = leads.filter { $0.status != LeadStatus.closed.rawValue }.count
        let activeContent = contentPlanItems.filter { $0.status != "Publicado" && $0.status != "Concluído" }.count
        return "Semana de \(dateStr). Saúde operacional: \(operationalHealthScore)%. Prontidão comercial: \(commercialReadinessScore)%. Playbooks: \(playbookExecutionPercentage)%. Gigs futuras: \(futureGigsCount). Leads ativos: \(activeLeadsCount). Conteúdo em produção: \(activeContent). Follow-ups pendentes: \(overdueFollowupsCount)."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                        .psyAppear()
                    
                    // CLEAN VERSION - Focus on today's actions only
                    quickActions
                        .psyAppear(delay: 0.05)

                    PsyCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dashboard compacto")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                Text(showExpandedDashboard ? "Modo completo ativo" : "Expanda para ver painéis detalhados")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }
                            Spacer()
                            Button(showExpandedDashboard ? "Minimizar" : "Expandir") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showExpandedDashboard.toggle()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .psyAppear(delay: 0.08)

                    if showExpandedDashboard {
                        pipelineMetrics
                            .psyAppear(delay: 0.1)

                        commercialReadinessPanel
                            .psyAppear(delay: 0.12)
                        
                        // 💰 Financial Alerts Widget
                        FinancialAlertsWidget()
                            .psyAppear(delay: 0.14)

                            // 📊 Social Pulse com sync
                            socialMediaPulse
                                .psyAppear(delay: 0.145)

                            // 🤖 AI Hub — Parceiro + Semanal
                            AIHubCard(
                                profile: profile,
                                leadsCount: leads.count,
                                gigsCount: gigs.count,
                                latestInsight: latestInsight
                            )
                            .psyAppear(delay: 0.15)

                        if !smartNotifications.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                PsySectionHeader(eyebrow: "Avisos", title: "Avisos inteligentes")

                                ForEach(smartNotifications) { notification in
                                    SmartNotificationCard(
                                        notification: notification,
                                        onDismiss: {
                                            dismissedSmartNotificationTitles.insert(notification.title)
                                        },
                                        onNavigate: { _ in
                                            if notification.title.lowercased().contains("follow-up") {
                                                onQuickAction(.manager)
                                            } else if notification.title.lowercased().contains("caixa") {
                                                onQuickAction(.finances)
                                            } else if notification.title.lowercased().contains("pós-show") {
                                                onQuickAction(.finances)
                                            } else if notification.title.lowercased().contains("playbook") {
                                                onQuickAction(.events)
                                            } else {
                                                onQuickAction(.events)
                                            }
                                        }
                                    )
                                }
                            }
                            .psyAppear(delay: 0.15)
                        }
                        
                        upcomingGig
                            .psyAppear(delay: 0.16)

                        nextGigPlaybookCard
                            .psyAppear(delay: 0.17)

                        postShowPlaybookCard
                            .psyAppear(delay: 0.18)

                        if playbookExecutionTotal > 0 {
                            playbookExecutionKpiCard
                                .psyAppear(delay: 0.19)
                        }

                        operationalHealthCard
                            .psyAppear(delay: 0.20)

                        weeklySummaryCard
                            .psyAppear(delay: 0.21)
                    }
                }
                .padding(20)
                .refreshable {
                    await refreshSocialInsights()
                }
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .animation(.easeInOut(duration: 0.22), value: dashboardMode)
            .animation(.easeInOut(duration: 0.22), value: insights.count)
            .animation(.easeInOut(duration: 0.22), value: tasks.count)
            .sensoryFeedback(.selection, trigger: dashboardMode)
            .onChange(of: scenePhase) {
                if scenePhase == .background {
                    Task { await refreshCareer360IfStaleInBackground() }
                }
            }
            .onAppear {
                runAutoPostShowPlaybookIfNeeded()
            }
        }
    }

    private var dashboardModePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Modo do dashboard", selection: $dashboardMode) {
                ForEach(DashboardMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Modo do dashboard")
            .accessibilityHint("Alterna entre visão foco e visão completa")

            Text(
                dashboardMode == .focus
                ? "Visão limpa para execução do dia."
                : "Visão 360° completa com todos os painéis."
            )
            .font(.caption)
            .foregroundStyle(PsyTheme.textSecondary)
            .padding(.horizontal, 2)
        }
    }

    private var career360Overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "360", title: "Carreira do artista")

            if let snapshot = latestCareerSnapshot {
                PsyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            metricCard(title: "Seguidores totais", value: "\(snapshot.totalFollowers)", detail: "somando plataformas")
                            metricCard(title: "Streams totais", value: "\(snapshot.totalStreams)", detail: "todas as fontes")
                        }

                        HStack(spacing: 12) {
                            metricCard(title: "Estágio", value: snapshot.careerStage, detail: "maturidade atual")
                            metricCard(title: "Plataforma líder", value: snapshot.dominantPlatform, detail: "maior tração")
                        }

                        PsyStatusPill(text: career360LastSourceLabel, color: career360LastSourceLabel.contains("Live") ? .green : .orange)

                        HStack(spacing: 12) {
                            metricCard(title: "Health score", value: "\(dataHealthScore)", detail: healthLabel)
                            metricCard(title: "Último sync", value: lastSyncText, detail: "pipeline 360")
                        }

                        Text(String(format: "Engajamento consolidado: %.1f%%", snapshot.engagementRate))
                            .foregroundStyle(PsyTheme.textSecondary)

                        if !careerMilestones.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Próximos marcos")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                ForEach(Array(careerMilestones.prefix(3)), id: \.self) { milestone in
                                    Text("• \(milestone)")
                                        .foregroundStyle(PsyTheme.textSecondary)
                                }
                            }
                        }

                        if !focusAreas.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Áreas de foco")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                ForEach(Array(focusAreas.prefix(2)), id: \.self) { item in
                                    Text("• \(item)")
                                        .foregroundStyle(PsyTheme.textSecondary)
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                Task { await refreshCareer360Insights() }
                            } label: {
                                if isRefreshingCareer360 {
                                    ProgressView()
                                } else {
                                    Text("Atualizar 360°")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PsyTheme.primary)
                            .disabled(isRefreshingCareer360)

                            Text("Coleta dados multi-plataforma e gera novo snapshot")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }

                        if !refreshCareerMessage.isEmpty {
                            Text(refreshCareerMessage)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.primary)
                        }
                    }
                }
            } else {
                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Sem snapshot 360 ainda. Gere os insights para visualizar a visão consolidada.")
                            .foregroundStyle(PsyTheme.textSecondary)

                        Button {
                            Task { await refreshCareer360Insights() }
                        } label: {
                            if isRefreshingCareer360 {
                                ProgressView()
                            } else {
                                Text("Gerar snapshot 360°")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PsyTheme.primary)
                        .disabled(isRefreshingCareer360)

                        if !refreshCareerMessage.isEmpty {
                            Text(refreshCareerMessage)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.primary)
                        }
                    }
                }
            }
        }
    }

    private var hero: some View {
        PsyHeroCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Boa sessão")
                            .font(.subheadline)
                            .foregroundStyle(PsyTheme.primary)
                        Text(profile.stageName)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "waveform")
                        .font(.title)
                        .foregroundStyle(PsyTheme.primary.opacity(0.5))
                }

                if let top = topWeeklyPriorities.first {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.warning)
                        Text("Foco da semana: \(top.area.title) — \(top.reason)")
                            .font(.footnote)
                            .foregroundStyle(PsyTheme.textSecondary)
                            .lineLimit(2)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack(spacing: 8) {
                    PsyStatusPill(text: profile.artistStage, color: PsyTheme.primary)
                    PsyStatusPill(text: profile.genre, color: PsyTheme.accent)
                }
            }
        }
    }

    private var weeklyFocus: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Semana", title: "Plano de ataque")

                    }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Prioridades dinâmicas")
                   Button {
                        .foregroundStyle(.white)

                    ForEach(topWeeklyPriorities) { item in
                        HStack(alignment: .top, spacing: 8) {
                            PsyStatusPill(text: "\(item.area.title) \(item.score)", color: item.score >= 75 ? PsyTheme.warning : PsyTheme.secondary)
                            Text(item.reason)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                }
            }

            ForEach(tasks.prefix(3), id: \.persistentModelID) { task in
                PsyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(task.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            PsyStatusPill(text: task.priority, color: task.priority == TaskPriority.high.rawValue ? PsyTheme.warning : PsyTheme.secondary)
                        }
                        Text(task.detail)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var heroPriorityMessage: String {
        let labels = topWeeklyPriorities.map { $0.area.title.lowercased() }
        guard !labels.isEmpty else {
            return "Seu manager esta monitorando todas as frentes da carreira esta semana."
        }

        if labels.count == 1 {
            return "Semana guiada por prioridade dinâmica em \(labels[0]), mantendo suporte integral nas demais áreas."
        }

        if labels.count == 2 {
            return "Semana guiada por prioridades dinâmicas em \(labels[0]) e \(labels[1]), com suporte 360° ativo."
        }

        return "Semana guiada por prioridades dinâmicas em \(labels[0]), \(labels[1]) e \(labels[2]), com suporte 360° ativo."
    }

    private var todayPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Today", title: "Execução do dia")

            PsyCard {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(todayTaskItems.enumerated()), id: \.offset) { idx, item in
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(PsyTheme.primary.opacity(0.15))
                                    .frame(width: 28, height: 28)
                                Text("\(idx + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(PsyTheme.primary)
                            }
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.08))
                        .padding(.vertical, 2)

                    HStack(spacing: 10) {
                        Button("Gerar tarefas") {
                            generateWeeklyTasks()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PsyTheme.primary)
                        .controlSize(.small)

                        Button("Ir para Eventos") {
                            onQuickAction(.events)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if !plannerMessage.isEmpty {
                        Text(plannerMessage)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.primary)
                    }
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Atalhos", title: "Ações de alto impacto")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                quickAction(title: "Criar mensagem", icon: "bubble.left.and.text.bubble.right.fill", color: PsyTheme.primary, target: .manager)
                quickAction(title: "Planejar reels", icon: "play.rectangle.fill", color: PsyTheme.accent, target: .creation)
                quickAction(title: "Gerar flyer", icon: "wand.and.stars", color: PsyTheme.secondary, target: .creation)
                quickAction(title: "Nova prospecção", icon: "location.magnifyingglass", color: PsyTheme.warning, target: .events)
                quickAction(title: "Planejar logística", icon: "car.fill", color: PsyTheme.primary, target: .events)
                quickAction(title: "Revisar caixa", icon: "chart.line.uptrend.xyaxis", color: PsyTheme.warning, target: .finances)
            }
        }
    }

    private var socialMediaPulse: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Growth", title: "Pulso social")

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        metricCard(title: "Seguidores", value: socialGrowthText, detail: "ultimo período")
                        metricCard(title: "Descoberta", value: socialReachText, detail: "média recente")
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Foco recomendado")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(socialFocusText)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }

                    Button("Abrir especialista social") {
                        onQuickAction(.creation)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PsyTheme.accent)
                }
            }
        }
    }
        private var socialMediaPulse: some View {
            VStack(alignment: .leading, spacing: 12) {
                PsySectionHeader(eyebrow: "Growth", title: "Pulso social")

                PsyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        // Real data from latest SocialInsightSnapshot
                        HStack(spacing: 12) {
                            if let insight = latestInsight {
                                metricCard(title: "Seguidores", value: "\(insight.followersEnd)", detail: socialGrowthText)
                                let engRate = insight.postsPublished > 0
                                    ? String(format: "%.1f%%", Double(insight.reach) / Double(max(insight.followersEnd, 1)) * 100)
                                    : "—"
                                metricCard(title: "Engajamento", value: engRate, detail: "reach/seguidores")
                            } else {
                                metricCard(title: "Seguidores", value: socialGrowthText, detail: "último período")
                                metricCard(title: "Descoberta", value: socialReachText, detail: "média recente")
                            }
                        }

                        if let insight = latestInsight {
                            HStack(spacing: 12) {
                                metricCard(title: "Alcance", value: "\(insight.reach)", detail: "último período")
                                metricCard(title: "Posts", value: "\(insight.postsPublished)", detail: insight.periodLabel)
                            }
                        }

                        // Sync status
                        HStack(spacing: 6) {
                            Image(systemName: instagramLastSyncAt.isEmpty ? "wifi.slash" : "checkmark.icloud.fill")
                                .font(.caption)
                                .foregroundStyle(instagramLastSyncAt.isEmpty ? PsyTheme.warning : .green)
                            Text(instagramLastSyncAt.isEmpty
                                 ? "Instagram não sincronizado — configure em Perfil"
                                 : "Sync: \(instagramLastSyncAt.prefix(10))")
                                .font(.caption2)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }

                        if !syncInsightsFeedback.isEmpty {
                            Text(syncInsightsFeedback)
                                .font(.caption2)
                                .foregroundStyle(PsyTheme.primary)
                        }

                        // Action row
                        HStack(spacing: 8) {
                            Button {
                                Task { await refreshSocialInsights() }
                            } label: {
                                HStack(spacing: 4) {
                                    if isSyncingInsights { ProgressView().controlSize(.mini) }
                                    Text(isSyncingInsights ? "Sincronizando..." : "⚑ Sync agora")
                                        .font(.caption).fontWeight(.semibold)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(PsyTheme.primary.opacity(isSyncingInsights ? 0.3 : 1))
                                .foregroundStyle(.black)
                                .cornerRadius(6)
                            }
                            .disabled(isSyncingInsights)

                            Button("Ver estratégia") { onQuickAction(.creation) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }

        @MainActor
        private func refreshSocialInsights() async {
            let handle = instagramArtistHandle.isEmpty ? profile.spotifyHandle : instagramArtistHandle
            guard !handle.isEmpty, !instagramBackendURL.isEmpty else { return }
            isSyncingInsights = true
            syncInsightsFeedback = ""
            do {
                let snapshots = try await InstagramInsightsBridge.sync(baseURL: instagramBackendURL, artistHandle: handle)
                let formatter = ISO8601DateFormatter()
                for item in snapshots {
                    guard let start = formatter.date(from: item.periodStartISO),
                          let end   = formatter.date(from: item.periodEndISO) else { continue }
                    modelContext.insert(SocialInsightSnapshot(
                        periodLabel:   item.periodLabel,
                        periodStart:   start,
                        periodEnd:     end,
                        followersStart: item.followersStart,
                        followersEnd:   item.followersEnd,
                        reach:          item.reach,
                        impressions:    item.impressions,
                        profileVisits:  item.profileVisits,
                        reelViews:      item.reelViews,
                        postsPublished: item.postsPublished,
                        source:         "instagram-api"
                    ))
                }
                try? modelContext.save()
                instagramLastSyncAt = ISO8601DateFormatter().string(from: .now)
                syncInsightsFeedback = "\(snapshots.count) período(s) sincronizado(s)."
            } catch {
                syncInsightsFeedback = "Não foi possível sincronizar. Configure o backend em Perfil."
            }
            isSyncingInsights = false
        }
    private func quickAction(title: String, icon: String, color: Color, target: RootTab) -> some View {
        Button {
            onQuickAction(target)
        } label: {
            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(color.opacity(0.18))
                            .frame(width: 42, height: 42)
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private var bookingRadar: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Radar", title: "Oportunidades de booking")

            PsyCard {
                VStack(alignment: .leading, spacing: 10) {
                    if topBookingOpportunities.isEmpty {
                        Text("Sem oportunidades ativas no momento.")
                            .foregroundStyle(PsyTheme.textSecondary)
                    } else {
                        ForEach(topBookingOpportunities) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.lead.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    PsyStatusPill(text: "Score \(item.score)", color: item.score >= 70 ? .green : (item.score >= 50 ? .orange : .gray))
                                }

                                Text("\(item.lead.city) • \(item.lead.venue)")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)

                                Text("Prob. fechamento: \(item.closeProbability)%")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)

                                Text("Ação: \(item.action)")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.primary)

                                HStack {
                                    Spacer()
                                    Button("Criar tarefa") {
                                        createTaskFromBookingOpportunity(item)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(PsyTheme.accent)
                                }
                            }
                        }
                    }

                    if !bookingRadarMessage.isEmpty {
                        Text(bookingRadarMessage)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.primary)
                    }
                }
            }

            PsyCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sinais de fechamento")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if topNegotiationSignals.isEmpty {
                        Text("Ainda sem negociações abertas para estimar fechamento.")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    } else {
                        ForEach(topNegotiationSignals) { signal in
                            Text("• \(signal.probability)% - \(signal.reason)")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var pipelineMetrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Pipeline", title: "Funil de booking")

            HStack(spacing: 12) {
                metricCard(title: "Prospects", value: "\(leads.count)", detail: "eventos mapeados")
                metricCard(title: "Resposta", value: responseRateText, detail: "taxa real")
                metricCard(title: "Fechamento", value: closeRateText, detail: "taxa real")
            }

            if overdueFollowupsCount > 0 {
                PsyCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Follow-up atrasado")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("\(overdueFollowupsCount) negociação(ões) aguardando ação.")
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(PsyTheme.warning)
                    }
                }
            }
        }
    }

    private var commercialReadinessPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Etapa 5", title: "Prontidão comercial")

            PsyCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Score: \(commercialReadinessScore)%")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(commercialReadinessLabel)
                                .font(.subheadline)
                                .foregroundStyle(commercialReadinessColor)
                        }
                        Spacer()
                        Button("Abrir estratégia") {
                            onQuickAction(.strategy)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    ProgressView(value: Double(commercialReadinessScore), total: 100)
                        .tint(commercialReadinessColor)

                    ForEach(commercialReadinessChecks) { check in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: check.isDone ? "checkmark.seal.fill" : "circle")
                                .foregroundStyle(check.isDone ? Color.green : PsyTheme.textSecondary)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(check.title)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                Text(check.detail)
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }

                            Spacer()

                            if !check.isDone {
                                Button("Resolver") {
                                    onQuickAction(check.target)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }

                    if let firstGap = criticalReadinessGaps.first {
                        Text("Bloqueio principal: \(firstGap.title).")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.warning)
                    }
                }
            }
        }
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        PsyCard {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(PsyTheme.textSecondary)
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(PsyTheme.textSecondary)
            }
        }
    }

    private var upcomingGig: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Operação", title: "Próxima gig")

            if let nextGig = gigs.first {
                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(nextGig.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(nextGig.city) • \(nextGig.state) • cache R$ \(Int(nextGig.fee))")
                            .foregroundStyle(PsyTheme.textSecondary)
                        Text(nextGig.checklistSummary)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            } else {
                PsyCard {
                    Text("Nenhuma gig cadastrada ainda.")
                        .foregroundStyle(PsyTheme.textSecondary)
                }
            }
        }
    }

    private var nextGigPlaybookCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Playbook", title: "Próxima gig")

            if let stage = nextGigPlaybookStage, let gig = nextGigForPlaybook {
                PsyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("🧭 Playbook da Próxima Gig · \(stage)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Button("Gerar checklist") {
                                createNextGigPlaybookTasks()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text("\(gig.title) em \(gig.city)")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(nextGigPlaybookTasks, id: \.self) { task in
                                Text("• \(task)")
                                    .font(.subheadline)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }
                        }

                        HStack(spacing: 10) {
                            Button("Abrir Eventos") {
                                onQuickAction(.events)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Abrir Finanças") {
                                onQuickAction(.finances)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if !playbookMessage.isEmpty {
                            Text(playbookMessage)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.primary)
                        }
                    }
                }
            }
        }
    }

    private var postShowPlaybookCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Playbook", title: "Pós-show D+1")

            if let gig = recentGigForPostShow {
                PsyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("🧾 Playbook Pós-Show · D+1")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Button("Gerar checklist") {
                                createPostShowPlaybookTasks()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Text("\(gig.title) em \(gig.city)")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(postShowPlaybookTasks, id: \.self) { task in
                                Text("• \(task)")
                                    .font(.subheadline)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }
                        }

                        HStack(spacing: 10) {
                            Button("Fechar Finanças") {
                                onQuickAction(.finances)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Follow-up no Manager") {
                                onQuickAction(.manager)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        if !postShowMessage.isEmpty {
                            Text(postShowMessage)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.primary)
                        }
                    }
                }
            }
        }
    }

    private var playbookExecutionKpiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "KPI", title: "Execução dos playbooks")

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(playbookExecutionCompleted)/\(playbookExecutionTotal) concluídas")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(playbookExecutionPercentage)%")
                            .font(.headline)
                            .foregroundStyle(PsyTheme.primary)
                    }

                    ProgressView(value: Double(playbookExecutionPercentage), total: 100)
                        .tint(.cyan)

                    ForEach(playbookExecutionMetrics) { metric in
                        HStack {
                            Text("Playbook \(metric.stage)")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(metric.completed)/\(metric.total) · \(metric.percentage)%")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }

                    if hasPlaybookTrendData {
                        Divider().overlay(Color.white.opacity(0.08))

                        Text("Últimas 4 semanas")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)

                        Chart {
                            ForEach(playbookWeeklyTrend) { point in
                                BarMark(
                                    x: .value("Semana", point.label),
                                    y: .value("%", point.pct)
                                )
                                .foregroundStyle(point.pct >= 80 ? Color.green : (point.pct >= 50 ? Color.cyan : (point.total > 0 ? PsyTheme.warning : PsyTheme.textSecondary)))
                                .cornerRadius(4)
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartYAxis {
                            AxisMarks(values: [0, 50, 100]) { value in
                                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(Color.white.opacity(0.1))
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text("\(Int(v))%")
                                            .font(.caption2)
                                            .foregroundStyle(PsyTheme.textSecondary)
                                    }
                                }
                            }
                        }
                        .frame(height: 110)
                    }
                }
            }
        }
    }

    private var operationalHealthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Score", title: "Saúde operacional")
            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(operationalHealthLabel)
                            .font(.headline)
                            .foregroundStyle(operationalHealthColor)
                        Spacer()
                        Text("\(operationalHealthScore)%")
                            .font(.title2.bold())
                            .foregroundStyle(operationalHealthColor)
                    }
                    ProgressView(value: Double(operationalHealthScore), total: 100)
                        .tint(operationalHealthColor)
                    HStack(spacing: 8) {
                        let pillars: [(String, Bool)] = [
                            ("Shows",    gigs.filter { $0.date > Date() }.count >= 1),
                            ("Conteúdo", contentPlanItems.filter { $0.status != "Publicado" && $0.status != "Concluído" }.count >= 3),
                            ("Finanças", (cashHealthPct ?? 0) >= 30 || !gigs.isEmpty),
                            ("Booking",  leads.filter { $0.status != LeadStatus.closed.rawValue }.count >= 2),
                        ]
                        ForEach(pillars, id: \.0) { name, ok in
                            VStack(spacing: 3) {
                                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(ok ? .green : PsyTheme.warning)
                                    .font(.footnote)
                                Text(name)
                                    .font(.caption2)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var weeklySummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Contexto IA", title: "Resumo semanal")
            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(weeklySummaryText)
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        sendWeeklyContextToManager()
                    } label: {
                        Label("Enviar para Manager IA", systemImage: "arrow.up.circle.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PsyTheme.primary)
                }
            }
        }
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Performance", title: "Evolução semanal")

            PsyCard {
                if weeklySeries.allSatisfy({ $0.leads == 0 && $0.closed == 0 }) {
                    Text("Sem dados suficientes nas últimas semanas.")
                        .foregroundStyle(PsyTheme.textSecondary)
                } else {
                    Chart {
                        ForEach(weeklySeries) { point in
                            BarMark(
                                x: .value("Semana", point.label),
                                y: .value("Leads", point.leads)
                            )
                            .foregroundStyle(PsyTheme.secondary)

                            LineMark(
                                x: .value("Semana", point.label),
                                y: .value("Fechados", point.closed)
                            )
                            .foregroundStyle(PsyTheme.primary)
                            .lineStyle(.init(lineWidth: 3))

                            PointMark(
                                x: .value("Semana", point.label),
                                y: .value("Fechados", point.closed)
                            )
                            .foregroundStyle(PsyTheme.primary)
                        }
                    }
                    .frame(height: 180)
                }
            }
        }
    }

    private func generateWeeklyTasks() {
        let drafts = CareerWeeklyPlanner.buildPlan(profile: profile, leads: leads, negotiations: negotiations, insights: insights)

        var inserted = 0
        for draft in drafts {
            let alreadyExists = tasks.contains { $0.title == draft.title && Calendar.current.isDate($0.dueDate, inSameDayAs: draft.dueDate) }
            if !alreadyExists {
                modelContext.insert(CareerTask(
                    title: draft.title,
                    detail: draft.detail,
                    priority: draft.priority,
                    dueDate: draft.dueDate
                ))
                inserted += 1
            }
        }

        try? modelContext.save()
        plannerMessage = inserted > 0 ? "\(inserted) tarefa(s) adicionada(s) ao seu plano." : "Nenhuma tarefa nova necessária agora."
    }

    private func createNextGigPlaybookTasks() {
        guard let stage = nextGigPlaybookStage,
              let gig = nextGigForPlaybook,
              !nextGigPlaybookTasks.isEmpty
        else {
            playbookMessage = "Sem playbook de gig para os próximos 3 dias."
            return
        }

        let dueDate = Calendar.current.startOfDay(for: gig.date)
        let labelPrefix = "[Playbook \(stage)] \(gig.title)"
        var inserted = 0

        for item in nextGigPlaybookTasks {
            let title = "\(labelPrefix): \(item)"
            let exists = tasks.contains {
                $0.title == title && Calendar.current.isDate($0.dueDate, inSameDayAs: dueDate)
            }

            if !exists {
                modelContext.insert(
                    CareerTask(
                        title: title,
                        detail: "Checklist operacional da gig \(gig.title) em \(gig.city).",
                        priority: TaskPriority.high.rawValue,
                        dueDate: dueDate
                    )
                )
                inserted += 1
            }
        }

        if inserted > 0 {
            try? modelContext.save()
            playbookMessage = "Checklist \(stage) criado para a próxima gig."
            onQuickAction(.creation)
        } else {
            playbookMessage = "Checklist já estava no plano."
        }
    }

    private func createPostShowPlaybookTasks() {
        let inserted = addPostShowPlaybookTasks()
        guard inserted >= 0 else {
            postShowMessage = "Sem gig recente para playbook pós-show."
            return
        }

        if inserted > 0 {
            postShowMessage = "Checklist D+1 criado para fechamento pós-show."
            onQuickAction(.creation)
        } else {
            postShowMessage = "Checklist já estava no plano."
        }
    }

    private func addPostShowPlaybookTasks() -> Int {
        guard let gig = recentGigForPostShow else {
            return -1
        }

        let dueDate = Calendar.current.startOfDay(for: Date())
        var inserted = 0
        let labelPrefix = "[Playbook D+1] \(gig.title)"

        for item in postShowPlaybookTasks {
            let title = "\(labelPrefix): \(item)"
            let exists = tasks.contains {
                $0.title == title && Calendar.current.isDate($0.dueDate, inSameDayAs: dueDate)
            }

            if !exists {
                modelContext.insert(
                    CareerTask(
                        title: title,
                        detail: "Fechamento pós-show da gig \(gig.title) em \(gig.city).",
                        priority: TaskPriority.high.rawValue,
                        dueDate: dueDate
                    )
                )
                inserted += 1
            }
        }

        if inserted > 0 {
            try? modelContext.save()
        }

        return inserted
    }

    private func runAutoPostShowPlaybookIfNeeded() {
        guard let gig = recentGigForPostShow else { return }

        let today = Calendar.current.startOfDay(for: Date())
        let key = "\(profile.stageName)-\(gig.title)-\(Int(gig.date.timeIntervalSince1970))-\(Int(today.timeIntervalSince1970))"
        guard lastAutoPostShowKey != key else { return }

        let inserted = addPostShowPlaybookTasks()
        lastAutoPostShowKey = key

        if inserted > 0 {
            postShowMessage = "Checklist D+1 automático criado para fechamento pós-show."
        }
    }

    private func createTaskFromBookingOpportunity(_ opportunity: BookingOpportunity) {
        let draft = BookingRadarService.buildTaskDraft(for: opportunity)

        let alreadyExists = tasks.contains {
            $0.title == draft.title && Calendar.current.isDate($0.dueDate, inSameDayAs: draft.dueDate)
        }

        guard !alreadyExists else {
            bookingRadarMessage = "Tarefa desse booking já existe no plano."
            return
        }

        let task = CareerTask(
            title: draft.title,
            detail: draft.detail,
            priority: draft.priority,
            dueDate: draft.dueDate
        )
        modelContext.insert(task)

        do {
            try modelContext.save()
            bookingRadarMessage = "Tarefa criada para \(opportunity.lead.name)."

            Task {
                do {
                    try await notificationPlanner.scheduleTaskReminder(for: task)
                } catch {
                    bookingRadarMessage = "Tarefa criada, mas não foi possível agendar lembrete."
                }
            }

            onQuickAction(.creation)
        } catch {
            bookingRadarMessage = "Falha ao criar tarefa de booking."
        }
    }

    @MainActor
    private func refreshCareer360Insights() async {
        guard !isRefreshingCareer360 else { return }

        isRefreshingCareer360 = true
        refreshCareerMessage = ""
        defer { isRefreshingCareer360 = false }

        let detailedInsights = await CareerInsightAggregator.fetchAllPlatformInsightsDetailed(profile: profile)
        let liveInsights = detailedInsights.map { $0.insight }
        guard !liveInsights.isEmpty else {
            refreshCareerMessage = "Não foi possível coletar dados de plataforma agora."
            return
        }

        let liveCount = detailedInsights.filter { $0.isLive }.count
        career360LastSourceLabel = liveCount > 0 ? "Live APIs (\(liveCount)/\(detailedInsights.count))" : "Mock fallback"
        career360LastSyncAtISO = ISO8601DateFormatter().string(from: Date())

        for insight in liveInsights {
            modelContext.insert(insight)
        }

        let snapshot = CareerInsightAggregator.buildCareerSnapshot(from: liveInsights)
        modelContext.insert(snapshot)

        do {
            try modelContext.save()
            refreshCareerMessage = "Snapshot 360 atualizado com \(liveInsights.count) plataformas."
        } catch {
            refreshCareerMessage = "Falha ao salvar atualização 360."
        }
    }

    private var lastSyncText: String {
        guard let date = ISO8601DateFormatter().date(from: career360LastSyncAtISO) else {
            return "Nunca"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    @MainActor
    private func refreshCareer360IfStaleInBackground() async {
        guard let last = ISO8601DateFormatter().date(from: career360LastSyncAtISO) else {
            await refreshCareer360Insights()
            return
        }

        let staleAfter: TimeInterval = 60 * 60 * 6
        if Date().timeIntervalSince(last) >= staleAfter {
            await refreshCareer360Insights()
        }
    }

    private func sendWeeklyContextToManager() {
        let message = ManagerChatMessage(role: "user", text: "[Contexto Semanal] \(weeklySummaryText)")
        modelContext.insert(message)
        try? modelContext.save()
        onQuickAction(.manager)
    }

private struct DashboardWeeklyPoint: Identifiable {
    let id = UUID()
    let label: String
    let leads: Int
    let closed: Int
}
