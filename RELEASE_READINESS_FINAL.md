# Release Readiness Final - App + Web

Data: 2026-03-25

## Resultado executivo
- Build iOS: OK (BUILD SUCCEEDED)
- Build Web: OK (Next.js build + TypeScript OK)
- Etapas 1-5: implementadas em App e Web

## Evidencias tecnicas
- App iOS compilando localmente com `xcodebuild` no projeto `PsyManager.xcodeproj`
- Web compilando com `npm run build` e rotas ativas, incluindo `api/workspace/sync-health`

## Checklist de homologacao comercial

### App iOS
- [ ] Abrir Dashboard e validar score de prontidao comercial
- [ ] Testar Manager IA (enviar pergunta + resposta)
- [ ] Testar acoes rapidas no Manager
- [ ] Testar fluxo de conteudo (ideia -> roteiro -> agendado -> publicado)
- [ ] Testar eventos/booking com follow-up
- [ ] Testar sincronizacao apos alterar dados em 2 modulos

### Web
- [ ] Abrir Dashboard e validar blocos Etapa 2, 3, 4 e 5
- [ ] Validar painel de saude de sync (taxa, falhas, latencia)
- [ ] Testar briefing IA e atalho de follow-up
- [ ] Testar busca de eventos com filtro de datas
- [ ] Testar persistencia apos refresh (dados mantidos)

### Comercial / Go-Live
- [ ] Definir owner de suporte para primeira semana
- [ ] Definir KPI de sucesso (ex: leads ativos, taxa de resposta, cadencia de conteudo)
- [ ] Definir plano de rollback (build anterior + checklist de reversao)
- [ ] Publicar release notes internas

## Risco residual
- Nao foram executados testes em device fisico nesta maquina (restricao de USB corporativo).
- Recomendado validar no outro MacBook via TestFlight para fechar homologacao de release.

## Conclusao
Pronto para fase final de homologacao em device real. A base tecnica esta estavel para avancar ao TestFlight e deploy web em producao.
