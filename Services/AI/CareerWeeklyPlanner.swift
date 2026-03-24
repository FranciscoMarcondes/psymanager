import Foundation

struct TaskDraft: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let priority: String
    let dueDate: Date
}

enum CareerWeeklyPlanner {
    static func buildPlan(
        profile: ArtistProfile,
        leads: [EventLead],
        negotiations: [Negotiation],
        insights: [SocialInsightSnapshot]
    ) -> [TaskDraft] {
        let calendar = Calendar.current
        let now = Date()

        var drafts: [TaskDraft] = []

        let notContacted = leads.filter { $0.status == LeadStatus.notContacted.rawValue }
        if !notContacted.isEmpty {
            drafts.append(TaskDraft(
                title: "Abordar \(min(3, notContacted.count)) leads novos",
                detail: "Priorize eventos com melhor encaixe ao estilo \(profile.genre) e personalize a primeira mensagem.",
                priority: TaskPriority.high.rawValue,
                dueDate: calendar.date(byAdding: .day, value: 1, to: now) ?? now
            ))
        }

        let overdueNegotiations = negotiations.filter {
            $0.nextActionDate < now && $0.stage != LeadStatus.closed.rawValue
        }
        if !overdueNegotiations.isEmpty {
            drafts.append(TaskDraft(
                title: "Executar follow-up pendente",
                detail: "Você tem \(overdueNegotiations.count) negociação(ões) aguardando ação. Envie follow-up hoje.",
                priority: TaskPriority.high.rawValue,
                dueDate: calendar.date(byAdding: .hour, value: 6, to: now) ?? now
            ))
        }

        if let latestInsight = insights.sorted(by: { $0.periodEnd > $1.periodEnd }).first {
            let growth = latestInsight.followersEnd - latestInsight.followersStart
            if growth < 20 {
                drafts.append(TaskDraft(
                    title: "Aumentar performance de conteúdo",
                    detail: "No último período o crescimento foi \(growth). Publique 3 reels com hook forte e CTA de follow/salvar.",
                    priority: TaskPriority.medium.rawValue,
                    dueDate: calendar.date(byAdding: .day, value: 2, to: now) ?? now
                ))
            } else {
                drafts.append(TaskDraft(
                    title: "Escalar conteúdo vencedor",
                    detail: "Repita o formato dos posts com maior alcance da última semana e transforme em série.",
                    priority: TaskPriority.medium.rawValue,
                    dueDate: calendar.date(byAdding: .day, value: 3, to: now) ?? now
                ))
            }
        }

        drafts.append(TaskDraft(
            title: "Revisar posicionamento do press kit",
            detail: "Atualize bio, destaque de set e CTA de booking para manter consistência da marca \(profile.stageName).",
            priority: TaskPriority.low.rawValue,
            dueDate: calendar.date(byAdding: .day, value: 4, to: now) ?? now
        ))

        return Array(drafts.prefix(4))
    }
}
