import SwiftData
import SwiftUI

struct StrategyModuleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArtistProfile.createdAt, order: .reverse) private var profiles: [ArtistProfile]
    @Query(sort: \SocialContentPlanItem.createdAt, order: .reverse) private var contentPlanItems: [SocialContentPlanItem]
    @Query(sort: \Gig.date) private var gigs: [Gig]
    @Query(sort: \EventLead.eventDate) private var leads: [EventLead]
    @Query(sort: \RadarEvent.dateISO) private var radarEvents: [RadarEvent]

    @AppStorage("strategy.chat.history.v1") private var persistedHistory = ""
    @AppStorage("strategy.chat.lastCleared.v1") private var lastClearedHistory = ""

    @State private var chatMessages: [StrategyChatMessage] = []
    @State private var inputText = ""
    @State private var feedback = ""
    @State private var showClearAlert = false
    @State private var isSending = false

    init() {}

    struct StrategyChatMessage: Identifiable, Codable {
        let id: UUID
        let role: String
        let content: String
        let timestamp: Date
        let suggestions: [AISuggestion]
    }

    struct AISuggestion: Identifiable, Codable {
        let id: UUID
        let title: String
        let format: String
        let objective: String
        let pillar: String
        let hook: String
        let caption: String
    }

    private var activeProfile: ArtistProfile? {
        profiles.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Módulo Estratégia")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Salvar ideias direto no backlog")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Menu {
                    Button("Recuperar conversa") { loadHistory() }
                    Button("Recuperar última limpa") { restoreLastClearedHistory() }
                    Button("Limpar conversa", role: .destructive) { showClearAlert = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(PsyTheme.primary)
                }
            }
            .padding()
            .background(PsyTheme.surface)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if chatMessages.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "wand.and.sparkles")
                                .font(.system(size: 34))
                                .foregroundStyle(PsyTheme.primary)
                            Text("Descreva um objetivo e eu sugiro ideias acionaveis.")
                                .font(.subheadline)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    ForEach(chatMessages) { message in
                        VStack(alignment: .leading, spacing: 10) {
                            EnhancedMarkdownChatBubble(
                                message: message.content,
                                isAssistant: message.role == "assistant"
                            )
                            
                            // Show quick actions extracted from assistant response
                            if message.role == "assistant" {
                                let suggestions = QuickActionService.parseActionSuggestions(from: message.content)
                                if !suggestions.isEmpty {
                                    QuickActionsButtonRow(
                                        suggestions: suggestions,
                                        onActionExecuted: { _ in
                                            feedback = "Ação executada com sucesso"
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                feedback = ""
                                            }
                                        }
                                    )
                                }
                            }

                            if message.role == "assistant", !message.suggestions.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(message.suggestions) { suggestion in
                                        suggestionCard(suggestion)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }

            if !feedback.isEmpty {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(PsyTheme.primary)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            Divider()

            if isSending {
                VStack(spacing: 12) {
                    SkeletonChatMessage()
                    SkeletonChatMessage()
                    
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(PsyTheme.primary)
                        Text("Estratégia IA analisando seu contexto...")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            HStack(spacing: 8) {
                TextField("Ex: preciso lotar 2 datas no proximo mes", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1 ... 4)

                Button(action: {
                    HapticFeedbackService.tapAction()
                    sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(PsyTheme.primary)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .background(PsyTheme.background)
        .onAppear(perform: loadHistory)
        .alert("Limpar conversa?", isPresented: $showClearAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Limpar", role: .destructive) { clearHistory() }
        } message: {
            Text("Esta conversa e o historico salvo serao removidos.")
        }
    }

    private func suggestionCard(_ suggestion: AISuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                PsyStatusPill(text: suggestion.format, color: PsyTheme.secondary)
            }

            Text(suggestion.hook)
                .font(.caption)
                .foregroundStyle(PsyTheme.textSecondary)

            Button {
                HapticFeedbackService.savedSuccessfully()
                saveSuggestionToBacklog(suggestion)
            } label: {
                Label("Salvar no backlog", systemImage: "bookmark.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(PsyTheme.primary)
        }
        .padding(12)
        .background(PsyTheme.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func sendMessage() {
        let cleaned = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        chatMessages.append(.init(
            id: UUID(),
            role: "user",
            content: cleaned,
            timestamp: Date(),
            suggestions: []
        ))

        inputText = ""
        feedback = ""
        isSending = true
        persistHistory()

        Task {
            let suggestions = buildSuggestions(from: cleaned)
            let historyPayload = chatMessages.suffix(6).map { (role: $0.role, text: $0.content) }
            let enrichedPrompt = ArtistAIContextBuilder.unifiedPrompt(
                request: cleaned,
                profile: activeProfile,
                facts: [],
                snapshot: AIWorkspaceSnapshot(
                    leads: leads.count,
                    gigs: gigs.count,
                    contentIdeas: contentPlanItems.count,
                    radarEvents: radarEvents.count
                ),
                guidance: "Responda com direção estratégica prática, prioridades de execução, ideias simples de implementar e próximos passos curtos."
            )
            let aiAnswer = await WebAIService.shared.ask(
                artistName: activeProfile?.stageName ?? "PsyManager Artist",
                prompt: enrichedPrompt,
                mode: "estrategico",
                context: WebAIContext(
                    leads: leads.count,
                    gigs: gigs.count,
                    contentIdeas: contentPlanItems.count,
                    radarEvents: radarEvents.count
                ),
                history: historyPayload
            )

            await MainActor.run {
                let response = aiAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Excelente direção. Organize a execução em blocos curtos e valide a resposta da audiência em 48h."
                    : aiAnswer

                chatMessages.append(.init(
                    id: UUID(),
                    role: "assistant",
                    content: response,
                    timestamp: Date(),
                    suggestions: suggestions
                ))
                isSending = false
                persistHistory()
            }
        }
    }

    private func buildSuggestions(from prompt: String) -> [AISuggestion] {
        [
            AISuggestion(
                id: UUID(),
                title: "Reel: bastidores da preparacao",
                format: "Reel",
                objective: "Alcance",
                pillar: "Autoridade de pista",
                hook: "Mostre 10 segundos da preparacao antes de subir ao palco.",
                caption: "Construindo o set da semana. Quer ver a tracklist completa?"
            ),
            AISuggestion(
                id: UUID(),
                title: "Carrossel com posicionamento",
                format: "Carrossel",
                objective: "Engajamento",
                pillar: "Narrativa de carreira",
                hook: "Explique seu diferencial em 3 slides objetivos.",
                caption: "Se essa visao conversa com voce, comenta \"quero\"."
            ),
            AISuggestion(
                id: UUID(),
                title: "Stories de aquecimento",
                format: "Stories",
                objective: "Conversao",
                pillar: "Comunidade",
                hook: "Abra caixa de perguntas para mapear dores da audiencia.",
                caption: "Respondo as melhores perguntas ainda hoje."
            ),
        ].map {
            AISuggestion(
                id: $0.id,
                title: $0.title,
                format: $0.format,
                objective: $0.objective,
                pillar: $0.pillar,
                hook: $0.hook,
                caption: $0.caption + "\n\nContexto: " + prompt
            )
        }
    }

    private func saveSuggestionToBacklog(_ suggestion: AISuggestion) {
        let item = SocialContentPlanItem(
            title: suggestion.title,
            contentType: suggestion.format,
            objective: suggestion.objective,
            status: "Rascunho",
            scheduledDate: .now,
            pillar: suggestion.pillar,
            hook: suggestion.hook,
            caption: suggestion.caption,
            cta: "Comente sua opiniao",
            hashtags: "#artist #music #conteudo",
            notes: "Criado no Modulo Estrategia"
        )

        modelContext.insert(item)
        do {
            try modelContext.save()
            feedback = "Ideia salva no backlog com sucesso."
        } catch {
            feedback = "Falha ao salvar no backlog."
        }
    }

    private func persistHistory() {
        guard let encoded = try? JSONEncoder().encode(chatMessages),
              let text = String(data: encoded, encoding: .utf8)
        else { return }
        persistedHistory = text
    }

    private func loadHistory() {
        guard !persistedHistory.isEmpty,
              let data = persistedHistory.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([StrategyChatMessage].self, from: data)
        else { return }
        chatMessages = decoded
        feedback = "Conversa recuperada."
    }

    private func restoreLastClearedHistory() {
        guard !lastClearedHistory.isEmpty,
              let data = lastClearedHistory.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([StrategyChatMessage].self, from: data)
        else {
            feedback = "Nenhuma conversa limpa para recuperar."
            return
        }
        chatMessages = decoded
        persistedHistory = lastClearedHistory
        feedback = "Última conversa limpa recuperada."
    }

    private func clearHistory() {
        if !persistedHistory.isEmpty {
            lastClearedHistory = persistedHistory
        }
        chatMessages.removeAll()
        persistedHistory = ""
        feedback = "Historico limpo."
    }
}

#Preview {
    StrategyModuleView()
}

