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

    @State private var plannerMessage = ""
    @State private var bookingRadarMessage = ""
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
    @State private var dashboardMode: DashboardMode = .focus
    @State private var dismissedSmartNotificationTitles: Set<String> = []

    private let notificationPlanner = NotificationPlanner()

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                        .psyAppear()
                    
                    // CLEAN VERSION - Focus on today's actions only
                    quickActions
                        .psyAppear(delay: 0.05)
                    pipelineMetrics
                        .psyAppear(delay: 0.08)

                    commercialReadinessPanel
                        .psyAppear(delay: 0.1)
                    
                    // 💰 Financial Alerts Widget
                    FinancialAlertsWidget()
                        .psyAppear(delay: 0.12)

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
                                        } else {
                                            onQuickAction(.events)
                                        }
                                    }
                                )
                            }
                        }
                        .psyAppear(delay: 0.13)
                    }
                    
                    upcomingGig
                        .psyAppear(delay: 0.15)
                }
                .padding(20)
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

            PsyCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Prioridades dinâmicas")
                        .font(.headline)
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
}

private struct DashboardWeeklyPoint: Identifiable {
    let id = UUID()
    let label: String
    let leads: Int
    let closed: Int
}
