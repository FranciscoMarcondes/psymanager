import Foundation

enum CareerArea: String, CaseIterable, Identifiable {
    case booking
    case content
    case logistics
    case networking
    case positioning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .booking:
            return "Booking"
        case .content:
            return "Conteudo"
        case .logistics:
            return "Logistica"
        case .networking:
            return "Networking"
        case .positioning:
            return "Posicionamento"
        }
    }
}

struct CareerAreaPriority: Identifiable {
    let area: CareerArea
    let score: Int
    let reason: String

    var id: String { area.rawValue }
}

enum CareerAreaPrioritizer {
    static func buildWeeklyPriorities(
        profile: ArtistProfile,
        gigs: [Gig],
        leads: [EventLead],
        negotiations: [Negotiation],
        tasks: [CareerTask],
        snapshots: [SocialInsightSnapshot],
        promoters: [PromoterContact],
        latestCareerSnapshot: ArtistCareerSnapshot?
    ) -> [CareerAreaPriority] {
        var scores: [CareerArea: Int] = Dictionary(uniqueKeysWithValues: CareerArea.allCases.map { ($0, 50) })
        var reasons: [CareerArea: [String]] = Dictionary(uniqueKeysWithValues: CareerArea.allCases.map { ($0, []) })

        let openLeads = leads.filter { $0.status != LeadStatus.closed.rawValue }
        if openLeads.count >= 8 {
            scores[.booking, default: 50] += 22
            reasons[.booking, default: []].append("Muitos leads em aberto pedem follow-up imediato")
        } else if openLeads.count <= 2 {
            scores[.booking, default: 50] += 8
            reasons[.booking, default: []].append("Pipeline curto, hora de ampliar prospeccao")
        }

        let overdueNegotiations = negotiations.filter { $0.nextActionDate < Date() && $0.stage != LeadStatus.closed.rawValue }
        if !overdueNegotiations.isEmpty {
            scores[.booking, default: 50] += min(overdueNegotiations.count * 8, 24)
            reasons[.booking, default: []].append("Existem negociacoes vencidas sem retorno")
        }

        if let latest = snapshots.sorted(by: { $0.periodEnd > $1.periodEnd }).first {
            let growth = latest.followersEnd - latest.followersStart
            if growth < 15 {
                scores[.content, default: 50] += 22
                reasons[.content, default: []].append("Crescimento social abaixo da meta na ultima janela")
            } else if growth > 60 {
                scores[.content, default: 50] += 8
                reasons[.content, default: []].append("Tracao social boa, vale manter consistencia")
            }

            let posts = max(latest.postsPublished, 1)
            let reachPerPost = latest.reach / posts
            if reachPerPost < 1200 {
                scores[.content, default: 50] += 15
                reasons[.content, default: []].append("Alcance por post pode melhorar com ajustes criativos")
            }
        } else {
            scores[.content, default: 50] += 18
            reasons[.content, default: []].append("Sem baseline recente de redes, priorize publicacao e medicao")
        }

        if let nextGig = gigs.sorted(by: { $0.date < $1.date }).first(where: { $0.date > Date() }) {
            let hours = nextGig.date.timeIntervalSinceNow / 3600
            if hours <= 72 {
                scores[.logistics, default: 50] += 26
                reasons[.logistics, default: []].append("Gig proxima exige preparacao de rota e custos")
            } else if hours <= 168 {
                scores[.logistics, default: 50] += 14
                reasons[.logistics, default: []].append("Semana com evento: alinhar deslocamento e operacao")
            }
        }

        if promoters.count < 8 {
            scores[.networking, default: 50] += 18
            reasons[.networking, default: []].append("Base de promoters pequena para escalar agenda")
        } else {
            scores[.networking, default: 50] += 6
            reasons[.networking, default: []].append("Networking ativo deve ser mantido para recorrencia")
        }

        let highPriorityOpenTasks = tasks.filter { !$0.completed && $0.priority == TaskPriority.high.rawValue }.count
        if highPriorityOpenTasks >= 4 {
            scores[.positioning, default: 50] += 16
            reasons[.positioning, default: []].append("Muitas tarefas criticas em aberto indicam ajuste de direcao")
        }

        if let stage = latestCareerSnapshot?.careerStage, stage == "Emerging" || stage == "Growing" {
            scores[.positioning, default: 50] += 12
            reasons[.positioning, default: []].append("Fase de carreira pede reforco de marca e narrativa")
        }

        let genericReason = "Prioridade mantida para evolucao continua"

        return CareerArea.allCases
            .map { area in
                CareerAreaPriority(
                    area: area,
                    score: max(0, min(scores[area, default: 50], 100)),
                    reason: reasons[area, default: []].first ?? genericReason
                )
            }
            .sorted { $0.score > $1.score }
    }
}
