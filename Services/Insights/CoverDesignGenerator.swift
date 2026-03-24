import Foundation

struct ColorPalette {
    let primary: String // Hex color
    let secondary: String
    let accent: String
    let background: String
    let rationale: String
}

struct CoverComposition {
    let layout: String // "centered", "asymmetric", "grid", "diagonal"
    let mainElement: String // O que vai ser o destaque
    let supportingElements: [String]
    let tipography: String // Recomendação de fonte/estilo
    let safeZones: String // Áreas seguras para texto
}

struct CoverDesignRecommendation {
    let format: String // "Reel", "YouTube", "SoundCloud", "Instagram Story"
    let colorPalette: ColorPalette
    let composition: CoverComposition
    let visualMotifs: [String] // Elementos visuais sugeridos
    let sizingTips: String
    let designNotes: String
}

enum CoverDesignFormat: String, CaseIterable {
    case reel = "Reel"
    case youtube = "YouTube"
    case soundCloud = "SoundCloud"
    case instagramStory = "Instagram Story"
    case tiktok = "TikTok"
    case spotify = "Spotify"
    case appleBMusic = "Apple Music"
    case bandcamp = "Bandcamp"
    case discordServer = "Discord"
    case twitch = "Twitch"
    case twitchOverlay = "Twitch Overlay"
    case beatsport = "Beatsport"
    
    var dimensions: String {
        switch self {
        case .reel, .instagramStory, .tiktok:
            return "1080x1920px (vertical)"
        case .youtube:
            return "1280x720px (horizontal)"
        case .soundCloud, .spotify, .appleBMusic, .bandcamp, .beatsport:
            return "500x500px (quadrado)"
        case .discordServer:
            return "1024x512px (quadrado ou rect)"
        case .twitch:
            return "1280x720px (horizontal)"
        case .twitchOverlay:
            return "1920x1080px+ (overlay)"
        }
    }
    
    var dpi: String {
        switch self {
        case .youtube, .twitch, .twitchOverlay:
            return "72 DPI mínimo"
        case .spotify, .appleBMusic, .bandcamp, .beatsport, .soundCloud:
            return "300 DPI recomendado"
        default:
            return "72 DPI para web"
        }
    }
    
    var description: String {
        switch self {
        case .spotify:
            return "Capa de faixa no Spotify"
        case .appleBMusic:
            return "Artwork do Apple Music"
        case .bandcamp:
            return "Arte da faixa no Bandcamp"
        case .discordServer:
            return "Banner do servidor Discord"
        case .twitch:
            return "Thumbnail do stream Twitch"
        case .twitchOverlay:
            return "Overlay da câmera Twitch"
        case .beatsport:
            return "Arte no Beatsport"
        default:
            return self.rawValue
        }
    }
}

enum CoverDesignGenerator {
    
    static func generateForTrack(
        trackName: String,
        profile: ArtistProfile,
        format: CoverDesignFormat,
        mood: String = "energético"
    ) -> CoverDesignRecommendation {
        
        // Selecionar paleta baseada no gênero e mood do artista
        let palette = colorPaletteFor(genre: profile.genre, mood: mood)
        
        // Composição específica para o formato
        let composition = compositionFor(format: format, trackName: trackName)
        
        // Motivos visuais alinhados ao estilo do artista
        let motifs = visualMotifsFor(genre: profile.genre, city: profile.city)
        
        return CoverDesignRecommendation(
            format: format.rawValue,
            colorPalette: palette,
            composition: composition,
            visualMotifs: motifs,
            sizingTips: format.dimensions,
            designNotes: designNotesFor(format: format, profile: profile)
        )
    }
    
    private static func colorPaletteFor(genre: String, mood: String) -> ColorPalette {
        let genreLower = genre.lowercased()
        
        if genreLower.contains("psytrance") || genreLower.contains("progressive") {
            if mood.lowercased().contains("dark") || mood.lowercased().contains("escuro") {
                return ColorPalette(
                    primary: "#1a0033",
                    secondary: "#4d0080",
                    accent: "#ff00ff",
                    background: "#0d001a",
                    rationale: "Deep purples e magentas para psytrance dark, high contrast para psych"
                )
            } else {
                return ColorPalette(
                    primary: "#0d47a1",
                    secondary: "#1565c0",
                    accent: "#00bcd4",
                    background: "#001a33",
                    rationale: "Blues e cyans vibrantes para progressive, efeito de energia progressiva"
                )
            }
        } else if genreLower.contains("techno") {
            return ColorPalette(
                primary: "#000000",
                secondary: "#333333",
                accent: "#00ff00",
                background: "#0a0a0a",
                rationale: "Minimalismo techno com verde citrino para high energy"
            )
        } else {
            return ColorPalette(
                primary: "#ff6600",
                secondary: "#ff3300",
                accent: "#ffff00",
                background: "#330000",
                rationale: "Palette quente padrão para eletrônico"
            )
        }
    }
    
    private static func compositionFor(format: CoverDesignFormat, trackName: String) -> CoverComposition {
        switch format {
        case .reel, .instagramStory, .tiktok:
            return CoverComposition(
                layout: "asymmetric",
                mainElement: "Waveform diagonal ou logo em corner",
                supportingElements: ["Track name centralizado", "Artista em top", "Animated elements sugeridos"],
                tipography: "Sans-serif ousado: Futura, Montserrat Bold em branco/contraste",
                safeZones: "Evitar borda 60px de todos os lados para UI do app"
            )
        case .youtube, .twitch:
            return CoverComposition(
                layout: "centered",
                mainElement: "Performance photo do artista ou visual abstrato grande",
                supportingElements: ["Track name topo center", "Sub-info rodapé"],
                tipography: "Títulos grandes (48pt+), legível em thumbnail",
                safeZones: "Área central 160x90 é o foco (aparece em thumbnail)"
            )
        case .twitchOverlay:
            return CoverComposition(
                layout: "asymmetric",
                mainElement: "Franja lateral com artista + waveform animado",
                supportingElements: ["Track name em sobreposição", "BPM e energia visual"],
                tipography: "Fontes ousadas com sombra para legibilidade",
                safeZones: "Deixar centro livre para game/câmera"
            )
        case .soundCloud, .spotify, .appleBMusic, .bandcamp, .beatsport:
            return CoverComposition(
                layout: "centered",
                mainElement: "Simétrico, quadrado perfeito",
                supportingElements: ["Track name e artista centrados"],
                tipography: "Limitado a 2 linhas máximo, fonte pequena mas legível",
                safeZones: "Margem mínima 20px de todos os lados"
            )
        case .discordServer:
            return CoverComposition(
                layout: "centered",
                mainElement: "Arte retangular com elementos do DJ verticalmente distribuídos",
                supportingElements: ["Logo do servidor esquerda", "Nome do servidor direita"],
                tipography: "Moderado, Discord mostra em 480px width",
                safeZones: "Margem 30px, evitar bolinhas de avatar indo sobrepor"
            )
        }
    }
    
    private static func visualMotifsFor(genre: String, city: String) -> [String] {
        var motifs: [String] = []
        
        let genreLower = genre.lowercased()
        if genreLower.contains("psytrance") {
            motifs = [
                "Fractais psicadélicos sutis",
                "Waveforms distorcidas",
                "Símbolos geométricos",
                "Glitch effects discretos"
            ]
        } else if genreLower.contains("techno") {
            motifs = [
                "Grid de linhas",
                "Números binários",
                "Circuitos abstratos",
                "Picos de frequência"
            ]
        } else {
            motifs = [
                "Elementos abstratos fluidos",
                "Cores em degradê",
                "Formas orgânicas"
            ]
        }
        
        // Adicionar referência geográfica
        if !city.isEmpty {
            motifs.append("Referência sutil a \(city): skyline ou símbolo local")
        }
        
        return motifs
    }
    
    private static func designNotesFor(format: CoverDesignFormat, profile: ArtistProfile) -> String {
        switch format {
        case .reel, .instagramStory, .tiktok:
            return "Optimize for mobile vertical viewing. Text deve ser legível em 2 segundos. Considere animação ou elementos dinâmicos para scroll feed."
        case .youtube, .twitch:
            return "Será visto em 298x168px como thumbnail. Certifique-se de que elementos chave são reconhecíveis nesse tamanho pequeno."
        case .twitchOverlay:
            return "Aparecerá sobre gameplay. Use transparência alfa. Bordas têm maior impacto visual. Teste com seu setup de stream."
        case .spotify:
            return "Aparecerá em 300x300 em desktop. SoundCard do artista será vista em context listening. Evite texto pequeno. Brand consistency com playlist arte."
        case .appleBMusic:
            return "Apple Music respeita o artwork enviado sem modificações. Qualidade é crítica - mínimo 1500x1500px com 72 DPI. Evite fontes finas."
        case .bandcamp:
            return "Bandcamp exibe em quadrado, alta resolução. Artistas indie preferem arte única e identitária. Considere efeitos de profundidade."
        case .soundCloud:
            return "Pequeno em feed. Evite muitos detalhes. Cores vibrantes são essenciais para chamar atenção. Logo SoundCloud aparecerá sobreposto."
        case .discordServer:
            return "Será visto redimensionado. Mantenha cor consistente com tema do servidor. Texto deve ser legível em 480px width mínimo."
        case .beatsport:
            return "Plataforma de DJs profissionais. Qualidade de imagem e profissionalismo são críticos. Evite clipart genérico."
        }
    }
}
