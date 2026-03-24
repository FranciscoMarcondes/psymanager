import Foundation

struct SocialContentDraft {
    let title: String
    let contentType: String
    let objective: String
    let pillar: String
    let hook: String
    let caption: String
    let cta: String
    let hashtags: [String]
}

enum SocialContentGenerator {
    static let supportedObjectives = ["Alcance", "Seguidores", "Booking"]
    static let supportedTypes = ["Reel", "Carrossel", "Stories"]

    static func generate(profile: ArtistProfile, objective: String, pillar: String, type: String) -> SocialContentDraft {
        let hook = hookFor(profile: profile, objective: objective, pillar: pillar)
        let cta = ctaFor(profile: profile, objective: objective)
        let caption = captionFor(profile: profile, objective: objective, pillar: pillar, type: type, hook: hook, cta: cta)
        let hashtags = hashtagsFor(profile: profile, objective: objective)
        let title = "\(type) • \(pillar)"

        return SocialContentDraft(
            title: title,
            contentType: type,
            objective: objective,
            pillar: pillar,
            hook: hook,
            caption: caption,
            cta: cta,
            hashtags: hashtags
        )
    }

    private static func hookFor(profile: ArtistProfile, objective: String, pillar: String) -> String {
        switch objective {
        case "Seguidores":
            return "Se você curte \(profile.genre.lowercased()) com identidade forte, esse momento aqui explica tudo."
        case "Booking":
            return "Esse recorte mostra exatamente o tipo de energia que \(profile.stageName) leva para a pista."
        default:
            return "Pouca gente viu o que aconteceu nesse momento de \(pillar.lowercased())."
        }
    }

    private static func ctaFor(profile: ArtistProfile, objective: String) -> String {
        switch objective {
        case "Seguidores":
            return "Segue o perfil para acompanhar os próximos cortes, datas e lançamentos de \(profile.stageName)."
        case "Booking":
            return "Se essa energia combina com sua pista, chama no direct para booking."
        default:
            return "Salva e compartilha com quem precisa sentir essa atmosfera."
        }
    }

    private static func captionFor(profile: ArtistProfile, objective: String, pillar: String, type: String, hook: String, cta: String) -> String {
        """
        \(hook)

        \(profile.stageName) constrói cada conteúdo com foco em \(profile.contentFocus.lowercased()), mantendo uma estética \(profile.visualIdentity.lowercased()) e uma presença \(profile.toneOfVoice.lowercased()). Nesta peça, o foco é \(pillar.lowercased()) para gerar \(objective.lowercased()).

        Formato: \(type). Contexto: \(profile.city), \(profile.state).

        \(cta)
        """
    }

    private static func hashtagsFor(profile: ArtistProfile, objective: String) -> [String] {
        var tags = ["#psytrance", "#djset", "#raveculture", "#electronicmusic", "#psymanager"]

        if objective == "Booking" {
            tags.append(contentsOf: ["#bookingdj", "#festivalbooking", "#lineupartist"])
        } else if objective == "Seguidores" {
            tags.append(contentsOf: ["#newmusicartist", "#undergroundscene", "#followthevibe"])
        } else {
            tags.append(contentsOf: ["#reelsmusic", "#viralreels", "#musicdiscovery"])
        }

        tags.append("#\(profile.city.replacingOccurrences(of: " ", with: ""))")
        return tags
    }
}