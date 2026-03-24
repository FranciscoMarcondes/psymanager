import Foundation

struct InstagramInsightRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let priority: String
}

enum InstagramInsightsAdvisor {
    static func recommendations(from snapshots: [SocialInsightSnapshot]) -> [InstagramInsightRecommendation] {
        guard let last = snapshots.sorted(by: { $0.periodEnd > $1.periodEnd }).first else {
            return [
                InstagramInsightRecommendation(
                    title: "Comece a registrar insights",
                    detail: "Adicione dados da semana ou mês para receber recomendações estratégicas de alcance e crescimento.",
                    priority: "Alta"
                ),
            ]
        }

        let growth = last.followersEnd - last.followersStart
        let reachPerPost = last.postsPublished > 0 ? last.reach / last.postsPublished : 0
        let reelWeight = last.reach > 0 ? Double(last.reelViews) / Double(last.reach) : 0

        var items: [InstagramInsightRecommendation] = []

        if growth <= 0 {
            items.append(.init(
                title: "Ajustar estratégia de crescimento",
                detail: "Seu crescimento foi \(growth). Aumente consistência de Reels com CTA de seguir e colab com artistas locais para expandir descoberta.",
                priority: "Alta"
            ))
        } else {
            items.append(.init(
                title: "Escalar o que funcionou",
                detail: "Você cresceu \(growth) seguidores no período. Replique o formato dos conteúdos com melhor retenção nas próximas 2 semanas.",
                priority: "Alta"
            ))
        }

        if reachPerPost < 1200 {
            items.append(.init(
                title: "Aumentar alcance por conteúdo",
                detail: "Seu alcance médio por post está em \(reachPerPost). Teste hooks nos 2 primeiros segundos, capas mais contrastantes e títulos curtos.",
                priority: "Média"
            ))
        }

        if reelWeight < 0.55 {
            items.append(.init(
                title: "Reforçar formato Reels",
                detail: "A proporção de visualizações de Reels está baixa. Priorize bastidores + drop principal + CTA para salvar/compartilhar.",
                priority: "Média"
            ))
        } else {
            items.append(.init(
                title: "Reels em boa performance",
                detail: "Reels estão puxando descoberta. Mantenha frequência e transforme os melhores em série temática semanal.",
                priority: "Média"
            ))
        }

        items.append(.init(
            title: "Técnicas atuais para psytrance",
            detail: "Use storytelling de pista, micro-clipes de transição, colabs com promoters e recortes de reação do público. Finalize com CTA de booking e follow.",
            priority: "Baixa"
        ))

        return items
    }

    static func weeklyActions(from snapshots: [SocialInsightSnapshot]) -> [String] {
        guard let last = snapshots.sorted(by: { $0.periodEnd > $1.periodEnd }).first else {
            return [
                "Publicar 2 Reels de performance com hook forte.",
                "Testar 1 post carrossel com narrativa de identidade artística.",
                "Revisar bio e CTA do perfil para conversão de seguidores.",
            ]
        }

        let growth = last.followersEnd - last.followersStart
        if growth < 20 {
            return [
                "Subir frequência para 4 peças na semana (3 Reels + 1 carrossel).",
                "Publicar em janela de pico e testar capa com contraste neon.",
                "Inserir CTA de seguir e salvar em todos os conteúdos da semana.",
            ]
        }

        return [
            "Manter formatos vencedores e duplicar tema de maior retenção.",
            "Converter melhor Reel em versão curta para stories com enquete.",
            "Rodar colaboração com perfil complementar para ampliar alcance orgânico.",
        ]
    }
}
