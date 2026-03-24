# PsyManager - Especificacao Tecnica e Estrutural

## 1. Visao do Produto

PsyManager e um manager digital de carreira para DJs e produtores independentes, com foco inicial em psytrance. O objetivo nao e apenas organizar informacoes, mas operar como um parceiro inteligente que entende posicionamento artistico, ajuda a vender bookings, melhora comunicacao com promoters, organiza a rotina e sugere estrategias de crescimento.

### Principios de Produto

- o artista trabalha sozinho
- o app deve reduzir atrito operacional
- IA deve agir como parceira de negocio, nao como chat generico
- o nicho psytrance exige linguagem, visual e referencias especificas
- tudo precisa ser rapido de usar no celular

## 2. Arquitetura Completa do Aplicativo

### 2.1 Estilo Arquitetural

Arquitetura recomendada: `SwiftUI + MVVM + Domain-driven feature modules + Services layer`.

Estrutura:

- `App`
  - entry point do aplicativo
  - injecao de dependencias raiz
  - navegacao global
- `Core`
  - design system
  - networking
  - persistencia
  - logging
  - notificacoes
  - wrappers de frameworks Apple
- `Domain`
  - entidades
  - enums de negocio
  - regras centrais
  - casos de uso
- `Features`
  - modulos de tela e fluxo
- `Services`
  - IA de texto
  - IA de imagem
  - providers de eventos
  - calendario nativo
  - pdf export

### 2.2 Estrutura Sugerida de Pastas

```text
PsyManager/
  App/
    PsyManagerApp.swift
    AppRouter.swift
    AppDependencies.swift
  Core/
    DesignSystem/
    Navigation/
    Networking/
    Persistence/
    Notifications/
    Analytics/
    Utilities/
  Domain/
    Entities/
    Enums/
    UseCases/
    Repositories/
  Services/
    AI/
      TextAI/
      ImageAI/
      Prompting/
      Memory/
    Events/
    Calendar/
    PDF/
    Media/
  Features/
    Onboarding/
    Dashboard/
    ManagerAI/
    ContentStudio/
    ArtworkGenerator/
    EventDiscovery/
    PromoterCRM/
    Gigs/
    InspirationHub/
    Portfolio/
    Settings/
  Resources/
    Assets.xcassets/
    Localizable.xcstrings
```

### 2.3 Camadas de Responsabilidade

- `View`: renderizacao, interacoes e estados de apresentacao
- `ViewModel`: orquestracao de acoes, carregamento, validacoes, mapping para view state
- `UseCase`: regras de negocio com foco em tarefas completas
- `Repository`: interface de dados local/remoto
- `Service`: integracoes externas e adaptadores nativos

### 2.4 Persistencia

Persistencia local com `SwiftData` para:

- perfil artistico
- memoria de preferencia da IA
- eventos prospectados
- promoters
- negociacoes
- gigs fechadas
- ideias e anotacoes
- historico de mensagens
- tarefas semanais

Sincronizacao cloud pode entrar depois via CloudKit ou backend proprio.

### 2.5 Integracao de IA

Abstracao recomendada:

- `TextAIProvider`
- `ImageAIProvider`
- `ArtistMemoryEngine`
- `PromptTemplateRepository`

Isso permite trocar entre OpenAI, Gemini e outros provedores sem reescrever as features.

## 3. Fluxo de Telas - Wireframe Textual Completo

### 3.1 Splash

- logo PsyManager
- loading rapido
- verifica se existe onboarding concluido

Saidas:

- onboarding
- dashboard

### 3.2 Onboarding Inicial do Artista

#### Tela 1 - Boas-vindas

- proposta do app
- CTA: `Construir meu manager digital`

#### Tela 2 - Identidade Artistica

- nome artistico
- nome real opcional
- genero principal
- subnicho
- cidade/estado
- stage atual: iniciante, em crescimento, consolidando, touring

#### Tela 3 - Posicionamento

- identidade visual atual
- referencias artisticas
- como quer ser percebido
- energia de palco
- tom de voz nas redes

#### Tela 4 - Objetivos

- mais gigs
- crescer Instagram
- melhorar branding
- fechar bookings em outras cidades
- organizar carreira
- lancar musica

#### Tela 5 - Conteudo

- tipos de conteudo desejados
- frequencia ideal
- dificuldade atual
- temas favoritos

#### Tela 6 - Booking e Vendas

- cache medio atual
- onde costuma tocar
- tipo de promoter ideal
- dificuldades de negociacao

#### Tela 7 - Preferencias de IA

- estilo de resposta
- tom do manager virtual
- nivel de objetividade
- aceita sugestoes automaticas?

#### Tela 8 - Resumo de Perfil

- resumo gerado pela IA
- confirmar ou editar
- CTA: `Entrar no PsyManager`

### 3.3 Dashboard Principal

Blocos:

- resumo da semana
- proxima gig
- tarefas sugeridas pela IA
- funil de prospeccao
- conteudo recomendado
- alerta de follow-up
- area de acesso rapido

Atalhos:

- falar com manager virtual
- nova prospeccao
- nova gig
- criar post
- gerar flyer

### 3.4 Manager Virtual de Carreira

#### Home do manager

- saudacao contextual
- cards de comando rapido
- historico de conversas
- sugestoes da semana

Comandos rapidos:

- criar legenda
- criar mensagem para promoter
- planejar semana
- analisar negociacao
- melhorar bio
- gerar estrategia de crescimento

#### Chat inteligente

- entrada multimodal futura
- suporte a anexar texto, print, briefing, referencia
- respostas com blocos acionaveis

Acoes a partir da resposta:

- salvar ideia
- transformar em tarefa
- enviar para CRM
- criar arte
- exportar texto

### 3.5 Content Studio

Subareas:

- posts
- reels
- carrosseis
- roteiros
- legendas
- hashtags

Fluxo:

- escolher objetivo do conteudo
- informar contexto
- receber sugestoes
- editar
- salvar no calendario de publicacao

### 3.6 Gerador de Capas e Artes

Entradas:

- prompt manual
- contexto do artista
- imagens de referencia
- objetivo da arte

Saidas:

- capa quadrada
- thumbnail vertical
- flyer de gig
- arte para stories

Fluxo:

- selecionar tipo de arte
- enviar referencia ou nao
- selecionar estilo sugerido
- gerar variacoes
- favoritar
- exportar

### 3.7 Mapeador de Eventos

Filtros:

- estado
- cidade
- periodo
- tipo de evento
- porte
- nicho/subnicho

Lista de resultados:

- nome do evento
- data
- local
- tipo
- instagram
- line-up
- status da prospeccao

Tela detalhe do evento:

- informacoes gerais
- contatos vinculados
- historico de mensagens
- sugestao da IA para abordagem
- botao `Marcar como prospectado`

### 3.8 CRM de Promoters e Negociacoes

Lista de contatos com status:

- nao contactado
- mensagem enviada
- aguardando resposta
- visualizou
- curtiu
- negociacao
- fechado
- perdido

Detalhe do promoter:

- nome
- rede principal
- historico completo
- tags
- eventos vinculados
- score de aquecimento
- textos sugeridos

Fluxos:

- primeira abordagem
- follow-up automatico assistido
- resposta a objecao
- fechamento

### 3.9 Minhas Gigs

Calendario/lista de gigs fechadas:

- data
- cidade
- fee
- contratante
- status pre-evento

Detalhe da gig:

- checklist
- observacoes
- alerta configurado
- botao adicionar ao calendario nativo

### 3.10 Hub de Inspiracao

Feed com secoes:

- reels em alta
- referencias visuais
- hooks de conteudo
- artistas semelhantes
- formatos que o usuario ainda nao explorou

Detalhe de referencia:

- porque faz sentido
- como adaptar ao seu estilo
- CTA: transformar em roteiro/post/arte

### 3.11 Portfolio e Press Kit

- fotos
- videos
- releases
- links
- destaques
- press kit PDF gerado

### 3.12 Configuracoes e Perfil

- dados do artista
- preferencias da IA
- integracoes
- notificacoes
- exportacao de dados

## 4. Modelos de Dados - Entidades e Relacionamentos

### 4.1 ArtistProfile

Campos:

- id
- stageName
- legalName
- genre
- subgenre
- city
- state
- country
- artistBio
- toneOfVoice
- audienceProfile
- visualIdentityNotes
- references
- careerGoals
- preferredContentTypes
- bookingGoals
- feeRange
- onboardingCompleted
- createdAt
- updatedAt

Relacionamentos:

- 1:N com `ContentIdea`
- 1:N com `Gig`
- 1:N com `CareerTask`
- 1:N com `AISession`
- 1:1 com `ArtistMemory`

### 4.2 ArtistMemory

Memoria consolidada da IA.

Campos:

- id
- artistProfileId
- brandSummary
- communicationStyleSummary
- negotiationStyleSummary
- topObjectivesSummary
- contentPreferenceSummary
- lastRefinedAt

### 4.3 ContentIdea

Campos:

- id
- title
- format
- objective
- hook
- outline
- captionDraft
- hashtagsDraft
- status
- source
- scheduledDate
- performanceNotes
- createdAt

Relacionamentos:

- N:1 com `ArtistProfile`
- N:1 opcional com `InspirationItem`

### 4.4 ArtworkProject

Campos:

- id
- title
- brief
- styleTags
- paletteNotes
- referenceImagePaths
- outputType
- generationPrompt
- selectedVariationPath
- createdAt

### 4.5 EventLead

Campos:

- id
- name
- eventType
- date
- city
- state
- venue
- instagramHandle
- eventURL
- lineupNotes
- source
- prospectStatus
- idealContactWindow
- notes
- createdAt
- updatedAt

Relacionamentos:

- 1:N com `PromoterContact`
- 1:N com `MessageLog`

### 4.6 PromoterContact

Campos:

- id
- name
- role
- instagramHandle
- phone
- email
- city
- relationshipTemperature
- lastContactAt
- responseRateScore
- notes

Relacionamentos:

- N:N com `EventLead`
- 1:N com `Negotiation`
- 1:N com `MessageLog`

### 4.7 Negotiation

Campos:

- id
- promoterId
- eventLeadId
- stage
- offeredFee
- desiredFee
- travelIncluded
- lodgingIncluded
- negotiationNotes
- nextAction
- followUpDate
- outcome
- createdAt
- updatedAt

### 4.8 MessageLog

Campos:

- id
- channel
- direction
- templateType
- messageBody
- sentAt
- seenAt
- reactionType
- outcomeTag

Relacionamentos:

- N:1 com `PromoterContact`
- N:1 opcional com `EventLead`
- N:1 opcional com `Negotiation`

### 4.9 Gig

Campos:

- id
- title
- date
- city
- state
- venue
- contactName
- contactPhone
- fee
- notes
- status
- soundcheckTime
- travelPlan
- introTrack
- addedToNativeCalendar

Relacionamentos:

- 1:N com `GigChecklistItem`

### 4.10 GigChecklistItem

Campos:

- id
- gigId
- title
- isCompleted
- priority

### 4.11 InspirationItem

Campos:

- id
- sourceType
- sourceURL
- title
- summary
- reasonRecommended
- adaptationIdea
- visualNotes
- savedAt

### 4.12 CareerTask

Campos:

- id
- title
- category
- priority
- dueDate
- status
- origin
- aiReason

### 4.13 WeeklyInsight

Campos:

- id
- weekStartDate
- contentSummary
- prospectingSummary
- growthSummary
- suggestedActions
- createdAt

## 5. Relacionamentos Essenciais

- um `ArtistProfile` concentra o contexto global
- `ArtistMemory` resume o aprendizado da IA
- `EventLead`, `PromoterContact`, `Negotiation` e `MessageLog` formam o CRM
- `Gig` cobre o operacional do evento ja fechado
- `ContentIdea`, `ArtworkProject` e `InspirationItem` cobrem criacao e branding
- `CareerTask` e `WeeklyInsight` conectam IA a execucao pratica

## 6. Plano de Componentes SwiftUI

### 6.1 Componentes Base

- `PMPrimaryButton`
- `PMSecondaryButton`
- `PMCard`
- `PMSectionHeader`
- `PMTag`
- `PMEmptyState`
- `PMLoadingView`
- `PMMetricTile`
- `PMAvatarView`
- `PMStatusBadge`

### 6.2 Componentes de Fluxo

- `OnboardingStepView`
- `ArtistProfileSummaryCard`
- `WeeklyFocusCard`
- `QuickActionGrid`
- `AIConversationBubble`
- `PromptSuggestionChip`
- `EventLeadRow`
- `PromoterPipelineBoard`
- `GigTimelineCard`
- `ChecklistItemRow`
- `InspirationCarousel`
- `ArtworkReferencePicker`
- `PortfolioMediaGrid`

### 6.3 Navegacao Principal

Tab bar sugerida:

- Home
- Manager
- Eventos
- Criacao
- Perfil

Stack de navegacao interna por feature.

### 6.4 ViewModels Iniciais

- `OnboardingViewModel`
- `DashboardViewModel`
- `ManagerAIViewModel`
- `EventDiscoveryViewModel`
- `PromoterCRMViewModel`
- `GigListViewModel`
- `ArtworkGeneratorViewModel`
- `InspirationHubViewModel`
- `ProfileViewModel`

## 7. Plano de APIs e Integracoes de IA

### 7.1 Camada Abstrata

Protocolos:

```swift
protocol TextAIProvider {
    func generate(request: TextAIRequest) async throws -> TextAIResponse
}

protocol ImageAIProvider {
    func generate(request: ImageAIRequest) async throws -> [GeneratedImage]
}
```

### 7.2 IA de Texto

Possiveis provedores:

- OpenAI
- Gemini
- modelo local futuro para features offline parciais

Casos de uso:

- gerar legenda
- gerar roteiro de reel
- gerar mensagem inicial para promoter
- gerar follow-up
- analisar resposta recebida
- sugerir estrategia semanal
- melhorar bio
- gerar hashtags
- resumir perfil artistico

### 7.3 IA de Imagem

Possiveis provedores:

- OpenAI Images
- Gemini Imagen via backend
- provider dedicado de imagens/flyers

Casos de uso:

- capa de post
- flyer de gig
- thumbnail
- arte de reels

### 7.4 Memoria e Aprendizado Continuo

Fluxo sugerido:

1. onboarding cria perfil inicial
2. cada interacao relevante gera sinal de preferencia
3. app resume padroes e atualiza `ArtistMemory`
4. prompts futuros incluem o resumo condensado
5. app ajusta sugestoes por historico real de uso

Campos monitorados no aprendizado:

- formatos de conteudo mais aceitos
- tipo de linguagem preferida
- objetivos mais recorrentes
- cidade/regiao de interesse
- tipo de promoter com maior taxa de resposta
- visuals preferidos

### 7.5 Event Discovery

Possibilidades tecnicas:

- cadastro manual no MVP
- scraping supervisionado via backend em fase posterior
- APIs de eventos quando disponiveis
- enrichment por Instagram/links publicos processados no backend

No app iOS, tratar apenas consumo de dados estruturados expostos por backend proprio.

### 7.6 Integracoes Apple

- `EventKit`: adicionar gigs ao calendario nativo
- `UserNotifications`: lembretes de gig, follow-up e tarefas da semana
- `ShareLink`: compartilhar legenda, press kit e artes
- `PhotosUI`: upload de referencias visuais
- `PDFKit`: gerar press kit

## 8. Regras de UX e Produto

### 8.1 Direcao de UX

- o app deve ser consultivo, nao burocratico
- toda tela importante deve terminar com proxima acao clara
- o usuario deve conseguir executar algo util em menos de 30 segundos
- linguagem visual deve refletir sofisticaçao + psicodelia controlada

### 8.2 Direcao Visual

Para o nicho psytrance:

- fundo escuro com contraste alto
- acentos neon controlados
- formas fluidas e geometricas
- cards com profundidade, brilho sutil e leitura forte
- evitar visual corporativo frio

### 8.3 Padroes de Interacao

- cards de acao rapida
- CTAs objetivos
- linguagem de assistente pessoal
- status visuais claros no CRM
- empty states com sugestao acionavel

## 9. README Tecnico Inicial do Projeto

### Nome

PsyManager

### Objetivo tecnico

App iOS nativo para DJs/produtores independentes com IA, CRM de bookings, gestao de gigs e criacao de conteudo.

### Requisitos tecnicos iniciais

- iOS 17+
- Xcode 15+
- Swift 5+
- arquitetura SwiftUI + MVVM

### Dependencias iniciais sugeridas

- sem dependencias externas no primeiro ciclo, exceto se necessario para observabilidade ou DI
- priorizar frameworks nativos da Apple

### Seguranca

- nenhuma chave de API hardcoded no app
- segredos via backend seguro ou configuracao local para desenvolvimento
- dados sensiveis com armazenamento seguro quando aplicavel

### Estrategia de backend

Backend recomendado para:

- chamadas a modelos de IA
- agregacao de eventos
- enriquecimento de perfis
- processamento de imagens
- analytics centralizados

## 10. MVP Recomendado

Escopo do MVP:

- onboarding inteligente
- dashboard semanal
- manager virtual de texto
- cadastro e acompanhamento de eventos/promoters
- geracao de mensagens com IA
- cadastro de gigs
- lembretes locais
- rascunhos de conteudo

Fica fora do MVP inicial:

- scraping avancado no proprio app
- geracao de imagem de alta complexidade on-device
- automacao total de envio em redes sociais
- analise profunda de video com pipeline pesado

## 11. Ideias Extras de Funcionalidades Inteligentes

- score de prontidao de carreira por semana
- mapa de calor de cidades com mais oportunidade
- recomendador de horario de postagem por historico
- simulador de negociacao com IA
- comparador de posicionamento entre referencias artisticas
- detector de repeticao de conteudo
- planner de lancamentos musicais integrado ao calendario
- radar de promotores mornos que valem novo contato
- modo pre-gig com checklist e foco mental
- resumo de carreira mensal em PDF
- coach de bio e branding com score evolutivo
- avaliador de identidade visual por consistencia

## 12. Ordem de Implementacao Recomendada

1. renomear projeto para PsyManager
2. configurar Design System basico
3. implementar onboarding e `ArtistProfile`
4. construir dashboard
5. implementar CRM de eventos/promoters
6. integrar `TextAIProvider`
7. implementar `Gig` + notificacoes + calendario
8. adicionar content studio
9. adicionar artwork generator
10. adicionar portfolio/press kit

## 13. Decisoes Tecnicas-Chave

- usar SwiftData no inicio para acelerar MVP
- usar backend para IA e scraping, nao embutir segredos no app
- tratar IA como conjunto de use cases, nao tela isolada
- centralizar memoria do artista em entidade propria
- priorizar automacao orientada por contexto e historico

## 14. Resultado Esperado

Quando bem executado, o PsyManager deve se comportar como:

- assistente de carreira
- CRM de bookings
- planner de conteudo
- organizador de gigs
- copiloto de branding
- fonte de inspiracao contextual

Nao apenas como uma agenda com chat.
