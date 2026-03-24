import Foundation

struct MockCareerManagerService: TextAIProvider {
    func generate(request: TextAIRequest) async throws -> String {
        let mockProfile = ArtistProfile(
            stageName: "Artista",
            genre: "Psytrance",
            city: "Cidade",
            state: "UF",
            artistStage: "Em crescimento",
            toneOfVoice: "Confiante",
            mainGoal: "Fechar gigs",
            contentFocus: "Reels",
            visualIdentity: "Psicodélica"
        )
        return respond(to: request.prompt, profile: mockProfile)
    }

    func respond(to prompt: String, profile: ArtistProfile) -> String {
        let lowerPrompt = prompt.lowercased()

        if lowerPrompt.contains("booking") || lowerPrompt.contains("promoter") {
            return "Para \(profile.stageName), eu focaria em uma abordagem curta, segura e personalizada. Abra conectando sua identidade \(profile.visualIdentity.lowercased()), cite o encaixe com o evento e feche com CTA simples: disponibilidade, press kit e set direcionado para a pista. Depois programe follow-up em 72h."
        }

        if lowerPrompt.contains("bio") {
            return "\(profile.stageName) e um projeto de \(profile.genre.lowercased()) baseado em \(profile.city), com assinatura \(profile.toneOfVoice.lowercased()) e direcao visual \(profile.visualIdentity.lowercased()). A proposta artistica combina imersao, impacto de pista e narrativa psicodelica contemporanea."
        }

        if lowerPrompt.contains("reel") || lowerPrompt.contains("conteudo") || lowerPrompt.contains("post") {
            return "Plano rapido de conteudo: 1) reel com hook forte dos bastidores, 2) corte de performance com legenda curta e magnetica, 3) post carrossel explicando sua identidade sonora. Mantenha foco em \(profile.contentFocus.lowercased()) e termine cada peca com CTA de conexao ou booking."
        }

        if lowerPrompt.contains("semana") || lowerPrompt.contains("estrategia") {
            return "Sua estrategia da semana: segunda para prospeccao, quarta para conteudo, sexta para relacionamento e domingo para planejamento. Objetivo central atual: \(profile.mainGoal.lowercased()). Prioridade numero um: gerar mais conversas qualificadas com promoters."
        }

        return "Como manager virtual, minha leitura e: voce precisa alinhar posicionamento, consistencia de conteudo e funil de booking. Para \(profile.stageName), o proximo melhor passo e transformar sua meta de \(profile.mainGoal.lowercased()) em rotina semanal com prospeccao, criacao e follow-up medidos."
    }
}
