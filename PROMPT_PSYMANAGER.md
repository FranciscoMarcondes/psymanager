# Prompt: PsyManager - Assistente IA para DJ Produtor em Crescimento

## VISÃO GERAL DA APLICAÇÃO

Você está criando **PsyManager**, um aplicativo iOS (14.0+) que funciona como assistente completo e intelligent para Djs/produtores independentes, especialmente no nicho psytrance/eletrônico. O app é baseado em SwiftUI, SwiftData (persistência local), e integração com APIs (Instagram, Spotify, YouTube, etc).

**Objetivo Core**: Automatizar, organizar e otimizar TODO o fluxo de trabalho de um DJ solo que:
- Cria conteúdo (posts, reels, carrosel)
- Negocia bookings (contato com events/promoters)
- Lança faixas (distribuição em plataformas)
- Gerencia carreira (alertas, timeline, métricas)
- Busca inspiração e referências
- Aprende com histórico para melhorar continuamente

---

## ARQUITETURA TÉCNICA

### Stack Tecnológico
- **Framework**: SwiftUI com MVVM
- **Persistência**: SwiftData (modelos @Model com queries)
- **Backend**: Node.js/Express (mock server em desenvolvimento, APIs reais em produção)
- **Autenticação**: OAuth2 para Instagram, Spotify, Apple Music
- **IA Integration**: Opcional - Gemini API, OpenAI, ou local ML models
- **Imagem**: CoverDesignGenerator (paletas + layouts + dimensões por plataforma)
- **Notifications**: UserNotifications (alertas de eventos, follow-ups)

### Estrutura de Pastas
```
Features/
├── Dashboard/ (visão geral, próximos eventos, métricas)
├── Creation/ (conteúdo, capas, estratégia)
├── Booking/ (contatos, negociações, follow-ups)
├── Events/ (mapa de eventos por estado, busca)
├── Profile/ (artista, integrações, onboarding)
├── Messages/ (histórico de contatos, sugestões)

Domain/
├── Entities/ (ArtistProfile, EventLead, Gig, etc)

Services/
├── Insights/ (estratégia, análise, covers)
├── AI/ (simulação/integração com IA)

App/
├── AppRootView, RootTabView, PsyManagerApp
```

---

## MODELOS DE DADOS (SwiftData)

### 1. **ArtistProfile**
```swift
@Model
final class ArtistProfile {
    var stageName: String
    var genre: String // "Psytrance Progressive", etc
    var city: String
    var bio: String
    var toneOfVoice: String // "experimental", "groovy", "dark"
    var contentFocus: String // Temas principais
    var visualIdentity: String // Cores, estilo visual
    var targetAudience: String // Descrição do público
    var connections: [StreamingConnection] // Spotify, Instagram, Apple Music
}

@Model
final class StreamingConnection {
    var platform: String // "Instagram", "Spotify", "YouTube"
    var handle: String
    var isConnected: Bool
    var lastSync: Date?
}
```

### 2. **EventLead** (Evento/Promoter identificado)
```swift
@Model
final class EventLead {
    var name: String
    var city: String
    var state: String  
    var eventDate: Date
    var venue: String
    var instagramHandle: String
    var status: String // "notContacted", "contacted", "negotiating", "booked", "rejected"
    var notes: String
    var promoter: PromoterContact?
}
```

### 3. **PromoterContact** (Pessoa de contato)
```swift
@Model
final class PromoterContact {
    var name: String
    var city: String
    var state: String
    var instagramHandle: String
    var phone: String?
    var email: String?
    var notes: String
    var leads: [EventLead]? // Eventos que gerencia
}
```

### 4. **Negotiation** (Negociação de booking)
```swift
@Model
final class Negotiation {
    var stage: String // "initial", "negotiating", "contracted", "rejected"
    var offeredFee: Int
    var desiredFee: Int
    var notes: String
    var nextActionDate: Date
    var nextActionType: String // "followUp", "sendProposal", "confirmDetails"
    var suggestedMessage: String
    var promoter: PromoterContact
    var lead: EventLead
}
```

### 5. **Gig** (Show confirmado)
```swift
@Model
final class Gig {
    var title: String
    var city: String
    var state: String
    var date: Date
    var fee: Int
    var contactName: String
    var notes: String
    var checklistSummary: String // Tour details
    var isCompleted: Bool
}
```

### 6. **SocialContentPlanItem** (Conteúdo planejado)
```swift
@Model
final class SocialContentPlanItem {
    var title: String
    var contentType: String // "Reel", "Carrossel", "Story"
    var objective: String // "Alcance", "Seguidores", "Booking"
    var status: String // "Rascunho", "Planejado", "Publicado", "Concluído"
    var scheduledDate: Date
    var pillar: String // Tema de conteúdo
    var hook: String
    var caption: String
    var cta: String
    var hashtags: String
    var publishedAt: Date?
    var completedAt: Date?
}
```

### 7. **SocialContentAnalytics** (Métricas de performance)
```swift
@Model
final class SocialContentAnalytics {
    var contentPlanItemID: String
    var likes: Int
    var comments: Int
    var shares: Int
    var reach: Int
    var engagementRate: Double
    var publishedAt: Date
}
```

### 8. **SocialInsightSnapshot** (Histórico semanal Instagram)
```swift
@Model
final class SocialInsightSnapshot {
    var periodLabel: String
    var periodStart: Date
    var periodEnd: Date
    var followersStart: Int
    var followersEnd: Int
    var reach: Int
    var impressions: Int
    var reelViews: Int
    var postsPublished: Int
}
```

### 9. **CareerTask** (Tarefas da semana)
```swift
@Model
final class CareerTask {
    var title: String
    var detail: String
    var priority: String // "high", "medium", "low"
    var dueDate: Date
    var isCompleted: Bool
}
```

### 10. **MessageTemplate** (Histórico + sugestões de mensagens)
```swift
@Model
final class MessageTemplate {
    var title: String
    var body: String
    var category: String // "Primeira abordagem", "Follow-up", "Negociação"
    var isFavorite: Bool
    var context: String? // "Organizer não respondeu em 72h", etc
}
```

---

## FUNCIONALIDADES PRINCIPAIS

### 🎯 **SEÇÃO 1: DASHBOARD**
**Propósito**: Visão geral, chamadas à ação urgentes, próximos passos.

**Componentes**:
- **Social Pulse Card**: Influências crescimento (seguidores semana), reach/post, foco recomendado
- **Upcoming Gigs**: Próximos shows em card com countdown
- **This Week Tasks**: Tarefas da semana (content, bookings, follow-ups)
- **Quick Stats**: Reels publicados, contatos feitos, taxa de resposta
- **AI Consultation Button**: Acesso rápido ao chat

---

### 📱 **SEÇÃO 2: CREATION STUDIO**
**Propósito**: Central de criação de conteúdo com inteligência.

**Features**:
1. **Social Media Strategist**
   - Diagnóstico automático baseado em métricas (crescimento baixo/alto, reach/post, engagement)
   - Recomendações de pilares (ex: "Foque em Autoridade de Pista - seus Reels com drop têm 9.5% engagement")
   - Sprint semanal com ações priorizadas
   - Hooks e CTAs contextualizados

2. **Performance Analytics**
   - Análise por formato (Reel vs Carrossel): qual engaja mais?
   - Análise por objetivo: qual objetivo gera mais seguidores/reaches?
   - Auto-recomendação: "Crie Reels focando em Processo Criativo - seu melhor performer"

3. **Editorial Calendar**
   - Exibição de conteúdos planejados
   - Status workflow: Rascunho → Planejado → Publicado → Concluído
   - Botão de edição com sheet para mudar status + capturar métricas
   - Dias desde publicação

4. **Content Draft Lab**
   - Seleção de Objetivo (Alcance, Seguidores, Booking)
   - Seleção de Formato (Reel, Carrossel, Story)
   - Seleção de Pilar (Autoridade de Pista, Processo Criativo, etc)
   - **Gerar Draft**: Produz hook, legenda, CTA, hashtags contextualizados
   - **Salvar**: Entra no calendário editorial

5. **Cover Design Studio**
   - Seleção multi-plataforma:
     * Spotify, Apple Music, SoundCloud, Bandcamp
     * YouTube, Twitch, Twitch Overlay
     * Reel, TikTok, Instagram Story
     * Discord, Beatsport
   - Input: Nome da faixa + Mood (energético, melancólico, experimental, groovy, dark)
   - Output por plataforma:
     * Dimensões exatas + DPI
     * Paleta de cores (com justificativa)
     * Composição visual (layout, elementos, tipografia)
     * Motivos visuais
     * Dicas específicas

---

### 🎤 **SEÇÃO 3: BOOKING MANAGER**
**Propósito**: Central de negociações e follow-ups.

**Features**:
1. **Contact Management**
   - Lista de promoters/organizers por estado
   - Histórico de contato (quem contatei, quando, status)
   - Tags: "não respondeu", "respondeu positivo", "esperando proposta", etc

2. **Event Discovery**
   - Mapa interativo por estado
   - Lista de eventos upcoming + Instagram handle
   - Busca por gênero, capacidade, localização

3. **Message Control & Workflow**
   - Status de lead: "Not Contacted" → "Contacted" → "Negotiating" → "Booked/Rejected"
   - Histórico de mensagens por lead
   - Sugestões de follow-up:
     * "72h sem resposta após 1ª msg? Enviar follow-up (sugestão aqui)"
     * "Curtiu mas não respondeu? Estratégia diferente (sugestão aqui)"
     * "Viu e ignorou? Abordar de forma diferente"
   - Recomendação de próxima ação + data sugerida

4. **Negotiation Tracker**
   - Oferta vs. desejado
   - Timeline de propostas enviadas
   - Próximos passos com sugestões

5. **Message Templates**
   - Categorias: Primeira abordagem, Follow-up educado, Follow-up agressivo, Negociação, Rejeição amigável
   - Contexto-aware (gera templates baseado no histórico)
   - Favorites para reuso

---

### 📅 **SEÇÃO 4: EVENTS DISCOVERY**
**Propósito**: Encontrar oportunidades de booking.

**Features**:
1. **State Map**
   - Visualização de estados/regiões
   - Contagem de eventos por estado
   - Click para expandir lista

2. **Event List**
   - Filtros: estado, data, gênero, capacidade aproximada
   - Informações: data, venue, cidade, Instagram handle
   - Status de contato (se já tentou contatar esse organizer)
   - Add to favorites

3. **Event Details**
   - Nome, data, local, capacidade estimada
   - Instagram profile link
   - Histórico de contatos com esse organizer (se houver)
   - Sugestões de approach baseado no tipo de evento

---

### 💬 **SEÇÃO 5: AI ADVISOR** (Future: Real IA, Now: Smart Templates)
**Propósito**: Consultor de carreira inteligente.

**Features**:
1. **Initial Onboarding** (ao primeiro uso)
   - "Como você se chama artisticamente?"
   - "Qual seu gênero principal?"
   - "Qual seu tom de voz/estilo visual?"
   - "Onde você atua (estado)?"
   - "Qual seu público alvo?"
   - "Quais plataformas usa?"
   - "Qual seu maior desafio agora?" (conteúdo, bookings, produção, etc)

2. **Smart Suggestions** (baseado em histórico)
   - "Vi que seus Reels sobre drops têm 9.5% engagement. Recomendo 2-3 por semana"
   - "Você contatou 15 promoters em SP este mês mas teve 20% de resposta. Quer que sugira uma estratégia diferente?"
   - "Você publicou, mas em horário ruim. Dados mostram 7pm-9pm é melhor para seu público"

3. **Career Path Guidance**
   - "Você pode estar pronto para eventos maiores. Aqui estão 5 eventos em seu estado"
   - "Você tem 5 Gigs confirmados em 3 meses. Hora de negociar fee melhor!"

4. **Learning System**
   - Rastreia sucesso/falha de estratégias
   - "Você teve 3 rejeições com essa abordagem. Dados mostram contexto diferente pode ajudar"
   - Melhora continuamente as sugestões

---

### 👤 **SEÇÃO 6: PROFILE & SETTINGS**
**Propósito**: Gerenciar identidade, integrações, preferências.

**Features**:
1. **Artist Profile**
   - Nome artístico, gênero, bio, tone of voice
   - Visual identity (cores preferidas, estilo)
   - Target audience description

2. **Integrations**
   - Instagram connect (OAuth para insights)
   - Spotify connect (para distribuição)
   - Apple Music, SoundCloud, Bandcamp setup
   - YouTube channel
   - Twitch (opcional para live)

3. **Notification Settings**
   - Alert para gigs em X dias antes
   - Follow-up reminders
   - Weekly digest de oportunidades
   - Customize horários

4. **Preferences**
   - Modo escuro (padrão - app é dark psytrance aesthetic)
   - Idioma (PT-BR primary)
   - Unidades de distância (km), moeda
   - Frequência de sync com APIs

---

## SERVIÇOS & LÓGICA (Services)

### SocialMediaStrategist
- `buildReport(profile, snapshots)` → Retorna diagnóstico completo
- Identifica estágio de crescimento do artista
- Recomenda pilares, hooks, CTAs
- Prioriza ações da semana

### ContentPerformanceAnalyzer
- `analyzeByContentType()` → Qual formato performa melhor
- `analyzeByObjective()` → Qual objetivo (alcance, seguidores, booking) funciona
- `analyzeByPillar()` → Qual tema de conteúdo engaja
- `generateRecommendation()` → Próximo conteúdo sugerido
- `identifyUnderperforming()` → Formatos/objetivos que precisam melhorar

### SocialContentGenerator
- `generate(profile, objective, pillar, type)` → Draft completo
- Hook contextualizado ao objetivo e perfil
- Legenda com call-to-action estratégico
- Hashtags relevantes ao nicho + localização
- Suporte a objetivo: Alcance, Seguidores, Booking

### CoverDesignGenerator
- `generateForTrack(trackName, profile, format, mood)` → Recomendações visuais
- Paleta de cores por gênero e mood
- Composição específica por plataforma
- Motivos visuais alinhados ao estilo
- Dimensões e DPI para cada formato
- Design notes contextualizados

### ContentStatusUpdater
- `moveToPublished()` → Marca como publicado + captura métricas iniciais
- `moveToScheduled/Completed/Draft()` → Transições validadas
- `canTransitionTo()` → Valida fluxo de status
- Integração com SocialContentAnalytics

### BookingAdvisor (Future: IA)
- Sugere próximo passo em negociação
- Recomenda templates de mensagem
- Aprende com histórico de tentativas
- Identifica padrões de sucesso/falha

### EventDiscovery
- Scrape/API de eventos por estado (Eventbrite API, Facebook Events, Instagram Hashtags)
- Filtra por gênero/capacidade
- Identifica organizers e extrai Instagram handles
- Ranking de oportunidades por fit

---

## FLUXOS DE USUÁRIO (User Journeys)

### 👨‍🎤 **Journey 1: DJ Criando Conteúdo**
1. Abre Dashboard → vê "Crescimento 3.2% cette semana, foco em Reels"
2. Vai para Creation Studio
3. Clica "Gerar draft" com Objetivo=Alcance, Format=Reel, Pilar=Autoridade de Pista
4. App gera hook, legenda, CTA, hashtags
5. Edita/aprova
6. Salva no calendário → Status "Rascunho"
7. Agenda para amanhã → Status "Planejado"
8. Publica no Instagram → Volta pro app, muda status para "Publicado" + captura likes/comments iniciais
9. App cria registro em SocialContentAnalytics
10. Próxima semana: Analytics mostram que esse Reel teve 8.2% engagement
11. App recomenda: "Este tipo de conteúdo está funcionando. Faça 2-3 similares esta semana"

### 📧 **Journey 2: DJ Procurando Bookings**
1. Dashboard mostra "3 Gigs este mês. Próximo em 12 dias"
2. Clica em "Events Discovery"
3. Seleciona Estado = São Paulo, Data = próximos 30 dias
4. App mostra 45 eventos com organizadores
5. Clica em evento "Festival Cosmic" → Vê Instagram handle do organizer
6. Clica "Contatar" → App mostra template de primeira abordagem
7. Edita + envia diretamente do app (ou copia e manda manual)
8. App marca status como "Contacted" + data de envio
9. 48h depois: App alerta "Nenhuma resposta em 48h. Seguir-up em 24h mais?"
10. DJ decide fazer follow-up → App sugere template diferente
11. Envia → Desta vez, organizer responde com oferta
12. DJ clica "Negotiating" → App mostra campo para oferta deles vs. sua desejada
13. Propõe contra-oferta com template de negociação
14. Combina em valor X → Status "Booked"
15. Data chega → App envia alert "Gig em 3 dias. Checklist: USB, intro edit, roupa..."

### 🎨 **Journey 3: Preparando Lançamento de Faixa (Future)**
1. DJ vai ao Creation Studio → "Preparar Lançamento de Faixa"
2. Input: "Nome da faixa: Void Logic" + Mood: Dark
3. App gera plano de lançamento:
   - Teaser com waveform (5 dias antes)
   - Reel mostrando produção (3 dias antes)
   - Anúncio em todas as plataformas (1 dia antes)
   - Pre-save links (Spotify, Apple Music - gerados automaticamente)
   - Post-launch follow-up (dia 7)
4. Para cada conteúdo, app gera recomendações de design + copy
5. DJ revisa calendar → Todos os posts estão agendados
6. Lançamento acontece → App monitora primeiras métricas
7. 7 dias depois: App analisa performance do lançamento
   - Qual plataforma mais listeners?
   - Qual post teve melhor engajamento?
   - Recomendações para próximo lançamento

---

## FLUXO DE DADOS & INTEGRAÇÕES

### Instagram Connection (OAuth)
1. DJ clica "Conectar Instagram" → Deep link abre navegador
2. Autentica no Instagram
3. App recebe access token + user info
4. Armazena em AppStorage (com expiry tracking)
5. Semanal: Fetch insights (followers, reach, impressions, engagements, reel_views)
6. Armazena em SocialInsightSnapshot

### Spotify Connection (Future)
1. DJ clica "Conectar Spotify" → OAuth flow
2. App acessa histórico de lançamentos
3. Extrai BPM, key, mood, danceability
4. Usa para recomendações futuras

### Event Data Sources (Future)
1. Eventbrite API: Eventos por localização
2. Facebook Events: Scrape de eventos locais
3. Instagram Hashtags: #psytrance #events #[city]
4. Bandcamp: Eventos de shows
5. Consolidação em um único feed

### IA Integration (Phase 2)
- Opcional: Conectar a Gemini API / OpenAI
- Exemplo: "Preciso de 5 ideias de conteúdo para Psytrance" → IA gera baseado no profil do artista
- Chat assistant que conhece histórico completo do usuário
- Análise de feedback de DJs que contatou: "Por que rejeitaram 3 eventos em SP?"

---

## DESIGN & UX

### Color Palette (Psytrance Aesthetic)
- **Primary**: #00D4FF (Cyan vibrante)
- **Secondary**: #9945FF (Purple)
- **Accent**: #FF00FF (Magenta)
- **Background**: #0A0A0A (Very dark)
- **Card BG**: #1A1A2E (Slightly lighter)
- **Text Primary**: #FFFFFF
- **Text Secondary**: #A0A0A0

### Typography
- Display: Futura Bold, Montserrat Bold
- Body: SF Pro Display (system default)
- Caption: SF Pro Text

### Components
- PsyCard: Custom card com gradiente subtle
- PsyStatusPill: Badges com cores por status
- PsySectionHeader: Section titles com eyebrow text + icon

### Animation
- Subtle fade-ins para cards
- Smooth transitions entre sections
- BPM-synced pulse animation em cards "urgent" (experimental)

---

## ROADMAP & PRIORIDADES

### MVP (v1.0)
- ✅ Dashboard com social pulse
- ✅ Content creation studio (draft generation)
- ✅ Editorial calendar com status workflow
- ✅ Performance analytics
- ✅ Multi-platform cover design recommendations
- ⏳ Event discovery by state
- ⏳ Booking message control

### Phase 2 (v1.5)
- Track feedback engine (BPM, estrutura, LOUDNESS, eq)
- Launch strategy planner (timeline + sequência de conteúdo)
- AI advisor chat (real IA integration)
- Facebook Events + Eventbrite API
- Message template learning system

### Phase 3 (v2.0)
- Apple Music, Bandcamp, SoundCloud integrations (para distribuição)
- Twitch overlay generator (para lives)
- Setlist generator (baseado em BPM + sound matching)
- Collaboration tools (convidar outros DJs/produtores)
- Analytics dashboard profundo (cohort analysis, churn prediction)

---

## TÉCNICAS DE MONETIZAÇÃO (Futuro)

- **Freemium**: Core features free, premium para analytics avançados
- **Premium**: $9.99/mês para AI advisor, event scraping, template library
- **Booking Affiliate**: 2-3% comissão em gigs negociados via app (opcional)
- **Analytics**: Exportar relatórios profissionais (PDF, share com promoters)

---

## KPIs & MÉTRICAS DE SUCESSO

1. **Adoption**: # de DJs onboarded, retention rate
2. **Content**: # de posts gerados vs. criados manualmente (diferença de tempo)
3. **Bookings**: # de contatos → # de respostas → # de gigs booked (funnel)
4. **Engagement**: Evolução do artista (followers, reaches, engagement rate)
5. **Time Saved**: Horas economizadas por semana (survey)

---

## PRÓXIMAS AÇÕES (AGORA)

1. **Implementar Event Discovery** por estado (mock data → real API)
2. **Booking Manager** com message history + follow-up sugestões
3. **Track Feedback Engine** (análise de BPM, harmonia, energia)
4. **Launch Strategy** (plano completo de lançamento de faixa)
5. **IA Chat** (integração com Gemini para personalized advice)
