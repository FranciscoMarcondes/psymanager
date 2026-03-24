import Foundation
import SwiftData

enum SampleDataSeeder {
    static func seedIfNeeded(in context: ModelContext) throws {
        let templateDescriptor = FetchDescriptor<MessageTemplate>()
        let existingTemplates = try context.fetch(templateDescriptor)
        if existingTemplates.isEmpty {
            context.insert(MessageTemplate(
                title: "Primeira abordagem - open air",
                body: "Oi, time! Sou artista de psytrance e curti muito a proposta de vocês. Tenho um set alinhado com pista progressiva e narrativa energética. Posso enviar press kit e proposta para futuras datas?",
                category: "Primeira abordagem",
                isFavorite: true
            ))
            context.insert(MessageTemplate(
                title: "Follow-up educado 72h",
                body: "Passando para reforçar meu interesse no evento. Se fizer sentido, envio agora uma proposta objetiva com formato de set, disponibilidade e materiais.",
                category: "Follow-up",
                isFavorite: true
            ))
            context.insert(MessageTemplate(
                title: "Fechamento de negociação",
                body: "Perfeito, podemos fechar com esse formato. Me confirma os detalhes finais de horário, estrutura e contrato para eu alinhar tudo do meu lado.",
                category: "Negociação",
                isFavorite: false
            ))
            context.insert(MessageTemplate(
                title: "Confirmação de gig",
                body: "Gig confirmada! Me passa por favor: horario de soundcheck, duracao do set, contato tecnico e orientacoes de credenciamento.",
                category: "Confirmação",
                isFavorite: false
            ))
            context.insert(MessageTemplate(
                title: "Agradecimento pós-evento",
                body: "Obrigado pela noite de ontem! Curti muito tocar no evento e a energia da pista. Se fizer sentido, vamos mapear as proximas datas juntos.",
                category: "Relacionamento",
                isFavorite: false
            ))
        }

        let contentDescriptor = FetchDescriptor<SocialContentPlanItem>()
        let existingContent = try context.fetch(contentDescriptor)
        if existingContent.isEmpty {
            let now = Date()
            let calendar = Calendar.current
            
            // Published content from 10 days ago
            context.insert(SocialContentPlanItem(
                title: "Reel • Beat drop essencial",
                contentType: "Reel",
                objective: "Alcance",
                status: "Concluído",
                scheduledDate: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
                pillar: "Autoridade de pista",
                hook: "Esse drop foi a vibe da noite.",
                caption: "Momento peak do set, beat progressivo desenrolando.",
                cta: "Marca quem tava nesse momento contigo 🎵",
                hashtags: "#psytrance #djset #musicmoment",
                publishedAt: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
                completedAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now
            ))
            
            // Published content from 7 days ago
            context.insert(SocialContentPlanItem(
                title: "Carrossel • Line-up festival",
                contentType: "Carrossel",
                objective: "Booking",
                status: "Concluído",
                scheduledDate: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                pillar: "Prova social",
                hook: "Uma galera que você precisa conhecer.",
                caption: "Line-up confirmado com uns produtores pesados do underground.",
                cta: "Chama a crew pra esse lineup",
                hashtags: "#bookingdj #festivalseason #psytrance",
                publishedAt: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
                completedAt: calendar.date(byAdding: .day, value: -2, to: now) ?? now
            ))
            
            // Scheduled for tomorrow
            context.insert(SocialContentPlanItem(
                title: "Reel • Autoridade de pista",
                contentType: "Reel",
                objective: "Alcance",
                status: "Planejado",
                scheduledDate: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                pillar: "Autoridade de pista",
                hook: "Pouca gente viu o que aconteceu nesse drop.",
                caption: "Drop, crowd reaction e energia real de pista para puxar descoberta orgânica.",
                cta: "Salva e compartilha com quem vive essa vibe.",
                hashtags: "#psytrance #djset #raveculture #musicdiscovery"
            ))
            
            // Draft for later
            context.insert(SocialContentPlanItem(
                title: "Carrossel • Prova social",
                contentType: "Carrossel",
                objective: "Booking",
                status: "Rascunho",
                scheduledDate: calendar.date(byAdding: .day, value: 3, to: now) ?? now,
                pillar: "Prova social",
                hook: "Lineup, crowd e identidade em um só post.",
                caption: "Carrossel para transformar percepção em confiança de contratante.",
                cta: "Se combinar com sua pista, chama no direct para booking.",
                hashtags: "#bookingdj #festivalbooking #psytrance #lineupartist"
            ))
        }

        let taskDescriptor = FetchDescriptor<CareerTask>()
        let existingTasks = try context.fetch(taskDescriptor)
        guard existingTasks.isEmpty else { return }

        let calendar = Calendar.current
        let now = Date()

        context.insert(CareerTask(
            title: "Fechar abordagem de 3 promoters",
            detail: "Enviar primeira mensagem personalizada para tres eventos de SP.",
            priority: TaskPriority.high.rawValue,
            dueDate: calendar.date(byAdding: .day, value: 1, to: now) ?? now
        ))
        context.insert(CareerTask(
            title: "Planejar reels da semana",
            detail: "Definir hook, roteiro e CTA para dois reels.",
            priority: TaskPriority.medium.rawValue,
            dueDate: calendar.date(byAdding: .day, value: 3, to: now) ?? now
        ))

        let promoterJulia = PromoterContact(
            name: "Julia Andrade",
            city: "Campinas",
            state: "SP",
            instagramHandle: "@julia.bookings",
            phone: "+55 19 99999-0000",
            email: "julia@bookingmail.com",
            notes: "Prefere comunicação objetiva e responde melhor no inicio da noite."
        )
        context.insert(promoterJulia)

        let promoterRafael = PromoterContact(
            name: "Rafael Mattos",
            city: "Curitiba",
            state: "PR",
            instagramHandle: "@rafa.openair",
            phone: "+55 41 98888-1234",
            email: "rafael@openairpr.com",
            notes: "Busca artistas com narrativa forte de pista e bom conteudo de bastidores."
        )
        context.insert(promoterRafael)

        let lead1 = EventLead(
            name: "Cosmic Bloom Open Air",
            city: "Campinas",
            state: "SP",
            eventDate: calendar.date(byAdding: .day, value: 18, to: now) ?? now,
            venue: "Vale Aurora",
            instagramHandle: "@cosmicbloomfestival",
            status: LeadStatus.waitingReply.rawValue,
            notes: "Promoter visualizou o ultimo story; boa chance para follow-up.",
            promoter: promoterJulia
        )
        context.insert(lead1)

        let lead2 = EventLead(
            name: "Neon Mandala Club Night",
            city: "Sao Paulo",
            state: "SP",
            eventDate: calendar.date(byAdding: .day, value: 27, to: now) ?? now,
            venue: "Subsolo Prism",
            instagramHandle: "@neonmandala",
            status: LeadStatus.notContacted.rawValue,
            notes: "Line-up com artistas de full-on progressivo."
        )
        context.insert(lead2)

        let lead3 = EventLead(
            name: "Bosque Frequency",
            city: "Curitiba",
            state: "PR",
            eventDate: calendar.date(byAdding: .day, value: 34, to: now) ?? now,
            venue: "Parque da Serra",
            instagramHandle: "@bosquefrequency",
            status: LeadStatus.negotiating.rawValue,
            notes: "Promoter pediu proposta com set de 2h e versao sunrise.",
            promoter: promoterRafael
        )
        context.insert(lead3)

        context.insert(Negotiation(
            stage: LeadStatus.negotiating.rawValue,
            offeredFee: 1200,
            desiredFee: 1600,
            notes: "Promoter pediu proposta com set de 90 minutos.",
            nextActionDate: calendar.date(byAdding: .day, value: 2, to: now) ?? now,
            promoter: promoterJulia,
            lead: lead1
        ))

        context.insert(SocialInsightSnapshot(
            periodLabel: "Semana -3",
            periodStart: calendar.date(byAdding: .day, value: -21, to: now) ?? now,
            periodEnd: calendar.date(byAdding: .day, value: -14, to: now) ?? now,
            followersStart: 1100,
            followersEnd: 1132,
            reach: 5200,
            impressions: 8700,
            profileVisits: 360,
            reelViews: 2900,
            postsPublished: 3,
            source: "manual"
        ))
        context.insert(SocialInsightSnapshot(
            periodLabel: "Semana -2",
            periodStart: calendar.date(byAdding: .day, value: -14, to: now) ?? now,
            periodEnd: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
            followersStart: 1132,
            followersEnd: 1170,
            reach: 6400,
            impressions: 9800,
            profileVisits: 420,
            reelViews: 3800,
            postsPublished: 4,
            source: "manual"
        ))
        context.insert(SocialInsightSnapshot(
            periodLabel: "Semana atual",
            periodStart: calendar.date(byAdding: .day, value: -7, to: now) ?? now,
            periodEnd: now,
            followersStart: 1170,
            followersEnd: 1218,
            reach: 7400,
            impressions: 11300,
            profileVisits: 560,
            reelViews: 4700,
            postsPublished: 4,
            source: "manual"
        ))

        context.insert(Gig(
            title: "Aura Garden Session",
            city: "Sorocaba",
            state: "SP",
            date: calendar.date(byAdding: .day, value: 12, to: now) ?? now,
            fee: 1500,
            contactName: "Julia promoter",
            checklistSummary: "Pendrive, intro edit, roupa preta UV, horario de soundcheck confirmado."
        ))

        context.insert(Gig(
            title: "Midnight Prism Showcase",
            city: "Sao Paulo",
            state: "SP",
            date: calendar.date(byAdding: .day, value: 21, to: now) ?? now,
            fee: 1800,
            contactName: "Equipe Neon Mandala",
            checklistSummary: "Set 90min, stage plot aprovado, transporte fechado."
        ))

        // Add analytics data for published content to show performance tracking
        let analyticsDescriptor = FetchDescriptor<SocialContentAnalytics>()
        let existingAnalytics = try context.fetch(analyticsDescriptor)
        if existingAnalytics.isEmpty {
            // Simulate published Reel with strong engagement
            context.insert(SocialContentAnalytics(
                contentPlanItemID: UUID().uuidString,
                contentType: "Reel",
                objective: "Alcance",
                pillar: "Autoridade de pista",
                publishedAt: calendar.date(byAdding: .day, value: -10, to: now) ?? now,
                likes: 287,
                comments: 34,
                shares: 12,
                reach: 4200,
                impressions: 6800,
                saves: 45,
                followersAtPublish: 1100
            ))
            
            // Simulate published Carousel with moderate engagement
            context.insert(SocialContentAnalytics(
                contentPlanItemID: UUID().uuidString,
                contentType: "Carrossel",
                objective: "Booking",
                pillar: "Prova social",
                publishedAt: calendar.date(byAdding: .day, value: -8, to: now) ?? now,
                likes: 156,
                comments: 18,
                shares: 8,
                reach: 2100,
                impressions: 3400,
                saves: 22,
                followersAtPublish: 1132
            ))
            
            // Another Reel with high engagement
            context.insert(SocialContentAnalytics(
                contentPlanItemID: UUID().uuidString,
                contentType: "Reel",
                objective: "Alcance",
                pillar: "Processo criativo",
                publishedAt: calendar.date(byAdding: .day, value: -5, to: now) ?? now,
                likes: 421,
                comments: 52,
                shares: 28,
                reach: 5800,
                impressions: 8900,
                saves: 67,
                followersAtPublish: 1170
            ))
        }

        let platformInsightDescriptor = FetchDescriptor<PlatformInsight>()
        let existingPlatformInsights = try context.fetch(platformInsightDescriptor)
        if existingPlatformInsights.isEmpty {
            context.insert(PlatformInsight(
                platform: "Instagram",
                followers: 1218,
                reach: 7400,
                impressions: 11300,
                likes: 864,
                comments: 104,
                shares: 48,
                saves: 134,
                profileViews: 560,
                trackCount: 24,
                platformProfileUrl: "https://instagram.com/demo_dj"
            ))

            context.insert(PlatformInsight(
                platform: "Spotify",
                followers: 3400,
                streams: 87500,
                trackCount: 8,
                totalMinutesStreamed: 125000,
                topCountries: "Brazil,Germany,Portugal",
                monthlyListeners: 2150,
                playlistInclusions: 47,
                platformProfileUrl: "https://open.spotify.com/artist/demo"
            ))

            context.insert(PlatformInsight(
                platform: "SoundCloud",
                followers: 845,
                streams: 34200,
                likes: 320,
                comments: 89,
                shares: 45,
                trackCount: 12,
                totalMinutesStreamed: 45000,
                platformProfileUrl: "https://soundcloud.com/demo_dj"
            ))

            context.insert(PlatformInsight(
                platform: "YouTube",
                followers: 2340,
                impressions: 145000,
                streams: 567000,
                likes: 12500,
                comments: 2340,
                trackCount: 156,
                totalMinutesStreamed: 450000,
                platformProfileUrl: "https://youtube.com/@demo_dj"
            ))

            context.insert(PlatformInsight(
                platform: "Apple Music",
                followers: 1200,
                streams: 45000,
                trackCount: 8,
                totalMinutesStreamed: 67500,
                monthlyListeners: 890,
                playlistInclusions: 23,
                platformProfileUrl: "https://music.apple.com/artist/demo"
            ))

            context.insert(PlatformInsight(
                platform: "BeatPort",
                followers: 450,
                streams: 12500,
                trackCount: 5,
                platformProfileUrl: "https://www.beatport.com/artist/demo"
            ))
        }

        let careerSnapshotDescriptor = FetchDescriptor<ArtistCareerSnapshot>()
        let existingSnapshots = try context.fetch(careerSnapshotDescriptor)
        if existingSnapshots.isEmpty {
            let allInsights = try context.fetch(platformInsightDescriptor)
            if !allInsights.isEmpty {
                let snapshot = CareerInsightAggregator.buildCareerSnapshot(from: allInsights)
                context.insert(snapshot)
            }
        }

        try context.save()
    }
}
