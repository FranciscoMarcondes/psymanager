# ✅ CHECKLIST DE DEPLOY - Validação Pré-Produção

## 📋 Antes de Fazer Deploy

---

## 1️⃣ PREPARAÇÃO GERAL

### 1.1 Verificar Arquivos

- [ ] Arquivo `logisticsScenarioGeneratorV2.ts` existente em:
  ```
  web-app/src/features/workspace/logisticsScenarioGeneratorV2.ts
  ```
  
- [ ] Arquivo `LogisticsScenarioExplainer.tsx` existente em:
  ```
  web-app/src/features/workspace/LogisticsScenarioExplainer.tsx
  ```

- [ ] Arquivo `GigNegotiationPanel.tsx` ATUALIZADO com:
  - [ ] Imports de V2 generator
  - [ ] Imports de Explainer component
  - [ ] Estados para showLogisticsCalculator, analysis, scenarios, etc.
  - [ ] Função `handleCalculateLogistics()`
  - [ ] Função `handleSelectLogistics()`
  - [ ] Modal com LogisticsScenarioExplainer
  - [ ] Botão "Calcular Logística"

### 1.2 Compilação Web

```bash
cd web-app

# Limpar build antigo
rm -rf .next
rm -rf out

# Instalar dependências (se necessário)
npm install

# Build
npm run build

# Verificar se passou sem erros
echo "Exit code: $?"
```

- [ ] Build completado sem erros
- [ ] Build completado sem warnings graves

### 1.3 Teste Local Web

```bash
npm run dev

# Abra http://localhost:3000
# Navegue até um GIG
# Clique em "Calcular Logística"
# Veja se modal abre
```

- [ ] Dev server iniciou sem erros
- [ ] Modal aparece ao clicar "Calcular Logística"
- [ ] Não há erros no console (F12)

---

## 2️⃣ TESTES FUNCIONAIS - WEB

### 2.1 Teste Basic Flow

1. Abra uma negociação de GIG existente
2. Preencha Cache: R$ 2.500
3. Clique "Calcular Logística"

- [ ] Modal abre em < 2 segundos
- [ ] Mostra opções rankeadas
- [ ] Cada opção tem score (0-100)
- [ ] Cada opção mostra pros/cons
- [ ] Validação aparece (warnings, confidence)

### 2.2 Teste Seleção

1. Clique em opção #1
2. Clique botão "Confirmar"

- [ ] Modal fecha automaticamente
- [ ] GIG salvo com selectedLogisticsScenarioId
- [ ] totalLogisticsCost calculado corretamente
- [ ] Área "Logística Selecionada" mostra opção correta

### 2.3 Teste Recálculo

1. Na área "Logística Selecionada", clique "Recalcular"
2. Modal reabre
3. Selecione outra opção

- [ ] Modal reabre
- [ ] Opção anterior mantém marcação
- [ ] Opção nova pode ser selecionada
- [ ] GIG atualiza corretamente

### 2.4 Teste Edge Cases

**Evento Local (SP → SP)**:
```
Cache: R$ 500
↓
Espera: Opções SEM voo (metrô, uber)
Espera: Nenhuma opção com "Voo"
```
- [ ] Sem opções com voo

**Cache Muito Baixo** (SP → RJ, Cache: R$ 300):
```
Espera: Opção marcada com ⚠️ INVIÁVEL
Espera: Warnings: "Logística > cache"
Espera: Confidence: LOW
```
- [ ] Validação mostra inviabilidade
- [ ] Score visual em vermelho

**Múltiplas Renegociações**:
```
1. Calcular com cache R$ 1.000
2. Salvar
3. Reabrir
4. Calcular com cache R$ 2.000
5. Ver opções diferentes
```
- [ ] Opções mudam conforme cache
- [ ] Histórico preservado

---

## 3️⃣ TESTES FUNCIONAIS - iOS

### 3.1 Setup

```bash
cd iOS-app

# Compile
xcodebuild build-for-testing \
  -scheme DJSimples \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

- [ ] Compilação sem erros
- [ ] Simulador inicia

### 3.2 Test 1: Local Event

1. Abra app
2. Crie novo gig (mesma cidade)
3. Preencha cache R$ 500
4. Clique "Calcular Logística"

- [ ] Sheet abre
- [ ] Mostra 2 opções (metrô, uber)
- [ ] Sem voo em nenhuma
- [ ] Score > 80

### 3.3 Test 2: National Event

1. Crie gig (outro estado)
2. Cache R$ 2.500
3. Clique "Calcular Logística"

- [ ] Sheet abre em < 3s
- [ ] Mostra 3 opções
- [ ] Todas com voo
- [ ] Score distribuído (70-85)

### 3.4 Test 3: Selection & Save

1. Selecione opção #2
2. Clique "Confirmar"
3. Volte à tela anterior

- [ ] Sheet fecha
- [ ] Opção selecionada aparece
- [ ] Dados salvos (SwiftData)
4. Releia GIG do banco

- [ ] `selectedLogisticsScenario` contém dados corretos
- [ ] `totalLogisticsCost` preenchido

### 3.5 Test 4: Recalculate

1. Na tela de GIG, clique "↻ Recalcular"
2. Sheet reabre
3. Selecione opção diferente

- [ ] Sheet reabre
- [ ] Opção anterior ainda marcada
- [ ] Pode mudar seleção
- [ ] Dados atualiizam

---

## 4️⃣ VALIDAÇÃO DE DADOS

### 4.1 Verificar Tipos TypeScript

```bash
cd web-app

# Type check
npx tsc --noEmit

# Reparar se tiver erros
```

- [ ] Sem erros de tipo
- [ ] LogisticsScenario tem todos campos
- [ ] RouteAnalysis tem todos campos
- [ ] ScenarioValidation tem todos campos

### 4.2 Verificar Dados Persistência

**Web (Banco de Dados)**:

```sql
-- Verificar que campo `selectedLogisticsScenarioId` existe
SELECT * FROM gigs LIMIT 1\G
```

- [ ] Coluna `selectedLogisticsScenarioId` existe
- [ ] Coluna `totalLogisticsCost` existe
- [ ] Coluna `logisticsRequired` existe

**iOS (SwiftData)**:

```swift
// No Xcode debugger
po try? modelContext.fetch(FetchDescriptor<Gig>())[0].selectedLogisticsScenarioId
```

- [ ] Valor salvo corretamente
- [ ] UUID is not null quando selecionado
- [ ] Data persistence funciona

### 4.3 Validar Scoring

Teste se scoring bate com fórmula (40/30/20/10):

```javascript
// Em LogisticsScenarioExplainer, inspect:
const expectedScore = 
  (costFactor * 0.40) +
  (comfortFactor * 0.30) +
  (feasibilityFactor * 0.20) +
  (speedFactor * 0.10);

// Compare com displayedScore
console.assert(
  Math.abs(expectedScore - displayedScore) < 1,
  `Scoring error: expected ${expectedScore}, got ${displayedScore}`
);
```

- [ ] Score 0-100 válido
- [ ] Fórmula 40/30/20/10 aplicada
- [ ] Sem valores NaN

---

## 5️⃣ PERFORMANCE

### 5.1 Web Performance

```bash
# Medir tempo de geração
npm run dev

# No browser console:
console.time('calculate');
handleCalculateLogistics();
console.timeEnd('calculate');
```

- [ ] < 1s para evento local
- [ ] < 2s para evento regional
- [ ] < 3s para evento nacional

**Se mais lento**: Implementar cache/API backend

### 5.2 iOS Performance

- [ ] Sheet abre em < 2s
- [ ] Não congela UI
- [ ] Não causa memory leak
- [ ] Simulador não aquece

**Teste Memory**:
```swift
// Xcode → Debug → Memory Graph
// Verificar que não cresce indefinidamente
```

---

## 6️⃣ CONFORMIDADE

### 6.1 Validação de Regras de Negócio

- [ ] Cenário com logística > cache bota warning "INVIÁVEL"
- [ ] Score sempre entre 0-100
- [ ] Pelo menos 2 opções geradas (local/regional)
- [ ] Pelo menos 3 opções geradas (nacional)
- [ ] Todos cenários validados (sem exceções)

### 6.2 Segurança

- [ ] Sem console.log() em produção (valores sensíveis)
- [ ] Sem hardcoded values (use env vars)
- [ ] Validação de entrada (gigFee > 0?)
- [ ] Sem SQL injection (se tiver backend)

**Verificação**:
```bash
# Buscar console.log
grep -r "console.log" web-app/src/features/workspace/

# Se encontrou muitos, limpar
```

### 6.3 Acessibilidade (Web)

```bash
# Instalar axe DevTools
# Rodar sobre modal de logística
# Verificar se passa em Level AA
```

- [ ] Sem violations críticas
- [ ] Labels descritivos
- [ ] Tab order lógico
- [ ] Contrast ratio OK

---

## 7️⃣ DOCUMENTAÇÃO & RELEASE NOTES

### 7.1 Verificar Documentação

- [ ] README.md atualizado com V2
- [ ] CHANGELOG.md menciona:
  - [ ] "Novo: Sistema de validação transparente"
  - [ ] "Novo: Scoring inteligente (40/30/20/10)"
  - [ ] "Novo: Detecção automática de necessidade de voo"
  - [ ] "Fix: Edge cases em múltiplas renegociações"

### 7.2 Release Notes para DJ

```markdown
# 🎉 Novidade: Logística Inteligente v2

## O Que Mudou?
- ✨ Sistema de scoring transparente (0-100)
- ✨ Validação automática de viabilidade
- ✨ Melhor detecção de quando voo é necessário
- ✨ Pros/cons para cada opção

## Como Usar?
1. Preencha cache aprovado
2. Clique "Calcular Logística"
3. Veja opções rankeadas
4. Selecione a melhor

## Novo Features
- "Expandir" cada opção para ver detalhes
- "Como funciona?" para entender scoring
- Avisos auromáticos se inviável
```

- [ ] Release notes criado
- [ ] Enviado para time de marketing

---

## 8️⃣ PREPARAÇÃO FINAL

### 8.1 Branches & PRs

```bash
# No repositório:
git branch -a | grep -E "logistics|v2|validation"

# Verificar PRs:
# - Todos PRs revisados? ✓
# - Todos testes passaram? ✓
# - Sem conflitos merge? ✓
```

- [ ] Feature branch criado: `feat/transparent-logistics-v2`
- [ ] PR aberto com descrição
- [ ] Pelo menos 1 revisão aprovada
- [ ] Todos testes (unit/integration) passando

### 8.2 Rollback Plan

- [ ] Entender como reverter se necessário
- [ ] Ter backup de banco (antes de deploy)
- [ ] Documentar rollback steps:
  ```bash
  # Se precisar reverter:
  git revert <commit-hash>
  npm run build
  vercel deploy --prod
  ```

- [ ] Rollback procedure documentado

### 8.3 Monitoramento

- [ ] Sentry/LogRocket configurado
- [ ] Alertas para erros críticos
- [ ] Dashboard de métricas pronto (analytics)
- [ ] Contato de on-call definido

---

## 📋 CHECKLIST FINAL - ANTES DO BOTÃO VERDE

### Web Checklist

- [ ] `npm run build` → OK (sem erros)
- [ ] `npm run test` → OK (se tiver testes)
- [ ] Teste local → modal abre, calcula, salva
- [ ] Teste edge case (cache baixo) → valida
- [ ] Performance → < 3s
- [ ] Types → sem erros
- [ ] Console → sem erro crítico
- [ ] Storage → dados salvam

### iOS Checklist

- [ ] `xcodebuild build` → OK
- [ ] Simulador → build roda
- [ ] Sheet abre → < 2s
- [ ] Selection salva → SwiftData atualiza
- [ ] Memory → sem leak
- [ ] No crashes

### Meta Checklist

- [ ] Docs atualizadas
- [ ] Release notes pronto
- [ ] PR aprovado
- [ ] Rollback plan documentado
- [ ] Monitoramento configurado

---

## 🚀 GO/NO-GO DECISION

### Podemos fazer deploy?

```
CRITÉRIO DE SUCESSO:

✅ Funcional
  - [ ] Modal abre corretamente
  - [ ] Calcula cenários (E SEM ERRO)
  - [ ] Valida corretamente
  - [ ] Salva dados

✅ Performance
  - [ ] < 3s para calcular
  - [ ] Sem UI freeze
  - [ ] Sem memory leak

✅ Segurança
  - [ ] Sem console.log sensível
  - [ ] Validação de entrada

✅ Documentação
  - [ ] Docs atualizadas
  - [ ] Release notes pronto

✅ Aprovação
  - [ ] 1+ aprovações de PR
  - [ ] Check-in com PO (DJ)
  - [ ] Nenhuma issue crítica aberta
```

---

## 🎬 DEPLOY STEPS

### 1. Environment Check

```bash
# Verificar estamos na branch correta
git branch

# Verificar versão
npm --version  # >= 16.0
node --version # >= 18.0
```

### 2. Final Build

```bash
# Web
cd web-app
npm run build
npm run test

# iOS (Xcode)
# Product → Build → Success
```

### 3. Deploy

**Web (Vercel)**:
```bash
vercel deploy --prod
```

**Web (Self-hosted)**:
```bash
npm run build
# Copy `out/` ou `.next/` para servidor
npm start  # ou seu PM2 config
```

**iOS (TestFlight first)**:
```
Xcode → Product → Archive
↓
Organizer → Upload
↓
TestFlight (2h esperar aprovação)
↓
Internal testing → Verificar
↓
App Store Connect → Submit (ou direto pra App Store)
```

### 4. Smoke Tests

- [ ] Abri app/web
- [ ] Consegui navegar até GIG
- [ ] Modal abre

### 5. Comunicar

- [ ] Avisa DJ em Slack/email
- [ ] Menciona novo feature em newsletter
- [ ] Marca em Jira/Linear como DONE

---

## 📞 TROUBLESHOOTING POS-DEPLOY

### Se tiver erro CRÍTICO:

1. **Immediate Rollback**:
   ```bash
   git revert <deployed-commit>
   npm run build
   vercel deploy --prod
   ```

2. **Notify DJ**: "Desculpa, encontramos erro. Revertemos. Tentaremos semana que vem."

3. **Post-mortem**: Por que passou QA mas falhou em produção?

---

## ✅ Pronto para Deploy!

Se todos itens estão marcados ✅, você pode:

```bash
git push origem main
# ou
vercel deploy --prod
```

**Boa sorte! 🚀**

