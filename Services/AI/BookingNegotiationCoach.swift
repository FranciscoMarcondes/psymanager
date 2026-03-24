import Foundation

struct BookingMessageSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let why: String
}

struct NegotiationCoachingBrief {
    let closeProbability: Int
    let riskLevel: String
    let riskReason: String
    let suggestedCounterOffer: Double
    let minimumAcceptable: Double
    let idealTarget: Double
    let suggestedReply: String
    let rationale: String
}

enum BookingNegotiationCoach {
    static func suggestedMessages(for lead: EventLead, status: String) -> [BookingMessageSuggestion] {
        if status == LeadStatus.notContacted.rawValue {
            return [
                BookingMessageSuggestion(
                    text: "Oi, time \(lead.name). Sou artista de psytrance e curti a proposta de vocês. Posso enviar press kit e proposta objetiva para uma data futura?",
                    why: "Abre conversa com contexto claro e CTA simples, elevando taxa de resposta no primeiro contato."
                ),
                BookingMessageSuggestion(
                    text: "Vi o posicionamento de \(lead.name) e acredito que meu set conversa com essa energia de pista. Se fizer sentido, envio agora material e disponibilidade.",
                    why: "Conecta seu repertório com identidade do evento e reduz fricção para o próximo passo."
                ),
            ]
        }

        if status == LeadStatus.waitingReply.rawValue || status == LeadStatus.messageSent.rawValue {
            return [
                BookingMessageSuggestion(
                    text: "Passando para reforçar meu interesse no \(lead.name). Posso te mandar proposta curta com formato de set, valor e logística em uma mensagem só?",
                    why: "Follow-up curto e específico costuma destravar respostas sem soar insistente."
                ),
                BookingMessageSuggestion(
                    text: "Se ajudar na decisão, envio duas opções de proposta (set padrão e set estendido) para vocês compararem rápido.",
                    why: "Oferece escolha objetiva e acelera decisão em promotores com pouco tempo."
                ),
            ]
        }

        return [
            BookingMessageSuggestion(
                text: "Para fechar hoje, posso ajustar para R$ X com \(lead.name) mantendo duração e entregas combinadas. Se aprovado, já reservamos a data.",
                why: "Mensagem orientada a fechamento com urgência saudável e clareza de contrapartida."
            ),
            BookingMessageSuggestion(
                text: "Consigo flexibilizar o formato para caber no budget sem perder impacto de pista. Posso te enviar a versão final para aprovação agora?",
                why: "Mantém percepção de valor enquanto cria caminho de concessão controlada."
            ),
        ]
    }

    static func coachingBrief(for negotiation: Negotiation, lead: EventLead?) -> NegotiationCoachingBrief {
        let probability = BookingRadarService.negotiationSignals([negotiation]).first?.probability ?? 20
        let now = Date()

        let desired = max(negotiation.desiredFee, 0)
        let offered = max(negotiation.offeredFee, 0)
        let baseDesired = desired > 0 ? desired : max(offered, 1200)
        let feeGap = max(baseDesired - offered, 0)

        let suggestedCounterOffer: Double
        if offered <= 0 {
            suggestedCounterOffer = baseDesired
        } else if offered >= baseDesired {
            suggestedCounterOffer = offered
        } else {
            suggestedCounterOffer = offered + (feeGap * 0.55)
        }

        let minimumAcceptable = baseDesired * 0.85
        let idealTarget = max(baseDesired, suggestedCounterOffer)

        var riskScore = 20
        var risks: [String] = []

        let overdueDays = Calendar.current.dateComponents([.day], from: negotiation.nextActionDate, to: now).day ?? 0
        if overdueDays >= 2 {
            riskScore += 30
            risks.append("follow-up atrasado")
        }

        if desired > 0 {
            let ratio = offered / desired
            if ratio < 0.75 {
                riskScore += 25
                risks.append("oferta muito abaixo do desejado")
            } else if ratio < 0.9 {
                riskScore += 12
                risks.append("gap moderado de fee")
            }
        }

        if negotiation.stage == LeadStatus.waitingReply.rawValue {
            riskScore += 10
            risks.append("dependência de retorno do promoter")
        }

        if let lead {
            let daysToEvent = Calendar.current.dateComponents([.day], from: now, to: lead.eventDate).day ?? 0
            if daysToEvent <= 4 {
                riskScore += 12
                risks.append("evento muito próximo")
            }
        }

        let cappedRisk = max(0, min(100, riskScore))
        let riskLevel: String
        if cappedRisk >= 65 {
            riskLevel = "Alto"
        } else if cappedRisk >= 40 {
            riskLevel = "Médio"
        } else {
            riskLevel = "Baixo"
        }

        let riskReason = risks.isEmpty ? "sem sinais críticos de risco" : risks.prefix(2).joined(separator: " + ")
        let counterText = Int(suggestedCounterOffer.rounded())
        let minimumText = Int(minimumAcceptable.rounded())
        let suggestedReply = "Para viabilizar essa data com segurança, consigo fechar em R$ \(counterText) no formato combinado. Abaixo de R$ \(minimumText), consigo apenas com ajustes de duração/estrutura."
        let rationale = "Valor sugerido equilibra fechamento e margem: aproxima da meta sem perder competitividade no contexto atual da negociação."

        return NegotiationCoachingBrief(
            closeProbability: probability,
            riskLevel: riskLevel,
            riskReason: riskReason,
            suggestedCounterOffer: suggestedCounterOffer,
            minimumAcceptable: minimumAcceptable,
            idealTarget: idealTarget,
            suggestedReply: suggestedReply,
            rationale: rationale
        )
    }
}