# PsyManager - Status de Desenvolvimento

## ✅ CONCLUÍDO (MVP Fundação)

### Core Infrastructure
- ✅ SwiftUI + SwiftData architecture (Models, Queries, Persistence)
- ✅ Node.js backend (OAuth, insights endpoints)
- ✅ App navigation (RootTabView com 6 abas principais)
- ✅ Design system (PsyTheme, PsyCard, custom components)

### 1. Dashboard
- ✅ Social Media Pulse (growth, reach/post, recomendação de foco)
- ✅ Upcoming Gigs preview
- ✅ Weekly tasks display

### 2. Creation Studio
- ✅ **Social Media Strategist**: Diagnóstico automático (SocialMediaStrategist.swift)
  - Detecta estágio de crescimento
  - Recomenda 4 pilares contextualizados
  - Gera sprint semanal com ações
  - Sugere hooks e CTAs personalizados

- ✅ **Performance Analytics**: Métricas inteligentes (ContentPerformanceAnalyzer.swift)
  - Análise por formato (Reel, Carrossel, Stories)
  - Análise por objetivo (Alcance, Seguidores, Booking)
  - Análise por pilar (conteúdo themes)
  - Auto-recomendação com engagement benchmark
  - Detecção de low performers

- ✅ **Editorial Calendar**: Gerenciamento completo (SocialContentPlanItem)
  - Permanência com SwiftData
  - Status workflow: Rascunho → Planejado → Publicado → Concluído
  - Edição com sheet modal (ContentStatusUpdateView)
  - Captura de métricas ao publicar
  - Dias desde publicação

- ✅ **Content Draft Lab**: Gerador contextualizado (SocialContentGenerator.swift)
  - 3 dimensões de seleção: Objetivo × Formato × Pilar
  - Gera hook, caption, CTA, hashtags
  - Contexto-aware (profile genre, city, tone)
  - Salva automaticamente no calendário

- ✅ **Cover Design Studio**: Multi-plataforma (CoverDesignGenerator.swift)
  - 12 plataformas suportadas:
    * Streaming: Spotify, Apple Music, SoundCloud, Bandcamp
    * Social: Reel, TikTok, Instagram Story, YouTube
    * Comunidade: Discord, Beatsport
    * Streaming de vídeo: Twitch, Twitch Overlay
  - Por plataforma:
    * Dimensões exatas + DPI
    * Paleta de cores (4 cores + rationale)
    * Composição visual (layout, tipografia, zonas seguras)
    * Motivos visuais contextualizados ao gênero
    * Dicas de design específicas
  - Input: Nome da faixa + Mood (5 opções)

### 3. Profile & Integrations
- ✅ Artist profile management
- ✅ Instagram OAuth connection (com error handling)
- ✅ Connection status pills (visual feedback)
- ✅ Last sync timestamp display

### 4. Data Models
- ✅ ArtistProfile
- ✅ SocialInsightSnapshot (semanal)
- ✅ SocialContentPlanItem (com status + timestamps)
- ✅ SocialContentAnalytics (performance tracking)
- ✅ CareerTask
- ✅ MessageTemplate
- ✅ EventLead
- ✅ PromoterContact
- ✅ Negotiation
- ✅ Gig

### 5. Services
- ✅ SocialMediaStrategist
- ✅ ContentPerformanceAnalyzer
- ✅ SocialContentGenerator
- ✅ ContentStatusUpdater
- ✅ CoverDesignGenerator

### 6. Sample Data
- ✅ Seeding sistema (SampleDataSeeder.swift)
  - 2 realistic content items (published + draft)
  - 3 analytics records com métricas reais
  - 2 event leads
  - 1 negotiation em progresso
  - 3 career tasks
  - Message templates

### Build Status
- ✅ 4 builds consecutivos com sucesso (BUILD SUCCEEDED)
- ✅ Zero warnings/errors
- ✅ All new features compiling cleanly

---

## ⏳ PRÓXIMOS (Priority Order)

### FASE 1: Booking Management (2-3 sprints)
1. **Events Discovery Interface**
   - State map visualization (com event counts)
   - Event list com filtros (state, date, genre)
   - Event details + organizer info
   - One-tap "Contatar" action

2. **Booking Manager Tab**
   - PromoterContact list (com cidade, handles)
   - Lead status pipeline (Not Contacted → Contacted → Negotiating → Booked)
   - Quick stats: Total contacted, response rate, follow-ups pending

3. **Message Control System**
   - Message history per lead
   - Status suggestions (based on time elapsed + response)
   - Follow-up reminders + suggested templates
   - Copy-paste friendly suggestions

4. **Negotiation Tracker**
   - Offer vs. desired display
   - Next action + date picker
   - Integration com CareerTask (to-do)

### FASE 2: Track Feedback Engine (1-2 sprints)
1. **Track Analysis Service**
   - Input: BPM, key, structure (intro-build-drop-outro)
   - Análise: Energy profile, danceability estimate
   - Recomendações: "Drop poderia ser 2 beats mais longo"

2. **Feedback UI**
   - Visual waveform com análise
   - Energy curve graph
   - Comparison com top tracks do gênero

### FASE 3: Launch Strategy Planner (1-2 sprints)
1. **Launch Timeline Generator**
   - 30 dias antes: Teasers + snippets
   - 7 dias antes: Pre-sale links
   - Release day: Full push + all platforms
   - 7 dias depois: Follow-up + compilation opportunities

2. **Content Sequence**
   - Auto-gera conteúdo para cada passo
   - Integra com Editorial Calendar

### FASE 4: AI Advisor Chat (2-3 sprints)
1. **LLM Integration** (Gemini API ou OpenAI)
   - Context-aware (conhece todo histórico do user)
   - Personalized advice

2. **Chat Interface**
   - Message history
   - Suggested prompts

---

## 📊 CURRENT APP FLOW

```
Dashboard (6 tabs)
├── Dashboard (social pulse, gigs, tasks)
├── Creation (studio multi-feature)
├── Profile (artist info + integrations)
├── Events (COMING SOON)
├── Messages (COMING SOON)
└── Settings

Creation Studio
├── Social Media Specialist (diagnóstico)
├── Performance Analytics (métricas)
├── Editorial Calendar (conteúdos planejados)
├── Content Draft Lab (generator)
└── Cover Design Studio (multi-plataforma)
```

---

## 🚀 QUICK STATS

- **Total Models**: 10 SwiftData entities
- **Services**: 5 main generators/analyzers
- **UI Screens**: 15+ views
- **Integrations**: Instagram OAuth (+ Spotify, YouTube prep)
- **Platforms Supported**: 12 (for covers)
- **Lines of Code**: ~4,500 Swift

---

## 🔧 TECH DECISIONS

### Why SwiftData?
- Native, modern, no CoreData hassle
- Automatic change tracking
- Query system is clean and type-safe

### Why Mock Backend First?
- Faster iteration
- No API keys stored in app
- Easy to switch to real APIs later

### Why Offline-First Architecture?
- Works without internet (except OAuth)
- Performance: instant data access
- Privacy: data stays on device

### Why Enum-Based Services?
- Stateless, functional approach
- Easy to test
- No state management complications

---

## 💡 UNIQUE VALUE PROPOSITIONS

1. **Social Media Intelligence**: App não só gera conteúdo, recomenda QUAL tipo baseado em histórico
2. **Booking Helper**: Transforma spreadsheet manual em smart workflow com sugestões
3. **Multi-Platform Design**: Não é só template - gera recomendações específicas para CADA plataforma
4. **Learning System**: App fica mais inteligente conforme o DJ usa
5. **Privacy**: Tudo local, no device, sem rastracking

---

## ⚡ PRÓXIMAS AÇÕES (DO USUÁRIO)

```bash
# Build atual
cd /Users/franciscomarcondes/Downloads/IOSSimuladorStarter
xcodebuild -project PsyManager.xcodeproj -scheme PsyManager \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Se quiser testar no Xcode
open PsyManager.xcodeproj
# ⌘ + R para buildar e rodar
```

---

## 📝 COMANDOS ÚTEIS (PRÓ DESENVOLVIMENTO)

### Reset de dados (para testar onboarding)
```swift
// Em PsyManagerApp.swift, remova ArtistProfile da seeding
```

### Simular um novo artista
```swift
// EditarArtistProfile com novos valores
// Rodar seeding novamente
```

### Testar Instagram OAuth
```bash
# Terminal 1: Start backend
npm --prefix backend-example run dev

# Terminal 2: Build app
xcodebuild ... build

# Clique em "Conectar Instagram" dentro do app
```

---

## 🎯 VISÃO: ONDE ISSO LEVA

**Ano 1**: MVP consolidado - DJ tem ferramenta completa para conteúdo + bookings + análise

**Ano 2**: IA real - Chat que conhece tudo sobre o artista + market, dá conselhos estratégicos

**Ano 3**: Community - DJs colaboram, compartilham estratégias, marketplace de templates

**Ano 4**: Agency - PsyManager oferece managed services: "Deixa que a gente gerencia seu crescimento"

---

**Status Final**: App em estado sólido de MVP, pronto para:
- Usuários reais testarem
- Coleta de feedback
- Refinement iterativo
- Feature expansion baseado em necessidade
