# 🚀 PROMPT COPILOT: PsyManager - DJ Manager App (Versão Concisa)

## RESUMO EXECUTIVO
Criar **PsyManager** - assistente iOS para DJs/produtores independentes (nicho psytrance). App como manager virtual: estratégia de conteúdo, bookings, análise de performance, design de capas para múltiplas plataformas, e descoberta de eventos.

---

## TECNOLOGIA
- **Framework**: SwiftUI + SwiftData
- **Backend**: Node.js/Express (OAuth + insights)
- **Arquitetura**: MVVM, feature-based
- **Persistência**: Local-first (SwiftData)
- **Auth**: Instagram OAuth (+ Spotify/Apple/SoundCloud ready)

---

## USUÁRIOS & PROBLEMAS
**Quem**: DJ solo, crescimento orgânico, sem equipe  
**Dor**: Criar conteúdos manualmente, buscar eventos em planilha, não saber qual conteúdo funciona, negociar bookings sozinho  
**Solução**: Um app que automatiza, organiza, aprende e recomenda

---

## 6 SEÇÕES PRINCIPAIS

### 1️⃣ DASHBOARD
- Social pulse (seguidores crescimento, recomendação semanal)
- Próximos shows com countdown
- Tasks da semana
- Quick stats (conteúdos publicados, contatos feitos)

### 2️⃣ CREATION STUDIO (Estúdio Criativo)
**2A: Social Media Strategist**
- Diagnóstico automático (crescimento baixo/alto, reach/post, engagement)
- Recomendações inteligentes (qual pilar focar - ex: "Autoridade de Pista está +9.5% engagement")
- Sprint semanal com ações priorizadas (content, reach, bookings)
- Hooks e CTAs contextualizados ao artista

**2B: Performance Analytics**
- Qual formato performa melhor (Reel vs Carrossel vs Story)?
- Qual objetivo (Alcance, Seguidores, Booking) gera resultados?
- Qual pilar/tema de conteúdo engaja mais?
- Auto-recomendação: "Próximo conteúdo deve ser Reel, objetivo Alcance, pilar Processo Criativo"

**2C: Editorial Calendar**
- Visualizar conteúdos planejados
- Status workflow: Rascunho → Planejado → Publicado → Concluído
- Editar status + capturar métricas ao publicar
- Integração com SocialContentAnalytics

**2D: Content Draft Lab**
- Input: Objetivo (3 opções) + Formato (3 opções) + Pilar (4 opções)
- Output: Hook, Legenda, CTA, Hashtags automáticos
- Contexto-aware (usa genre, city, tone of voice do artista)
- Salva direto no calendário

**2E: Cover Design Studio** ⭐ (O diferencial)
- Selecionar múltiplas plataformas: Spotify, Apple Music, SoundCloud, Bandcamp, Reel, TikTok, Instagram Story, YouTube, Discord, Beatsport, Twitch
- Input: Nome da faixa + Mood (energético, melancólico, experimental, groovy, dark)
- Output POR PLATAFORMA:
  * Dimensões exatas (ex: 1080x1920px)
  * Paleta de cores (primária, secundária, acentuada, fundo) + rationale
  * Composição visual (layout, tipografia, elementos)
  * Motivos visuais (fractais, waveforms, etc - contextual ao gênero)
  * Dicas design específicas

### 3️⃣ BOOKING MANAGER (Gerenciador de Bookings)
- Event Discovery: Mapa interativo por estado + lista de eventos
- Contact Management: Promoters/organizers com histórico
- Message Control: Histórico de msgs, status de lead (contacted/negotiating/booked)
- Workflow suggestions: "72h sem resposta? Enviar follow-up com nova abordagem"
- Negotiation Tracker: Oferta vs desejado, timeline de propostas

### 4️⃣ EVENTS DISCOVERY (Descoberta de Eventos)
- Visualização por estado (mapa ou lista)
- Filtrar por data, gênero, capacidade
- Encontrar organizers no Instagram
- Ver histórico de contatos prévios com esse organizador

### 5️⃣ PROFILE
- Artist profile (nome, gênero, city, tom, identidade visual)
- Instagram connection (OAuth + sync de insights semanal)
- Preferences (notificações, idioma, integrations)

### 6️⃣ MESSAGES/CHAT (Future: com IA)
- Histórico de mensagens com promoters
- Templates sugeridos (1ª abordagem, follow-up 48h, negociação, rejeição amigável)
- Learning system: aprende qual mensagem funciona

---

## MODELOS DE DADOS (SwiftData @Model)

```
ArtistProfile (nome, gênero, city, tone)
SocialInsightSnapshot (followers, reach, impressions, reel_views)
SocialContentPlanItem (título, tipo, objetivo, status, data, pillar, hook, caption, cta, hashtags)
SocialContentAnalytics (likes, comments, shares, reach, engagement_rate)
EventLead (nome, city, data evento, venue, instagram_handle, status)
PromoterContact (nome, city, instagram_handle, phone, email, notas)
Negotiation (stage, oferta, desejado, próxima_ação_data)
Gig (título, city, data, fee, contato)
CareerTask (título, detalhe, prioridade, data)
MessageTemplate (título, corpo, categoria, is_favorite)
```

---

## SERVIÇOS (Logic Layer)

**SocialMediaStrategist** - Diagnóstico e recomendações
- `buildReport(profile, snapshots)` → estratégia completa

**ContentPerformanceAnalyzer** - Análise de performance
- `analyzeByContentType()`, `analyzeByObjective()`, `analyzeByPillar()`
- `generateRecommendation()` → próximo conteúdo sugerido

**SocialContentGenerator** - Geração de drafts
- `generate(profile, objetivo, pilar, tipo)` → hook, caption, cta, hashtags

**CoverDesignGenerator** - Recomendações visuais
- `generateForTrack(trackName, profile, format, mood)` → design specs por plataforma

**ContentStatusUpdater** - Workflow de status
- Transições validadas: Rascunho → Planejado → Publicado → Concluído
- Captura de métricas ao publicar

---

## DESIGN
- **Cores**: Cyan (#00D4FF), Purple (#9945FF), Magenta (#FF00FF), Dark background (#0A0A0A)
- **Style**: Dark mode psytrance (constant), custom components (PsyCard, PsyStatusPill, PsySectionHeader)
- **Animation**: Subtle fades, smooth transitions

---

## ROADMAP

**MVP (v1.0)** ✅ Mostly Done
- Dashboard, Creation Studio (todos sub-features), Cover Design, Profile, Integrations

**v1.5**
- Event Discovery functionality completa
- Booking Manager completo
- Track Feedback Engine (BPM analysis, loudness, structure)

**v2.0**
- Real IA chat advisor (Gemini/OpenAI)
- Multi-platform integrations (Spotify, Apple Music distributions)
- Learning system (analytics avançado)

---

## O QUE TORNA ESPECIAL

1. **Smart Content**: App não só gera, recomenda QUAL tipo de conteúdo baseado em histórico de performance
2. **Multi-Plataforma Design**: Não é template genérico - gera recomendações específicas por plataforma (Spotify ≠ YouTube)
3. **Booking Automation**: Transforma manual spreadsheet into smart workflow com sugestões contextuais
4. **Learning System**: App melhora conforme o DJ usa (rastreia o que funcionou)
5. **Local-First Privacy**: Tudo no device, sem tracking

---

## PRÓXIMAS AÇÕES

1. **Phase 1**: Implementar Events Discovery (visualização de eventos por estado)
2. **Phase 2**: Booking Manager completo (message control + follow-up logic)
3. **Phase 3**: Track Feedback Engine (análise técnica de faixas)
4. **Phase 4**: AI Chat Advisor (com contexto histórico do artista)

---

**Contexto**: Cliente é DJ/produtor de psytrance em crescimento. App será seu manager virtual para crescimento orgânico + negociação de bookings + estratégia de conteúdo. Foco em private, local-first, e aprendizado evolutivo.
