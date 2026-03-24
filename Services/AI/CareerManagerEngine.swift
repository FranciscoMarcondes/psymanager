import Foundation

struct CareerManagerEngine {
    private let provider: TextAIProvider?
    private let fallback = MockCareerManagerService()

    init(provider: TextAIProvider? = nil) {
        if let provider {
            self.provider = provider
            return
        }

        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty {
            self.provider = OpenAITextProvider(apiKey: key)
        } else {
            self.provider = nil
        }
    }

    func ask(prompt: String, profile: ArtistProfile) async -> String {
        let summary = """
        nome: \(profile.stageName)
        genero: \(profile.genre)
        cidade: \(profile.city)-\(profile.state)
        fase: \(profile.artistStage)
        objetivo: \(profile.mainGoal)
        tom: \(profile.toneOfVoice)
        visual: \(profile.visualIdentity)
        foco conteudo: \(profile.contentFocus)
        """

        do {
            if let provider {
                return try await provider.generate(request: TextAIRequest(prompt: prompt, profileSummary: summary))
            }
            return fallback.respond(to: prompt, profile: profile)
        } catch {
            return fallback.respond(to: prompt, profile: profile)
        }
    }
}
