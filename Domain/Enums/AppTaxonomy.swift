import Foundation

enum ArtistStage: String, CaseIterable, Identifiable {
    case beginner = "Iniciante"
    case growing = "Em crescimento"
    case consolidating = "Consolidando"
    case touring = "Touring"

    var id: String { rawValue }
}

enum LeadStatus: String, CaseIterable, Identifiable {
    case notContacted = "Nao contactado"
    case messageSent = "Mensagem enviada"
    case waitingReply = "Aguardando resposta"
    case negotiating = "Negociacao"
    case closed = "Fechado"

    var id: String { rawValue }
}

enum TaskPriority: String, CaseIterable, Identifiable {
    case high = "Alta"
    case medium = "Media"
    case low = "Baixa"

    var id: String { rawValue }
}
