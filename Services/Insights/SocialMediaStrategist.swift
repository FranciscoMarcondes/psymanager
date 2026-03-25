import Foundation
import Security

struct SocialMediaDiagnostic {
    let headline: String
    let summary: String
    let signalLabel: String
    let signalColorName: String
}

struct SocialMediaContentPillar: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let recommendedFormat: String
}

struct SocialMediaWeeklyActionDraft: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let dueDate: Date
    let priority: String
}

struct SocialMediaHookIdea: Identifiable {
    let id = UUID()
    let title: String
    let example: String
}

struct SocialMediaStrategyReport {
    let diagnostic: SocialMediaDiagnostic
    let pillars: [SocialMediaContentPillar]
    let weeklyPlan: [SocialMediaWeeklyActionDraft]
    let hooks: [SocialMediaHookIdea]
    let postingGuidance: [String]
    let ctas: [String]
}

enum SocialMediaStrategist {
    static func buildReport(profile: ArtistProfile, snapshots: [SocialInsightSnapshot]) -> SocialMediaStrategyReport {
        let sortedSnapshots = snapshots.sorted(by: { $0.periodEnd > $1.periodEnd })
        let latest = sortedSnapshots.first
        let growth = latest.map { $0.followersEnd - $0.followersStart } ?? 0
        let reachPerPost = latest.map { $0.postsPublished > 0 ? $0.reach / $0.postsPublished : 0 } ?? 0
        let reelViews = latest?.reelViews ?? 0
        let profileVisits = latest?.profileVisits ?? 0

        let diagnostic = makeDiagnostic(profile: profile, growth: growth, reachPerPost: reachPerPost, reelViews: reelViews, profileVisits: profileVisits, hasSnapshot: latest != nil)
        let pillars = makePillars(profile: profile, growth: growth)
        let weeklyPlan = makeWeeklyPlan(profile: profile, growth: growth, reachPerPost: reachPerPost)
        let hooks = makeHooks(profile: profile)
        let postingGuidance = makePostingGuidance(profile: profile, growth: growth, reachPerPost: reachPerPost)
        let ctas = makeCTAs(profile: profile)

        return SocialMediaStrategyReport(
            diagnostic: diagnostic,
            pillars: pillars,
            weeklyPlan: weeklyPlan,
            hooks: hooks,
            postingGuidance: postingGuidance,
            ctas: ctas
        )
    }

    private static func makeDiagnostic(profile: ArtistProfile, growth: Int, reachPerPost: Int, reelViews: Int, profileVisits: Int, hasSnapshot: Bool) -> SocialMediaDiagnostic {
        guard hasSnapshot else {
            return SocialMediaDiagnostic(
                headline: "Base social pronta para acelerar",
                summary: "Seu posicionamento ja existe, mas falta telemetria. Comece registrando uma semana de resultados para o app calibrar frequência, formatos e CTA com mais precisão.",
                signalLabel: "Sem baseline",
                signalColorName: "warning"
            )
        }

        if growth >= 50 && reachPerPost >= 1800 {
            return SocialMediaDiagnostic(
                headline: "Momento de escala orgânica",
                summary: "Seu perfil esta ganhando tracao. O foco agora e dobrar os formatos que puxam descoberta e converter alcance em seguidores e contatos de booking.",
                signalLabel: "Escalar agora",
                signalColorName: "positive"
            )
        }

        if growth <= 10 || reachPerPost < 1200 {
            return SocialMediaDiagnostic(
                headline: "Conteudo precisa de recalibragem",
                summary: "O alcance por peça ou o ganho de seguidores ainda esta abaixo do ideal. O melhor caminho e reforcar Reels curtos, series recorrentes e CTA mais claros de seguir, salvar e compartilhar.",
                signalLabel: "Corrigir rápido",
                signalColorName: "warning"
            )
        }

        if reelViews > profileVisits * 6 {
            return SocialMediaDiagnostic(
                headline: "Descoberta boa, conversão mediana",
                summary: "Os Reels estao trazendo consumo, mas parte da audiência ainda nao esta migrando para o perfil. Trabalhe gancho visual, bio e CTA de follow com mais agressividade.",
                signalLabel: "Converter melhor",
                signalColorName: "accent"
            )
        }

        return SocialMediaDiagnostic(
            headline: "Base consistente para crescer",
            summary: "Seu social esta funcional. O ganho adicional vem de consistência editorial, formatos em serie e um funil mais forte entre conteudo, profile visit e booking.",
            signalLabel: "Otimizar",
            signalColorName: "primary"
        )
    }

    private static func makePillars(profile: ArtistProfile, growth: Int) -> [SocialMediaContentPillar] {
        [
            SocialMediaContentPillar(
                title: "Autoridade de pista",
                description: "Mostre leitura de crowd, transições, drop e energia do seu set para provar impacto real ao mercado.",
                recommendedFormat: "Reels de 12-20s"
            ),
            SocialMediaContentPillar(
                title: "Universo do artista",
                description: "Transforme \(profile.visualIdentity.lowercased()) em assinatura visual recorrente para fixar memoria e reconhecimento.",
                recommendedFormat: "Carrossel + Stories"
            ),
            SocialMediaContentPillar(
                title: "Processo criativo",
                description: "Leve o público para dentro da construçao musical, bastidores e decisão estética do projeto.",
                recommendedFormat: "Bastidor vertical"
            ),
            SocialMediaContentPillar(
                title: "Prova social",
                description: "Use crowd reaction, feedbacks, lineups e cortes de promoters para sustentar desejo de booking.",
                recommendedFormat: "Recortes com legenda forte"
            ),
        ]
    }

    private static func makeWeeklyPlan(profile: ArtistProfile, growth: Int, reachPerPost: Int) -> [SocialMediaWeeklyActionDraft] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())

        let frequencyDetail = growth < 20 ? "Suba 3 Reels e 1 carrossel para recuperar descoberta." : "Mantenha 2 Reels fortes e 1 prova social para escalar o que ja funciona."
        let conversionDetail = reachPerPost < 1200 ? "Regrave a abertura com hook mais rápido e CTA de seguir nos 3 primeiros segundos." : "Aproveite o alcance atual para empurrar visita ao perfil e pedido de orçamento."

        return [
            SocialMediaWeeklyActionDraft(
                title: "Planejar pauta da semana",
                detail: "Defina 4 peças alinhadas a \(profile.contentFocus.lowercased()). \(frequencyDetail)",
                dueDate: start,
                priority: TaskPriority.high.rawValue
            ),
            SocialMediaWeeklyActionDraft(
                title: "Produzir Reel de autoridade",
                detail: "Edite um corte de pista com ganho de tensão, reação do público e CTA de booking no fechamento.",
                dueDate: calendar.date(byAdding: .day, value: 1, to: start) ?? start,
                priority: TaskPriority.high.rawValue
            ),
            SocialMediaWeeklyActionDraft(
                title: "Publicar prova social",
                detail: "Suba carrossel ou recorte com lineup, crowd ou depoimento. \(conversionDetail)",
                dueDate: calendar.date(byAdding: .day, value: 3, to: start) ?? start,
                priority: TaskPriority.medium.rawValue
            ),
            SocialMediaWeeklyActionDraft(
                title: "Revisar métricas e retenção",
                detail: "Compare seguidores, alcance, visitas ao perfil e salvamentos para decidir o formato da próxima semana.",
                dueDate: calendar.date(byAdding: .day, value: 6, to: start) ?? start,
                priority: TaskPriority.medium.rawValue
            ),
        ]
    }

    private static func makeHooks(profile: ArtistProfile) -> [SocialMediaHookIdea] {
        [
            SocialMediaHookIdea(
                title: "Hook de tensão",
                example: "Essa virada destruiu a pista em \(profile.city) e quase ninguém viu esse momento inteiro."
            ),
            SocialMediaHookIdea(
                title: "Hook de identidade",
                example: "Se \(profile.stageName) tivesse que ser resumido em 15 segundos, seria isso aqui."
            ),
            SocialMediaHookIdea(
                title: "Hook de bastidor",
                example: "O que acontece antes do drop perfeito não aparece no palco, mas muda tudo."
            ),
        ]
    }

    private static func makePostingGuidance(profile: ArtistProfile, growth: Int, reachPerPost: Int) -> [String] {
        let firstWindow = growth < 20 ? "Priorize 19h-22h com post principal em dia util e reforço em stories 30 minutos depois." : "Teste janela de pico 18h-21h e recorte curto nas stories logo após o Reel principal."
        let secondWindow = reachPerPost < 1200 ? "Evite abrir vídeo com logo ou intro lenta; o primeiro segundo precisa entregar tensão visual ou crowd reaction." : "Repita a estrutura visual dos conteúdos que mais puxaram alcance e só altere o tema narrativo."

        return [
            firstWindow,
            secondWindow,
            "Sempre publique stories de sustentação no mesmo dia: teaser antes, prova social depois, CTA de follow ou booking no fechamento.",
            "Amarre cada peça a um objetivo único: descoberta, relacionamento ou conversão. Não misture tudo no mesmo post.",
            "Para psytrance, privilegie cor, movimento, crowd e sensação de viagem. Conteúdo excessivamente estático tende a perder retenção.",
        ]
    }

    private static func makeCTAs(profile: ArtistProfile) -> [String] {
        [
            "Segue o perfil para acompanhar os próximos drops e datas de \(profile.stageName).",
            "Se esse clima combina com sua pista, chama no direct para booking.",
            "Salva esse vídeo para lembrar da energia e compartilhar com seu crew.",
            "Responde nos comentários qual cidade precisa receber esse set.",
        ]
    }
}

protocol PlatformInsightAdapter {
    func fetchInsights(handle: String) async -> PlatformInsightFetch
}

struct PlatformInsightFetch {
    let insight: PlatformInsight
    let isLive: Bool
    let errorDetail: String?
}

enum PlatformAPISecrets {
    static func migrateLegacyUserDefaultsSecrets() {
        KeychainSecretStore.migrateFromUserDefaults(
            keychainKey: KeychainSecretStore.spotifyTokenKey,
            defaultsKey: "psy.spotify.token"
        )
        KeychainSecretStore.migrateFromUserDefaults(
            keychainKey: KeychainSecretStore.youtubeAPIKey,
            defaultsKey: "psy.youtube.apiKey"
        )
        KeychainSecretStore.migrateFromUserDefaults(
            keychainKey: KeychainSecretStore.soundCloudClientIdKey,
            defaultsKey: "psy.soundcloud.clientId"
        )
        KeychainSecretStore.migrateFromUserDefaults(
            keychainKey: KeychainSecretStore.googleMapsAPIKey,
            defaultsKey: "psy.logistics.googleMapsApiKey"
        )
        KeychainSecretStore.migrateFromUserDefaults(
            keychainKey: KeychainSecretStore.rapidAPIKey,
            defaultsKey: "psy.logistics.rapidApiKey"
        )
        KeychainSecretStore.migrateFromUserDefaults(
            keychainKey: KeychainSecretStore.skyscannerAPIKey,
            defaultsKey: "psy.logistics.skyscannerApiKey"
        )
        KeychainSecretStore.migrateFromUserDefaults(
            keychainKey: KeychainSecretStore.kiwiTequilaAPIKey,
            defaultsKey: "psy.logistics.kiwiTequilaApiKey"
        )
        KeychainSecretStore.migrateFromUserDefaults(
            keychainKey: KeychainSecretStore.webSyncAuthHeaderKey,
            defaultsKey: "psy.web.authHeader"
        )
    }

    static var spotifyToken: String? {
        KeychainSecretStore.read(KeychainSecretStore.spotifyTokenKey)
    }

    static var youtubeAPIKey: String? {
        KeychainSecretStore.read(KeychainSecretStore.youtubeAPIKey)
    }

    static var soundCloudClientId: String? {
        KeychainSecretStore.read(KeychainSecretStore.soundCloudClientIdKey)
    }

    static var googleMapsAPIKey: String? {
        KeychainSecretStore.read(KeychainSecretStore.googleMapsAPIKey)
    }

    static var rapidAPIKey: String? {
        KeychainSecretStore.read(KeychainSecretStore.rapidAPIKey)
    }

    static var skyscannerAPIKey: String? {
        KeychainSecretStore.read(KeychainSecretStore.skyscannerAPIKey)
    }

    static var kiwiTequilaAPIKey: String? {
        KeychainSecretStore.read(KeychainSecretStore.kiwiTequilaAPIKey)
    }

    static var webSyncAuthHeader: String? {
        KeychainSecretStore.read(KeychainSecretStore.webSyncAuthHeaderKey)
    }

    static var authUserEmail: String? {
        KeychainSecretStore.read(KeychainSecretStore.authUserEmailKey)
    }

    static var authUserName: String? {
        KeychainSecretStore.read(KeychainSecretStore.authUserNameKey)
    }
}

enum KeychainSecretStore {
    static let service = "com.franciscomarcondes.psymanager"
    static let spotifyTokenKey = "psy.spotify.token"
    static let youtubeAPIKey = "psy.youtube.apiKey"
    static let soundCloudClientIdKey = "psy.soundcloud.clientId"
    static let googleMapsAPIKey = "psy.logistics.googleMapsApiKey"
    static let rapidAPIKey = "psy.logistics.rapidApiKey"
    static let skyscannerAPIKey = "psy.logistics.skyscannerApiKey"
    static let kiwiTequilaAPIKey = "psy.logistics.kiwiTequilaApiKey"
    static let webSyncAuthHeaderKey = "psy.web.authHeader"
    static let authUserEmailKey = "psy.auth.userEmail"
    static let authUserNameKey = "psy.auth.userName"

    static func read(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else { return nil }
        return value
    }

    static func write(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func delete(_ account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static func migrateFromUserDefaults(keychainKey: String, defaultsKey: String) {
        let defaults = UserDefaults.standard
        guard let existing = defaults.string(forKey: defaultsKey), !existing.isEmpty else { return }
        if read(keychainKey) == nil {
            write(existing, account: keychainKey)
        }
        defaults.removeObject(forKey: defaultsKey)
    }
}

enum PlatformHandleResolver {
    static func normalizedHandles(for profile: ArtistProfile) -> [String: String] {
        func sanitize(_ value: String?) -> String {
            (value ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "@", with: "")
                .lowercased()
        }

        let fallback = sanitize(profile.stageName)

        return [
            "Instagram": sanitize(profile.instagramHandle).isEmpty ? fallback : sanitize(profile.instagramHandle),
            "Spotify": sanitize(profile.spotifyHandle).isEmpty ? fallback : sanitize(profile.spotifyHandle),
            "SoundCloud": sanitize(profile.soundCloudHandle).isEmpty ? fallback : sanitize(profile.soundCloudHandle),
            "YouTube": sanitize(profile.youTubeHandle).isEmpty ? fallback : sanitize(profile.youTubeHandle),
            "Apple Music": fallback,
            "BeatPort": fallback,
        ]
    }
}

struct InstagramAdapter: PlatformInsightAdapter {
    func fetchInsights(handle: String) async -> PlatformInsightFetch {
        PlatformInsightFetch(insight: PlatformInsight(
            platform: "Instagram",
            followers: 1218,
            reach: 7400,
            impressions: 11300,
            likes: 287 + 156 + 421,
            comments: 34 + 18 + 52,
            shares: 12 + 8 + 28,
            saves: 45 + 22 + 67,
            profileViews: 560,
            trackCount: 24,
            platformProfileUrl: "https://instagram.com/\(handle)"
        ), isLive: false, errorDetail: nil)
    }
}

struct SpotifyAdapter: PlatformInsightAdapter {
    func fetchInsights(handle: String) async -> PlatformInsightFetch {
        if let token = PlatformAPISecrets.spotifyToken, !token.isEmpty {
            let liveResult = await fetchLiveSpotifyInsight(handle: handle, token: token)
            if let liveInsight = liveResult.insight {
                return PlatformInsightFetch(insight: liveInsight, isLive: true, errorDetail: nil)
            }

            return PlatformInsightFetch(insight: PlatformInsight(
                platform: "Spotify",
                followers: 3400,
                streams: 87500,
                trackCount: 8,
                totalMinutesStreamed: 125000,
                topCountries: "Brazil,Germany,Portugal",
                monthlyListeners: 2150,
                playlistInclusions: 47,
                platformProfileUrl: "https://open.spotify.com/artist/\(handle)"
            ), isLive: false, errorDetail: liveResult.errorDetail ?? "Falha desconhecida no endpoint Spotify")
        }

        return PlatformInsightFetch(insight: PlatformInsight(
            platform: "Spotify",
            followers: 3400,
            streams: 87500,
            trackCount: 8,
            totalMinutesStreamed: 125000,
            topCountries: "Brazil,Germany,Portugal",
            monthlyListeners: 2150,
            playlistInclusions: 47,
            platformProfileUrl: "https://open.spotify.com/artist/\(handle)"
        ), isLive: false, errorDetail: nil)
    }

    private func fetchLiveSpotifyInsight(handle: String, token: String) async -> (insight: PlatformInsight?, errorDetail: String?) {
        let query = "artist:\(handle)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? handle
        guard let url = URL(string: "https://api.spotify.com/v1/search?type=artist&limit=1&q=\(query)") else {
            return (nil, "URL inválida para Spotify")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return (nil, "Resposta inválida do Spotify")
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                return (nil, "Spotify HTTP \(http.statusCode)")
            }
            guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let artists = payload["artists"] as? [String: Any],
                  let items = artists["items"] as? [[String: Any]],
                  let artist = items.first
            else {
                return (nil, "Spotify sem artista para esse handle")
            }

            let followersDict = artist["followers"] as? [String: Any]
            let followers = followersDict?["total"] as? Int ?? 0
            let profileURL = ((artist["external_urls"] as? [String: Any])?["spotify"] as? String) ?? "https://open.spotify.com/search/\(handle)"

            return (
                PlatformInsight(
                    platform: "Spotify",
                    followers: followers,
                    trackCount: 0,
                    platformProfileUrl: profileURL
                ),
                nil
            )
        } catch {
            return (nil, "Spotify network error: \(error.localizedDescription)")
        }
    }
}

struct SoundCloudAdapter: PlatformInsightAdapter {
    func fetchInsights(handle: String) async -> PlatformInsightFetch {
        if let clientId = PlatformAPISecrets.soundCloudClientId, !clientId.isEmpty {
            let liveResult = await fetchLiveSoundCloudInsight(handle: handle, clientId: clientId)
            if let liveInsight = liveResult.insight {
                return PlatformInsightFetch(insight: liveInsight, isLive: true, errorDetail: nil)
            }

            return PlatformInsightFetch(insight: PlatformInsight(
                platform: "SoundCloud",
                followers: 845,
                streams: 34200,
                likes: 320,
                comments: 89,
                shares: 45,
                trackCount: 12,
                totalMinutesStreamed: 45000,
                platformProfileUrl: "https://soundcloud.com/\(handle)"
            ), isLive: false, errorDetail: liveResult.errorDetail ?? "Falha desconhecida no endpoint SoundCloud")
        }

        return PlatformInsightFetch(insight: PlatformInsight(
            platform: "SoundCloud",
            followers: 845,
            streams: 34200,
            likes: 320,
            comments: 89,
            shares: 45,
            trackCount: 12,
            totalMinutesStreamed: 45000,
            platformProfileUrl: "https://soundcloud.com/\(handle)"
        ), isLive: false, errorDetail: nil)
    }

    private func fetchLiveSoundCloudInsight(handle: String, clientId: String) async -> (insight: PlatformInsight?, errorDetail: String?) {
        let encodedProfileURL = "https://soundcloud.com/\(handle)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "https://soundcloud.com/\(handle)"
        guard let url = URL(string: "https://api-v2.soundcloud.com/resolve?url=\(encodedProfileURL)&client_id=\(clientId)") else {
            return (nil, "URL inválida para SoundCloud")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                return (nil, "Resposta inválida do SoundCloud")
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                return (nil, "SoundCloud HTTP \(http.statusCode)")
            }
            guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return (nil, "Payload inválido do SoundCloud")
            }

            let followers = payload["followers_count"] as? Int ?? 0
            let trackCount = payload["track_count"] as? Int ?? 0
            let permalinkURL = payload["permalink_url"] as? String ?? "https://soundcloud.com/\(handle)"

            return (
                PlatformInsight(
                    platform: "SoundCloud",
                    followers: followers,
                    trackCount: trackCount,
                    platformProfileUrl: permalinkURL
                ),
                nil
            )
        } catch {
            return (nil, "SoundCloud network error: \(error.localizedDescription)")
        }
    }
}

struct YouTubeAdapter: PlatformInsightAdapter {
    func fetchInsights(handle: String) async -> PlatformInsightFetch {
        if let apiKey = PlatformAPISecrets.youtubeAPIKey, !apiKey.isEmpty {
            let liveResult = await fetchLiveYouTubeInsight(handle: handle, apiKey: apiKey)
            if let liveInsight = liveResult.insight {
                return PlatformInsightFetch(insight: liveInsight, isLive: true, errorDetail: nil)
            }

            return PlatformInsightFetch(insight: PlatformInsight(
                platform: "YouTube",
                followers: 2340,
                impressions: 145000,
                streams: 567000,
                likes: 12500,
                comments: 2340,
                trackCount: 156,
                totalMinutesStreamed: 450000,
                platformProfileUrl: "https://youtube.com/@\(handle)"
            ), isLive: false, errorDetail: liveResult.errorDetail ?? "Falha desconhecida no endpoint YouTube")
        }

        return PlatformInsightFetch(insight: PlatformInsight(
            platform: "YouTube",
            followers: 2340,
            impressions: 145000,
            streams: 567000,
            likes: 12500,
            comments: 2340,
            trackCount: 156,
            totalMinutesStreamed: 450000,
            platformProfileUrl: "https://youtube.com/@\(handle)"
        ), isLive: false, errorDetail: nil)
    }

    private func fetchLiveYouTubeInsight(handle: String, apiKey: String) async -> (insight: PlatformInsight?, errorDetail: String?) {
        let encodedHandle = handle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? handle
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/channels?part=statistics,snippet&forHandle=\(encodedHandle)&key=\(apiKey)") else {
            return (nil, "URL inválida para YouTube")
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else {
                return (nil, "Resposta inválida do YouTube")
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                return (nil, "YouTube HTTP \(http.statusCode)")
            }
            guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = payload["items"] as? [[String: Any]],
                  let channel = items.first,
                  let statistics = channel["statistics"] as? [String: Any]
            else {
                return (nil, "YouTube sem canal para esse handle")
            }

            let subscribers = Int(statistics["subscriberCount"] as? String ?? "0") ?? 0
            let views = Int(statistics["viewCount"] as? String ?? "0") ?? 0
            let videos = Int(statistics["videoCount"] as? String ?? "0") ?? 0

            return (
                PlatformInsight(
                    platform: "YouTube",
                    followers: subscribers,
                    streams: views,
                    trackCount: videos,
                    platformProfileUrl: "https://youtube.com/@\(handle)"
                ),
                nil
            )
        } catch {
            return (nil, "YouTube network error: \(error.localizedDescription)")
        }
    }
}

struct AppleMusicAdapter: PlatformInsightAdapter {
    func fetchInsights(handle: String) async -> PlatformInsightFetch {
        PlatformInsightFetch(insight: PlatformInsight(
            platform: "Apple Music",
            followers: 1200,
            streams: 45000,
            trackCount: 8,
            totalMinutesStreamed: 67500,
            monthlyListeners: 890,
            playlistInclusions: 23,
            platformProfileUrl: "https://music.apple.com/artist/\(handle)"
        ), isLive: false, errorDetail: nil)
    }
}

struct BeatPortAdapter: PlatformInsightAdapter {
    func fetchInsights(handle: String) async -> PlatformInsightFetch {
        PlatformInsightFetch(insight: PlatformInsight(
            platform: "BeatPort",
            followers: 450,
            streams: 12500,
            trackCount: 5,
            platformProfileUrl: "https://www.beatport.com/artist/\(handle)"
        ), isLive: false, errorDetail: nil)
    }
}

enum CareerInsightAggregator {
    static func fetchAllPlatformInsightsDetailed(profile: ArtistProfile) async -> [PlatformInsightFetch] {
        let handles = PlatformHandleResolver.normalizedHandles(for: profile)

        return [
            await InstagramAdapter().fetchInsights(handle: handles["Instagram"] ?? ""),
            await SpotifyAdapter().fetchInsights(handle: handles["Spotify"] ?? ""),
            await SoundCloudAdapter().fetchInsights(handle: handles["SoundCloud"] ?? ""),
            await YouTubeAdapter().fetchInsights(handle: handles["YouTube"] ?? ""),
            await AppleMusicAdapter().fetchInsights(handle: handles["Apple Music"] ?? ""),
            await BeatPortAdapter().fetchInsights(handle: handles["BeatPort"] ?? ""),
        ]
    }

    static func fetchAllPlatformInsights(profile: ArtistProfile) async -> [PlatformInsight] {
        let details = await fetchAllPlatformInsightsDetailed(profile: profile)
        return details.map { $0.insight }
    }

    static func buildCareerSnapshot(from platformInsights: [PlatformInsight]) -> ArtistCareerSnapshot {
        var totalFollowers = 0
        var totalReach = 0
        var totalImpressions = 0
        var totalStreams = 0
        var totalListenerMinutes = 0
        var totalTracks = 0
        var totalLikes = 0
        var totalComments = 0
        var totalShares = 0

        var platformBreakdown: [String: [String: Any]] = [:]
        var dominantPlatform = "Unknown"
        var maxFollowers = 0

        for insight in platformInsights {
            totalFollowers += insight.followers
            totalReach += insight.reach
            totalImpressions += insight.impressions
            totalStreams += (insight.streams ?? 0)
            totalListenerMinutes += (insight.totalMinutesStreamed ?? 0)
            totalTracks += (insight.trackCount ?? 0)
            totalLikes += insight.likes
            totalComments += insight.comments
            totalShares += insight.shares

            if insight.followers > maxFollowers {
                maxFollowers = insight.followers
                dominantPlatform = insight.platform
            }

            platformBreakdown[insight.platform] = [
                "followers": insight.followers,
                "reach": insight.reach,
                "streams": insight.streams ?? 0,
                "url": insight.platformProfileUrl ?? "",
            ]
        }

        let engagementRate = totalImpressions > 0
            ? Double(totalLikes + totalComments + totalShares) / Double(totalImpressions) * 100
            : 0

        let careerStage = determineCareerStage(followers: totalFollowers)
        let nextMilestones = generateMilestones(followers: totalFollowers)
        let areasOfFocus = generateFocusAreas(insights: platformInsights, dominantPlatform: dominantPlatform)

        let breakdownJSON: String = {
            guard let data = try? JSONSerialization.data(withJSONObject: platformBreakdown, options: .prettyPrinted),
                  let json = String(data: data, encoding: .utf8)
            else { return "{}" }
            return json
        }()

        return ArtistCareerSnapshot(
            totalFollowers: totalFollowers,
            totalReach: totalReach,
            totalImpressions: totalImpressions,
            totalStreams: totalStreams,
            totalListenerMinutes: totalListenerMinutes,
            totalTracks: totalTracks,
            engagementRate: engagementRate,
            platformBreakdown: breakdownJSON,
            careerStage: careerStage,
            dominantPlatform: dominantPlatform,
            nextMilestones: nextMilestones,
            areasOfFocus: areasOfFocus
        )
    }

    private static func determineCareerStage(followers: Int) -> String {
        if followers < 1000 { return "Emerging" }
        if followers < 10000 { return "Growing" }
        if followers < 50000 { return "Established" }
        return "Scaling"
    }

    private static func generateMilestones(followers: Int) -> String {
        let milestones: [String]
        if followers < 1000 {
            milestones = ["Reach 1000 followers", "Get 5000 total streams", "Land 3 bookings"]
        } else if followers < 5000 {
            milestones = ["Reach 5000 followers", "Get 25000 total streams", "Book 10 events"]
        } else if followers < 10000 {
            milestones = ["Reach 10k followers", "Hit 100k streams", "Release EP"]
        } else {
            milestones = ["Reach 20k followers", "Release album", "Tour booking"]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: milestones, options: .prettyPrinted),
              let json = String(data: jsonData, encoding: .utf8)
        else { return "[]" }
        return json
    }

    private static func generateFocusAreas(insights: [PlatformInsight], dominantPlatform: String) -> String {
        var focusAreas: [String: String] = [:]

        let spotifyInsight = insights.first { $0.platform == "Spotify" }
        let youtubeInsight = insights.first { $0.platform == "YouTube" }
        let soundcloudInsight = insights.first { $0.platform == "SoundCloud" }

        if spotifyInsight == nil || (spotifyInsight?.monthlyListeners ?? 0) < 500 {
            focusAreas["Spotify"] = "Priority growth: Spotify playlisting + playlist pitching"
        }

        if youtubeInsight == nil || (youtubeInsight?.followers ?? 0) < 500 {
            focusAreas["YouTube"] = "Start uploading: Behind-the-scenes, production vlogs"
        }

        if soundcloudInsight == nil || (soundcloudInsight?.followers ?? 0) < 300 {
            focusAreas["SoundCloud"] = "Build community: Engage with followers, drop exclusives"
        }

        if dominantPlatform == "Instagram" {
            focusAreas["Diversification"] = "Instagram strong, diversify to streaming platforms"
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: focusAreas, options: .prettyPrinted),
              let json = String(data: jsonData, encoding: .utf8)
        else { return "{}" }
        return json
    }

    #if DEBUG
    static func runDebugSanityChecks() -> [String] {
        let setA = [
            PlatformInsight(platform: "Spotify", followers: 400, streams: 1000),
            PlatformInsight(platform: "YouTube", followers: 600, streams: 2000),
        ]
        let snapshotA = buildCareerSnapshot(from: setA)

        var failures: [String] = []
        if snapshotA.totalFollowers != 1000 {
            failures.append("totalFollowers esperado 1000, recebido \(snapshotA.totalFollowers)")
        }
        if snapshotA.totalStreams != 3000 {
            failures.append("totalStreams esperado 3000, recebido \(snapshotA.totalStreams)")
        }
        if snapshotA.careerStage != "Growing" {
            failures.append("careerStage esperado Growing, recebido \(snapshotA.careerStage)")
        }

        return failures
    }
    #endif
}