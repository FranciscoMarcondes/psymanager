# PsyManager

PsyManager e um aplicativo iOS focado em DJs e produtores musicais independentes, com prioridade inicial para o nicho psytrance. O produto combina CRM de bookings, assistente de carreira com IA, organizacao de calendario, criacao de conteudo e hub de inspiracao em um unico app.

## Produto

O app foi concebido para agir como parceiro operacional do artista, reduzindo trabalho manual nas frentes de:

- prospeccao de eventos
- follow-up com promoters
- planejamento de conteudo
- organizacao de gigs
- evolucao de posicionamento artistico
- criacao de materiais visuais e textos com IA

## Stack Proposta

- Swift 5
- SwiftUI
- MVVM com feature modules
- SwiftData para persistencia local
- URLSession para integracoes HTTP
- EventKit para calendario nativo
- UserNotifications para alertas inteligentes
- PhotosUI para referencias visuais
- PDFKit e UIGraphicsPDFRenderer para press kit em PDF

## IA no Manager

O Manager funciona em dois modos:

- `Real`: usa OpenAI Chat Completions quando a variavel `OPENAI_API_KEY` esta presente.
- `Fallback`: usa respostas mock locais quando a chave nao estiver configurada.

Para desenvolvimento local com IA real, defina `OPENAI_API_KEY` no ambiente de execucao do esquema no Xcode (Edit Scheme -> Run -> Arguments -> Environment Variables).

## Direcao de Arquitetura

- `App`: bootstrap, roteamento global e dependencia raiz
- `Core`: design system, networking, persistencia, analytics, notificacoes, abstractions de IA
- `Features`: modulos isolados por capacidade de negocio
- `Domain`: entidades de negocio, casos de uso, protocolos
- `Services`: adaptadores externos como IA, calendario, eventos, scraping/API providers

## Modulos Iniciais

- Onboarding do artista
- Dashboard semanal
- Manager Virtual com IA
- Prospeccao de eventos
- CRM de promoters e negociacoes
- Minhas gigs
- Criacao visual
- Hub de inspiracao
- Portfolio e press kit
- Configuracoes e perfil artistico

## Status Atual

Este repositorio contem um shell iOS pronto para abrir no Xcode e simular. A especificacao completa do produto, fluxo de telas, modelos de dados, componentes e integracoes esta em [docs/PsyManager-Spec.md](docs/PsyManager-Spec.md).

## Backend de Instagram

O projeto contem um backend mock em [backend-example/README.md](backend-example/README.md) para validar localmente:

- healthcheck do servico
- inicio do OAuth do Instagram via browser
- callback para o deep link `psymanager://oauth/instagram`
- sincronizacao de snapshots de insights

Como a workspace aberta no VS Code pode nao ser a pasta do app, prefira subir o backend com:

```bash
npm --prefix /Users/franciscomarcondes/Downloads/IOSSimuladorStarter/backend-example run dev
```

## Roadmap Tecnico

### Fase 1

- onboarding do artista
- perfil artistico persistido localmente
- dashboard com tarefas e resumo da semana
- CRM manual de eventos e promoters
- criacao assistida de mensagens com IA
- calendario de gigs com lembretes

### Fase 2

- gerador de conteudo com IA
- gerador de artes com referencias visuais
- hub de inspiracao com analise de reels
- metricas de prospeccao e fechamento
- press kit em PDF

### Fase 3

- aprendizado continuo por perfil
- recomendacoes automaticas semanais
- enrichment de perfil artistico por busca publica
- automacoes de follow-up baseadas em tempo e status
- sugeridor de estrategia por fase de carreira

## Proximos Passos de Implementacao

1. Renomear o target/projeto para PsyManager.
2. Criar estrutura de pastas por modulo.
3. Implementar onboarding guiado do artista.
4. Implementar entidades centrais com SwiftData.
5. Construir dashboard e fluxo de prospeccao.
6. Integrar provider de IA via camada abstrata.
