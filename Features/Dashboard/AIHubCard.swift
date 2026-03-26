import SwiftUI

/// Central IA — painel "Parceiro" (plano 7 dias) e "Semanal" (relatório de semana).
/// Equivalente ao aiHub / AI Hub do Web.
struct AIHubCard: View {

    let profile: ArtistProfile
    let leadsCount: Int
    let gigsCount: Int
    let latestInsight: SocialInsightSnapshot?

    enum AIHubMode: String, CaseIterable {
        case partner = "Parceiro"
        case weekly  = "Semanal"

        var subtitle: String {
            switch self {
            case .partner: return "Análise cruzada: social + booking. Plano para os próximos 7 dias."
            case .weekly:  return "Relatório semanal de performance com recomendações estratégicas."
            }
        }

        var promptMode: String {
            switch self {
            case .partner: return "partnership"
            case .weekly:  return "weekly-report"
            }
        }
    }

    @AppStorage("aiHub.partnerResponse") private var partnerCache = ""
    @AppStorage("aiHub.weeklyReport")   private var weeklyCache  = ""
    @AppStorage("aiHub.weeklyLastDate") private var weeklyLastDate = ""

    @State private var mode: AIHubMode = .partner
    @State private var isLoading = false

    private var currentResponse: String {
        mode == .partner ? partnerCache : weeklyCache
    }

    // Auto-generate weekly report on Monday if not yet done today
    private var weeklyIsStale: Bool {
        guard !weeklyCache.isEmpty else { return false }
        let today = ISO8601DateFormatter().string(from: .now).prefix(10)
        return !weeklyLastDate.hasPrefix(String(today))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Central IA", title: "Hub Estratégico")

            PsyCard {
                VStack(alignment: .leading, spacing: 14) {

                    // Mode picker
                    Picker("Modo", selection: $mode) {
                        ForEach(AIHubMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(mode.subtitle)
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)

                    // Response area
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(PsyTheme.primary)
                            Text(mode == .partner ? "Cruzando dados..." : "Montando relatório...")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    } else if !currentResponse.isEmpty {
                        Text(.init(currentResponse))
                            .font(.caption)
                            .foregroundStyle(.white)
                            .textSelection(.enabled)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Toque em \"Gerar análise\" para receber insights personalizados.")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }

                    // Action button
                    Button {
                        Task { await generate() }
                    } label: {
                        Label(currentResponse.isEmpty ? "Gerar análise" : "Atualizar",
                              systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isLoading ? PsyTheme.primary.opacity(0.4) : PsyTheme.primary)
                            .foregroundStyle(isLoading ? PsyTheme.textSecondary : .black)
                            .cornerRadius(8)
                            .fontWeight(.semibold)
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            // Auto-run weekly report on Mondays if cache is stale
            let weekday = Calendar.current.component(.weekday, from: .now)
            if weekday == 2 && weeklyIsStale {
                let today = ISO8601DateFormatter().string(from: .now).prefix(10)
                if !weeklyLastDate.hasPrefix(String(today)) {
                    let prevMode = mode
                    mode = .weekly
                    Task {
                        await generate()
                        await MainActor.run { mode = prevMode }
                    }
                }
            }
        }
    }

    private func generate() async {
        isLoading = true

        let socialContext = latestInsight.map {
            "Seguidores: \($0.followersEnd), Alcance médio: \($0.reach), Impressões: \($0.impressions)"
        } ?? "dados sociais ainda não sincronizados"

        let basePrompt: String
        if mode == .partner {
            basePrompt = """
            Sou o artista \(profile.stageName), gênero \(profile.genre), de \(profile.city) (\(profile.state)).
            Objetivo principal: \(profile.mainGoal).
            Pipeline atual: \(leadsCount) leads, \(gigsCount) gigs confirmadas.
            \(socialContext).
            Crie um plano de ação concreto para os próximos 7 dias, priorizando as 3 áreas de maior impacto na carreira agora.
            """
        } else {
            basePrompt = """
            Sou o artista \(profile.stageName) (\(profile.genre)).
            Esta semana: \(leadsCount) leads ativos, \(gigsCount) gigs.
            \(socialContext).
            Gere um relatório semanal curto incluindo: performance da semana, pontos de atenção críticos e os 3 próximos passos estratégicos mais urgentes.
            """
        }

        let result = await WebAIService.shared.ask(
            artistName: profile.stageName,
            prompt: basePrompt,
            mode: mode.promptMode,
            context: WebAIContext(leads: leadsCount, gigs: gigsCount)
        )

        await MainActor.run {
            if mode == .partner {
                partnerCache = result
            } else {
                weeklyCache = result
                weeklyLastDate = ISO8601DateFormatter().string(from: .now)
            }
            isLoading = false
        }
    }
}
