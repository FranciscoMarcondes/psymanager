import SwiftData
import SwiftUI

struct CreationStudioView: View {
    @Environment(\.modelContext) private var modelContext

    let profile: ArtistProfile

    @Query(sort: \SocialInsightSnapshot.periodEnd, order: .reverse) private var insights: [SocialInsightSnapshot]
    @Query(sort: \CareerTask.dueDate) private var tasks: [CareerTask]
    @Query(sort: \SocialContentPlanItem.scheduledDate) private var contentCalendar: [SocialContentPlanItem]
    @Query(sort: \SocialContentAnalytics.captureDate, order: .reverse) private var analytics: [SocialContentAnalytics]

    @State private var plannerFeedback = ""
    @State private var selectedObjective = SocialContentGenerator.supportedObjectives.first ?? "Alcance"
    @State private var selectedContentType = SocialContentGenerator.supportedTypes.first ?? "Reel"
    @State private var selectedPillar = "Autoridade de pista"
    @State private var generatedDraft: SocialContentDraft?
    @State private var showingPlannerForm = false
    @State private var selectedItemForStatusUpdate: SocialContentPlanItem?
    @State private var showingStatusUpdateSheet = false
    @State private var aiStrategyResult = ""
    @State private var isGeneratingStrategy = false

    private let cards = [
        ("Legenda magnética", "text.bubble.fill"),
        ("Roteiro de reel", "video.fill"),
        ("Estúdio de capas", "photo.artframe"),
        ("Hashtags do nicho", "number"),
    ]

    private var report: SocialMediaStrategyReport {
        SocialMediaStrategist.buildReport(profile: profile, snapshots: insights)
    }

    private var activeTasksCount: Int {
        tasks.filter { !$0.completed }.count
    }

    private var scheduledContentCount: Int {
        contentCalendar.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Studio criativo")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Conteúdo com direção estratégica")
                                        .font(.subheadline)
                                        .foregroundStyle(PsyTheme.primary)
                                }
                                Spacer()
                                Image(systemName: "camera.aperture")
                                    .font(.title)
                                    .foregroundStyle(PsyTheme.primary.opacity(0.6))
                            }

                            Text("Crie conteúdos alinhados ao seu posicionamento \(profile.toneOfVoice.lowercased()).")
                                .foregroundStyle(PsyTheme.textSecondary)

                            HStack(spacing: 8) {
                                PsyStatusPill(text: "Tarefas \(activeTasksCount)", color: PsyTheme.secondary)
                                PsyStatusPill(text: "Calendário \(scheduledContentCount)", color: PsyTheme.primary)
                                PsyStatusPill(text: "Insights \(insights.count)", color: PsyTheme.warning)
                            }
                        }
                    }

                    socialMediaSpecialist
                    aiStrategySection
                    performanceAnalyticsSection
                    editorialCalendarSection
                    contentDraftLab

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(cards, id: \.0) { item in
                            if item.0 == "Estúdio de capas" {
                                NavigationLink(destination: CoverDesignStudioView(profile: profile)) {
                                    PsyCard {
                                        VStack(alignment: .leading, spacing: 16) {
                                            Image(systemName: item.1)
                                                .font(.title2)
                                                .foregroundStyle(PsyTheme.primary)
                                            Text(item.0)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                    }
                                }
                            } else {
                                PsyCard {
                                    VStack(alignment: .leading, spacing: 16) {
                                        Image(systemName: item.1)
                                            .font(.title2)
                                            .foregroundStyle(PsyTheme.primary)
                                        Text(item.0)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Studio")
            .navigationBarTitleDisplayMode(.inline)
            .animation(.easeInOut(duration: 0.2), value: contentCalendar.count)
            .animation(.easeInOut(duration: 0.2), value: analytics.count)
            .sheet(isPresented: $showingPlannerForm) {
                SocialContentPlanFormView(profile: profile, defaultPillar: selectedPillar) { item in
                    modelContext.insert(item)
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showingStatusUpdateSheet) {
                if let item = selectedItemForStatusUpdate {
                    ContentStatusUpdateView(item: item, modelContext: modelContext, isPresented: $showingStatusUpdateSheet)
                }
            }
        }
    }

    private var aiStrategySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "IA Estratégica", title: "Estratégia semanal de conteúdo")

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "wand.and.sparkles")
                            .foregroundStyle(PsyTheme.accent)
                        Text("Gerar plano de conteúdo para essa semana com base no seu perfil e posicionamento.")
                            .font(.subheadline)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                    Button(action: generateAIStrategy) {
                        HStack {
                            if isGeneratingStrategy {
                                ProgressView().tint(.white).controlSize(.small)
                            }
                            Text(isGeneratingStrategy ? "Gerando..." : "Gerar estratégia IA")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PsyTheme.accent)
                    .disabled(isGeneratingStrategy)

                    if !aiStrategyResult.isEmpty {
                        Text(aiStrategyResult)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func generateAIStrategy() {
        isGeneratingStrategy = true
        aiStrategyResult = ""
        Task {
            let prompt = "Crie um plano de conteúdo estratégico para essa semana. Artista: \(profile.stageName), gênero: \(profile.genre), fase: \(profile.artistStage), objetivo: \(profile.mainGoal), tom: \(profile.toneOfVoice). Liste 5 ideias de conteúdo com formato, pilar e objetivo."
            let result = await WebAIService.shared.ask(
                artistName: profile.stageName,
                prompt: prompt,
                mode: "estrategico"
            )
            await MainActor.run {
                aiStrategyResult = result
                isGeneratingStrategy = false
            }
        }
    }

    private var socialMediaSpecialist: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Social Media", title: "Especialista de crescimento")

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(report.diagnostic.headline)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(report.diagnostic.summary)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        Spacer()
                        PsyStatusPill(text: report.diagnostic.signalLabel, color: diagnosticColor)
                    }

                    Button("Adicionar plano social à semana") {
                        addWeeklyPlanTasks()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PsyTheme.primary)

                    if !plannerFeedback.isEmpty {
                        Text(plannerFeedback)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.primary)
                    }
                }
            }

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sprint editorial")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(report.weeklyPlan) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.title)
                                    .foregroundStyle(.white)
                                Spacer()
                                PsyStatusPill(text: item.priority, color: item.priority == TaskPriority.high.rawValue ? PsyTheme.warning : PsyTheme.secondary)
                            }
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                            Text(item.dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(PsyTheme.primary)
                        }
                    }
                }
            }

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pilares de conteúdo")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(report.pillars) { pillar in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pillar.title)
                                .foregroundStyle(.white)
                            Text(pillar.description)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                            Text("Formato sugerido: \(pillar.recommendedFormat)")
                                .font(.caption2)
                                .foregroundStyle(PsyTheme.primary)
                        }
                    }
                }
            }

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hooks e CTA")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(report.hooks) { hook in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hook.title)
                                .foregroundStyle(.white)
                            Text(hook.example)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }

                    Divider()
                        .overlay(Color.white.opacity(0.1))

                    ForEach(report.ctas, id: \.self) { cta in
                        Text("• \(cta)")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            }

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Guia de publicação")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(report.postingGuidance, id: \.self) { guideline in
                        Text("• \(guideline)")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var performanceAnalyticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Análise", title: "Performance e recomendações")

            if analytics.isEmpty {
                PsyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sem dados de performance ainda")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Publique conteúdo nos próximos dias para começar a receber recomendações automáticas baseadas em engajamento.")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            } else {
                let typeMetrics = ContentPerformanceAnalyzer.analyzeByContentType(analytics: analytics)
                let objectiveMetrics = ContentPerformanceAnalyzer.analyzeByObjective(analytics: analytics)
                let pillarMetrics = ContentPerformanceAnalyzer.analyzeByPillar(analytics: analytics)
                let recommendation = ContentPerformanceAnalyzer.generateRecommendation(
                    from: analytics,
                    recentlyUsedType: nil,
                    recentlyUsedObjective: nil,
                    recentlyUsedPillar: nil
                )

                PsyCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Recomendação de conteúdo")
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                PsyStatusPill(text: recommendation.recommendedContentType, color: PsyTheme.primary)
                                PsyStatusPill(text: recommendation.recommendedObjective, color: PsyTheme.secondary)
                                PsyStatusPill(text: recommendation.recommendedPillar, color: PsyTheme.accent)
                            }
                            Text(recommendation.reason)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                            
                            Button(action: {
                                selectedContentType = recommendation.recommendedContentType
                                selectedObjective = recommendation.recommendedObjective
                                selectedPillar = recommendation.recommendedPillar
                                generatedDraft = SocialContentGenerator.generate(
                                    profile: profile,
                                    objective: selectedObjective,
                                    pillar: selectedPillar,
                                    type: selectedContentType
                                )
                            }) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Gerar draft recomendado")
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(PsyTheme.primary)
                        }
                    }
                }

                PsyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Métricas por formato")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(typeMetrics.sorted(by: { $0.value.avgEngagementRate > $1.value.avgEngagementRate }), id: \.key) { type, metrics in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(type)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(String(format: "%.1f%% eng.", metrics.avgEngagementRate))
                                        .font(.caption)
                                        .foregroundStyle(PsyTheme.primary)
                                }
                                ProgressView(value: metrics.avgEngagementRate, total: 10.0)
                                    .tint(metrics.avgEngagementRate > 5 ? .green : PsyTheme.warning)
                                Text("\(metrics.count) publicações")
                                    .font(.caption2)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }
                        }
                    }
                }

                PsyCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Objetivos e pilares")
                            .font(.headline)
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Por objetivo:")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.primary)
                            ForEach(objectiveMetrics.sorted(by: { $0.value.avgEngagementRate > $1.value.avgEngagementRate }), id: \.key) { objective, metrics in
                                HStack {
                                    Text(objective)
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.1f%%", metrics.avgEngagementRate))
                                        .font(.caption2)
                                        .foregroundStyle(PsyTheme.primary)
                                }
                            }
                        }

                        Divider()
                            .overlay(Color.white.opacity(0.1))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Por pilar:")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.primary)
                            ForEach(pillarMetrics.sorted(by: { $0.value.avgEngagementRate > $1.value.avgEngagementRate }), id: \.key) { pillar, metrics in
                                HStack {
                                    Text(pillar)
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.1f%%", metrics.avgEngagementRate))
                                        .font(.caption2)
                                        .foregroundStyle(PsyTheme.primary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var editorialCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Calendário", title: "Plano editorial")

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Conteúdos agendados")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Button("Novo item") {
                            showingPlannerForm = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PsyTheme.secondary)
                    }

                    if contentCalendar.isEmpty {
                        Text("Ainda não há peças planejadas. Monte seu calendário editorial e distribua descoberta, prova social e conversão durante a semana.")
                            .foregroundStyle(PsyTheme.textSecondary)
                    } else {
                        ForEach(contentCalendar.prefix(5), id: \.persistentModelID) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: ContentStatusUpdater.statusIcon(item.status))
                                        .foregroundStyle(statusColorForString(ContentStatusUpdater.statusColor(item.status)))
                                    Text(item.title)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Button(action: {
                                        selectedItemForStatusUpdate = item
                                        showingStatusUpdateSheet = true
                                    }) {
                                        Image(systemName: "pencil.circle.fill")
                                            .foregroundStyle(PsyTheme.primary)
                                    }
                                }
                                Text("\(item.contentType) • \(item.objective) • \(item.pillar)")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.primary)
                                Text(item.caption)
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)
                                Text(item.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(PsyTheme.textSecondary)
                                
                                // Show published date if available
                                if item.publishedAt != nil, let days = ContentStatusUpdater.daysPublished(item) {
                                    Text("Publicado há \(days) dia\(days == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(PsyTheme.primary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var contentDraftLab: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Generator", title: "Laboratório de conteúdo")

            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Objetivo", selection: $selectedObjective) {
                        ForEach(SocialContentGenerator.supportedObjectives, id: \.self) { objective in
                            Text(objective).tag(objective)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Formato", selection: $selectedContentType) {
                        ForEach(SocialContentGenerator.supportedTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Pilar", selection: $selectedPillar) {
                        ForEach(report.pillars.map(\.title), id: \.self) { pillar in
                            Text(pillar).tag(pillar)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack(spacing: 10) {
                        Button("Gerar draft") {
                            generatedDraft = SocialContentGenerator.generate(
                                profile: profile,
                                objective: selectedObjective,
                                pillar: selectedPillar,
                                type: selectedContentType
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PsyTheme.primary)

                        Button("Salvar no calendário") {
                            saveGeneratedDraft()
                        }
                        .buttonStyle(.bordered)
                        .disabled(generatedDraft == nil)
                    }

                    if let generatedDraft {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(generatedDraft.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(generatedDraft.hook)
                                .foregroundStyle(PsyTheme.primary)
                            Text(generatedDraft.caption)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                            Text("CTA: \(generatedDraft.cta)")
                                .font(.caption)
                                .foregroundStyle(.white)
                            Text(generatedDraft.hashtags.joined(separator: " "))
                                .font(.caption2)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var diagnosticColor: Color {
        switch report.diagnostic.signalColorName {
        case "positive":
            return .green
        case "warning":
            return PsyTheme.warning
        case "accent":
            return PsyTheme.accent
        default:
            return PsyTheme.primary
        }
    }
    
    private func statusColorForString(_ colorName: String) -> Color {
        switch colorName {
        case "positive", "success":
            return .green
        case "warning":
            return PsyTheme.warning
        case "accent":
            return PsyTheme.accent
        case "primary":
            return PsyTheme.primary
        case "secondary":
            return PsyTheme.secondary
        default:
            return .gray
        }
    }

    private func addWeeklyPlanTasks() {
        var inserted = 0

        for item in report.weeklyPlan {
            let exists = tasks.contains { task in
                task.title == item.title && Calendar.current.isDate(task.dueDate, inSameDayAs: item.dueDate)
            }

            if !exists {
                modelContext.insert(CareerTask(
                    title: item.title,
                    detail: item.detail,
                    priority: item.priority,
                    dueDate: item.dueDate
                ))
                inserted += 1
            }
        }

        try? modelContext.save()
        plannerFeedback = inserted > 0 ? "\(inserted) tarefa(s) sociais adicionada(s) ao plano." : "Seu sprint social desta semana ja foi adicionado."
    }

    private func saveGeneratedDraft() {
        guard let generatedDraft else { return }

        let scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        modelContext.insert(SocialContentPlanItem(
            title: generatedDraft.title,
            contentType: generatedDraft.contentType,
            objective: generatedDraft.objective,
            status: "Rascunho",
            scheduledDate: scheduledDate,
            pillar: generatedDraft.pillar,
            hook: generatedDraft.hook,
            caption: generatedDraft.caption,
            cta: generatedDraft.cta,
            hashtags: generatedDraft.hashtags.joined(separator: " ")
        ))
        try? modelContext.save()
        plannerFeedback = "Draft salvo no calendário editorial."
    }
}

private struct SocialContentPlanFormView: View {
    @Environment(\.dismiss) private var dismiss

    let profile: ArtistProfile
    let defaultPillar: String
    let onSave: (SocialContentPlanItem) -> Void

    @State private var title = ""
    @State private var contentType = "Reel"
    @State private var objective = "Alcance"
    @State private var status = "Planejado"
    @State private var scheduledDate = Date()
    @State private var pillar = ""
    @State private var hook = ""
    @State private var caption = ""
    @State private var cta = ""
    @State private var hashtags = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Título", text: $title)

                Picker("Formato", selection: $contentType) {
                    ForEach(SocialContentGenerator.supportedTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }

                Picker("Objetivo", selection: $objective) {
                    ForEach(SocialContentGenerator.supportedObjectives, id: \.self) { goal in
                        Text(goal).tag(goal)
                    }
                }

                TextField("Pilar", text: $pillar)
                TextField("Status", text: $status)
                DatePicker("Data", selection: $scheduledDate)
                TextField("Hook", text: $hook, axis: .vertical)
                TextField("Legenda", text: $caption, axis: .vertical)
                TextField("CTA", text: $cta, axis: .vertical)
                TextField("Hashtags", text: $hashtags, axis: .vertical)
                TextField("Notas", text: $notes, axis: .vertical)

                Button("Pré-gerar rascunho") {
                    let draft = SocialContentGenerator.generate(profile: profile, objective: objective, pillar: pillar, type: contentType)
                    if title.isEmpty {
                        title = draft.title
                    }
                    hook = draft.hook
                    caption = draft.caption
                    cta = draft.cta
                    hashtags = draft.hashtags.joined(separator: " ")
                }
            }
            .navigationTitle("Novo conteúdo")
            .onAppear {
                if pillar.isEmpty {
                    pillar = defaultPillar
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        onSave(SocialContentPlanItem(
                            title: title.isEmpty ? "\(contentType) • \(pillar)" : title,
                            contentType: contentType,
                            objective: objective,
                            status: status,
                            scheduledDate: scheduledDate,
                            pillar: pillar,
                            hook: hook,
                            caption: caption,
                            cta: cta,
                            hashtags: hashtags,
                            notes: notes
                        ))
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ContentStatusUpdateView: View {
    @Environment(\.dismiss) private var dismiss
    
    let item: SocialContentPlanItem
    let modelContext: ModelContext
    @Binding var isPresented: Bool
    
    @State private var newStatus = ""
    @State private var publishedAt = Date()
    @State private var likes = 0
    @State private var comments = 0
    @State private var shares = 0
    @State private var reach = 0
    @State private var impressions = 0
    @State private var saves = 0
    @State private var followers = 0
    @State private var feedback = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Status Atual") {
                    HStack {
                        Image(systemName: ContentStatusUpdater.statusIcon(item.status))
                            .foregroundStyle(statusColor(item.status))
                        Text(item.status)
                            .font(.headline)
                    }
                }
                
                Section("Próximo Status") {
                    Picker("Novo Status", selection: $newStatus) {
                        ForEach(ContentStatusUpdater.validStatuses, id: \.self) { status in
                            if ContentStatusUpdater.canTransitionTo(item.status, status) {
                                Text(status).tag(status)
                            }
                        }
                    }
                }
                
                if newStatus == "Publicado" {
                    Section("Data de Publicação") {
                        DatePicker("Publicado em", selection: $publishedAt, displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Section("Métricas Iniciais") {
                        Stepper("Likes: \(likes)", value: $likes, in: 0...10000)
                        Stepper("Comentários: \(comments)", value: $comments, in: 0...1000)
                        Stepper("Compartilhamentos: \(shares)", value: $shares, in: 0...500)
                        Stepper("Alcance: \(reach)", value: $reach, in: 0...50000)
                        Stepper("Impressões: \(impressions)", value: $impressions, in: 0...100000)
                        Stepper("Salvamentos: \(saves)", value: $saves, in: 0...5000)
                        Stepper("Seguidores na data: \(followers)", value: $followers, in: 0...50000)
                    }
                }
                
                if !feedback.isEmpty {
                    Section("Status") {
                        Text(feedback)
                            .foregroundStyle(PsyTheme.primary)
                    }
                }
            }
            .navigationTitle("Editar status")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Atualizar") {
                        updateStatus()
                    }
                    .disabled(newStatus.isEmpty)
                }
            }
        }
        .onAppear {
            newStatus = item.status
            if let publishedAt = item.publishedAt {
                self.publishedAt = publishedAt
            }
        }
    }
    
    private func updateStatus() {
        do {
            if newStatus == "Publicado" && item.status != "Publicado" {
                try ContentStatusUpdater.moveToPublished(
                    item: item,
                    publishedAt: publishedAt,
                    modelContext: modelContext,
                    initialEngagement: (
                        likes: likes,
                        comments: comments,
                        shares: shares,
                        reach: reach,
                        impressions: impressions,
                        saves: saves,
                        followers: followers
                    )
                )
                feedback = "Conteúdo marcado como publicado com analytics capturado."
            } else if newStatus == "Planejado" {
                try ContentStatusUpdater.moveToScheduled(item: item, scheduledDate: item.scheduledDate, modelContext: modelContext)
                feedback = "Movido para planejado."
            } else if newStatus == "Rascunho" {
                try ContentStatusUpdater.moveToDraft(item: item, modelContext: modelContext)
                feedback = "Movido para rascunho."
            } else if newStatus == "Concluído" {
                try ContentStatusUpdater.moveToCompleted(item: item, modelContext: modelContext)
                feedback = "Concluído e revisado."
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isPresented = false
            }
        } catch {
            feedback = "Erro ao atualizar: \(error.localizedDescription)"
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        let colorName = ContentStatusUpdater.statusColor(status)
        switch colorName {
        case "success":
            return .green
        case "warning":
            return PsyTheme.warning
        case "accent":
            return PsyTheme.accent
        case "primary":
            return PsyTheme.primary
        case "secondary":
            return PsyTheme.secondary
        default:
            return .gray
        }
    }
}
