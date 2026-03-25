import Foundation

struct AIWorkspaceSnapshot {
    let leads: Int
    let gigs: Int
    let contentIdeas: Int
    let radarEvents: Int
}

enum ArtistAIContextBuilder {
    static func profileSummary(_ profile: ArtistProfile?) -> String {
        guard let profile else {
            return "Perfil do artista ainda não configurado por completo."
        }

        return """
        nome: \(profile.stageName)
        genero: \(profile.genre)
        cidade: \(profile.city)-\(profile.state)
        fase: \(profile.artistStage)
        objetivo principal: \(profile.mainGoal)
        tom de voz: \(profile.toneOfVoice)
        foco de conteudo: \(profile.contentFocus)
        identidade visual: \(profile.visualIdentity)
        instagram: \(profile.instagramHandle)
        spotify: \(profile.spotifyHandle)
        youtube: \(profile.youTubeHandle)
        soundcloud: \(profile.soundCloudHandle)
        """
    }

    static func factsSummary(_ facts: [String]) -> String {
        guard !facts.isEmpty else {
            return "Nenhum fato persistido ainda."
        }
        return facts.map { "- \($0)" }.joined(separator: "\n")
    }

    static func snapshotSummary(_ snapshot: AIWorkspaceSnapshot) -> String {
        """
        leads ativos: \(snapshot.leads)
        gigs confirmadas: \(snapshot.gigs)
        ideias/conteudos no plano: \(snapshot.contentIdeas)
        eventos no radar: \(snapshot.radarEvents)
        """
    }

    static func unifiedPrompt(
        request: String,
        profile: ArtistProfile?,
        facts: [String] = [],
        snapshot: AIWorkspaceSnapshot? = nil,
        guidance: String
    ) -> String {
        let snapshotText = snapshot.map(snapshotSummary) ?? "Sem snapshot operacional disponível."

        return """
        Contexto do artista:
        \(profileSummary(profile))

        Fatos aprendidos:
        \(factsSummary(facts))

        Snapshot operacional:
        \(snapshotText)

        Pedido do usuário:
        \(request)

        Instruções de resposta:
        \(guidance)
        """
    }
}