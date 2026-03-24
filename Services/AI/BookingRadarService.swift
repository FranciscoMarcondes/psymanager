import Foundation
import SwiftData

struct BookingOpportunity: Identifiable {
    let id: PersistentIdentifier
    let lead: EventLead
    let score: Int
    let closeProbability: Int
    let action: String
}

struct BookingTaskDraft {
    let title: String
    let detail: String
    let priority: String
    let dueDate: Date
}

struct NegotiationCloseSignal: Identifiable {
    let id: PersistentIdentifier
    let negotiation: Negotiation
    let probability: Int
    let reason: String
}

enum BookingRadarService {
    static func topOpportunities(
        profile: ArtistProfile,
        leads: [EventLead],
        negotiations: [Negotiation],
        limit: Int = 5
    ) -> [BookingOpportunity] {
        let openLeads = leads.filter { $0.status != LeadStatus.closed.rawValue }

        let ranked = openLeads.map { lead -> BookingOpportunity in
            let leadScore = leadPriorityScore(profile: profile, lead: lead)
            let leadNegotiations = negotiations
                .filter { $0.lead?.persistentModelID == lead.persistentModelID }
                .sorted(by: { $0.createdAt > $1.createdAt })

            let closeProbability: Int
            if let latestNegotiation = leadNegotiations.first {
                closeProbability = negotiationCloseProbability(negotiation: latestNegotiation, lead: lead).probability
            } else {
                closeProbability = baseProbabilityFromStatus(lead.status)
            }

            let action = suggestedAction(for: lead, closeProbability: closeProbability)

            return BookingOpportunity(
                id: lead.persistentModelID,
                lead: lead,
                score: leadScore,
                closeProbability: closeProbability,
                action: action
            )
        }

        return ranked
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.closeProbability > rhs.closeProbability
                }
                return lhs.score > rhs.score
            }
            .prefix(limit)
            .map { $0 }
    }

    static func negotiationSignals(_ negotiations: [Negotiation]) -> [NegotiationCloseSignal] {
        negotiations
            .filter { $0.stage != LeadStatus.closed.rawValue }
            .map { negotiation in
                let result = negotiationCloseProbability(negotiation: negotiation, lead: negotiation.lead)
                return NegotiationCloseSignal(
                    id: negotiation.persistentModelID,
                    negotiation: negotiation,
                    probability: result.probability,
                    reason: result.reason
                )
            }
            .sorted(by: { $0.probability > $1.probability })
    }

    static func buildTaskDraft(for opportunity: BookingOpportunity, referenceDate: Date = .now) -> BookingTaskDraft {
        let now = referenceDate
        let daysToEvent = Calendar.current.dateComponents([.day], from: now, to: opportunity.lead.eventDate).day ?? 0

        let priority: String
        if opportunity.closeProbability >= 70 || daysToEvent <= 7 {
            priority = TaskPriority.high.rawValue
        } else if opportunity.closeProbability >= 45 {
            priority = TaskPriority.medium.rawValue
        } else {
            priority = TaskPriority.low.rawValue
        }

        let dueDate: Date
        if priority == TaskPriority.high.rawValue {
            dueDate = Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now
        } else if priority == TaskPriority.medium.rawValue {
            dueDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        } else {
            dueDate = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now
        }

        let eventDateText = DateFormatter.shortDate.string(from: opportunity.lead.eventDate)
        let detail = "\(opportunity.action). Evento: \(opportunity.lead.venue) em \(opportunity.lead.city) no dia \(eventDateText). Probabilidade atual: \(opportunity.closeProbability)% (score \(opportunity.score))."

        return BookingTaskDraft(
            title: "Booking: \(opportunity.lead.name)",
            detail: detail,
            priority: priority,
            dueDate: dueDate
        )
    }

    private static func leadPriorityScore(profile: ArtistProfile, lead: EventLead) -> Int {
        var score = 20

        if lead.city.caseInsensitiveCompare(profile.city) == .orderedSame {
            score += 18
        }

        if lead.state.caseInsensitiveCompare(profile.state) == .orderedSame {
            score += 10
        }

        let daysToEvent = Calendar.current.dateComponents([.day], from: Date(), to: lead.eventDate).day ?? 0

        if (7 ... 45).contains(daysToEvent) {
            score += 22
        } else if (3 ... 6).contains(daysToEvent) {
            score += 10
        } else if daysToEvent < 0 {
            score -= 30
        } else if daysToEvent > 90 {
            score -= 8
        }

        switch lead.status {
        case LeadStatus.notContacted.rawValue:
            score += 16
        case LeadStatus.messageSent.rawValue:
            score += 14
        case LeadStatus.waitingReply.rawValue:
            score += 12
        case LeadStatus.negotiating.rawValue:
            score += 8
        case LeadStatus.closed.rawValue:
            score -= 50
        default:
            break
        }

        if lead.promoter != nil {
            score += 10
        }

        if !lead.instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 5
        }

        let notes = lead.notes.lowercased()
        let genreToken = profile.genre.lowercased()
        if notes.contains("psy") || notes.contains("trance") || notes.contains(genreToken) {
            score += 10
        }

        return max(0, min(100, score))
    }

    private static func negotiationCloseProbability(negotiation: Negotiation, lead: EventLead?) -> (probability: Int, reason: String) {
        var score = baseProbabilityFromStatus(negotiation.stage)
        var reasons: [String] = []

        if negotiation.desiredFee > 0 {
            let ratio = negotiation.offeredFee / negotiation.desiredFee
            if ratio >= 1.0 {
                score += 25
                reasons.append("oferta >= desejado")
            } else if ratio >= 0.9 {
                score += 15
                reasons.append("oferta próxima do desejado")
            } else if ratio >= 0.75 {
                score += 5
                reasons.append("oferta razoável")
            } else {
                score -= 10
                reasons.append("gap de fee alto")
            }
        }

        let now = Date()
        if negotiation.nextActionDate < now {
            let overdueDays = Calendar.current.dateComponents([.day], from: negotiation.nextActionDate, to: now).day ?? 0
            if overdueDays >= 2 {
                score -= 15
                reasons.append("follow-up atrasado")
            }
        } else {
            let daysToAction = Calendar.current.dateComponents([.day], from: now, to: negotiation.nextActionDate).day ?? 0
            if daysToAction <= 2 {
                score += 8
                reasons.append("próxima ação iminente")
            }
        }

        let notes = negotiation.notes.lowercased()
        if notes.contains("confirm") || notes.contains("fech") || notes.contains("ok") {
            score += 10
            reasons.append("sinal positivo nas notas")
        }
        if notes.contains("sem resposta") || notes.contains("baixo") || notes.contains("nao") {
            score -= 10
            reasons.append("sinal de risco nas notas")
        }

        if let lead {
            let daysToEvent = Calendar.current.dateComponents([.day], from: now, to: lead.eventDate).day ?? 0
            if (5 ... 40).contains(daysToEvent) {
                score += 8
                reasons.append("janela ideal para fechamento")
            } else if daysToEvent <= 3 {
                score -= 5
                reasons.append("evento muito próximo")
            } else if daysToEvent < 0 {
                score -= 20
                reasons.append("evento já passou")
            }
        }

        let normalized = max(0, min(100, score))
        let reason = reasons.isEmpty ? "sem sinais relevantes" : reasons.prefix(2).joined(separator: " + ")
        return (normalized, reason)
    }

    private static func baseProbabilityFromStatus(_ status: String) -> Int {
        switch status {
        case LeadStatus.closed.rawValue:
            return 100
        case LeadStatus.negotiating.rawValue:
            return 55
        case LeadStatus.waitingReply.rawValue:
            return 35
        case LeadStatus.messageSent.rawValue:
            return 25
        case LeadStatus.notContacted.rawValue:
            return 15
        default:
            return 20
        }
    }

    private static func suggestedAction(for lead: EventLead, closeProbability: Int) -> String {
        if closeProbability >= 70 {
            return "Enviar proposta final e travar data"
        }
        if closeProbability >= 45 {
            return "Follow-up com opções de formato e fee"
        }
        if lead.status == LeadStatus.notContacted.rawValue {
            return "Primeiro contato com press kit objetivo"
        }
        return "Reforçar prova social e pedir retorno objetivo"
    }
}

private extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .short
        return formatter
    }()
}
