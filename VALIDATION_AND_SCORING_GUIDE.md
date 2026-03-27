# 🔍 VALIDAÇÃO & SCORING - GUIA COMPLETO

## O Que Mudou (v2)

### Antes ❌
```
Gera 3-5 cenários
... mas não explica como calculou
... valores são estimativas (parece mágica)
... DJ não sabe se pode confiar
```

### Depois ✅
```
Gera cenários INTELIGENTES
✓ Detecta se precisa voo mesmo (distância, não só UF)
✓ Mostra SCORE transparente (0-100)
✓ Explica POR QUÊ cada opção é recomendada
✓ Valida se é viável (DJ ganha dinheiro?)
✓ Mostra PROS/CONS para cada opção
✓ Adverte quando valores são estimativas
```

---

## 🎯 Como Funciona o Sistema Novo

### Etapa 1: Análise da Rota

```typescript
const analysis = analyzeRoute(
  "São Paulo",      // de
  "SP",
  "Rio de Janeiro", // para
  "RJ"
);

// Retorna:
{
  requiresFlight: true,
  reason: "Outro estado, 430km - voo recomendado",
  estimatedRoadDistance: 430,
  estimatedRoadTime: 6,   // horas até RJ
  isLocalEvent: false,    // Não é mesmo local
  isRegionalEvent: false, // Não é mesmo estado
  isNationalEvent: true   // É outro estado!
}
```

**Lógica Inteligente**:
- ✅ Mesmo local (SP → SP) = SÓ metrô/uber, sem voo
- ✅ Mesmo estado < 500km = SÓ rodoviário (carro/ônibus)
- ✅ Mesmo estado ≥ 500km = rodoviário ainda viável
- ✅ Outro estado ≤ 1200km = voo a considerar
- ✅ Outro estado > 1200km = voo recomendado
- ✅ > 2000km = voo obrigatório

### Etapa 2: Geração Inteligente de Cenários

**Se for Evento Local** (SP → SP):
```
Opção 1: 🚶 Metrô (R$15) - MAIS BARATO
Opção 2: 🚙 Uber (R$35)
```
→ Sem voo, porque está no mesmo prédio!

**Se for Mesmo Estado** (SP → Campinas, ~90km):
```
Opção 1: 🚗 Carro próprio (R$150) - RECOMENDADO
Opção 2: 🚙 Uber (R$250)
Opção 3: 🚌 Ônibus (R$45) - MAIS BARATO
```
→ Sem voo, porque é dia mesmo (volta em 2-3h)

**Se for Outro Estado** (SP → RJ, 430km):
```
Opção 1: 🚙 Uber + Voo + Uber (R$1.030) ⭐
Opção 2: 🚲 Metrô+Ônibus+Voo+Ônibus (R$752) 💚
Opção 3: 🚗 Carro+Estacionamento+Voo (R$1.150)
```
→ Todas com voo, porque é longe demais pra dirigir

---

## 📊 Sistema de Validação

### O que Valida?

```typescript
const validation = validateScenario(scenario, gigFee);
```

**Verifica**:

| Validação | O Quê | Exemplo |
|-----------|-------|---------|
| Missing Data | Faltam valores? | "Falta custo de transporte" |
| Cost Realism | Preço realista? | Voo < R$200 = ALERTA |
| Viability | Dá pra ganhar? | Se logística > cache = INVIÁVEL |
| Assumptions | O que assumimos | "Voo estimado em R$650" |
| Warnings | Avisos | "Logística= 70% do cache" |

### Exemplo de Validação

```
Cenário: Uber + Voo
├─ Custo total: R$ 1.030
├─ Cache: R$ 2.500
├─ Lucro: R$ 1.470 ✅
├─ Confidence: HIGH
├─ Assumptions:
│  └─ "Voo doméstico estimado ~R$650 (busque Skyscanner)"
└─ Warnings: NONE
```

### Confidence Levels

- 🟢 **HIGH**: Todos dados presentes, sem avisos
- 🟡 **MEDIUM**: Alguns dados estimados, 1-2 avisos
- 🔴 **LOW**: Muitos dados faltam ou avisos críticos

---

## ⭐ Sistema de Scoring (40+30+20+10)

### Os 4 Fatores Ponderados

```
SCORE GERAL (0-100)
├─ 💰 CUSTO (40%) - Mais barato = melhor
├─ 🛋️ CONFORTO (30%) - Carro/Uber > Ônibus/Metrô
├─ ✓ VIABILIDADE (20%) - Cabe no orçamento? Deixa margem?
└─ ⚡ VELOCIDADE (10%) - Voo > Rodo, menos conexões
```

### Exemplo Prático

```
CENÁRIO: Uber + Voo (SP → RJ)

Custo (40%):
├─ R$ 1.030 = Score 85/100 (relativamente barato)
├─ Ponderação: 85 × 0.40 = 34 pontos

Conforto (30%):
├─ Uber + Voo = Score 80/100 (confortável)
├─ Ponderação: 80 × 0.30 = 24 pontos

Viabilidade (20%):
├─ Lucro: R$ 1.470 (ótimo)
├─ Score: 100/100 (muito viável)
├─ Ponderação: 100 × 0.20 = 20 pontos

Velocidade (10%):
├─ Voo = Score 85/100 (rápido)
├─ Ponderação: 85 × 0.10 = 8,5 pontos

───────────────────
SCORE FINAL: 34 + 24 + 20 + 8.5 = 86,5 → 86/100 ⭐
```

### Interpretação do Score

| Score | Interpretação | Recomendação |
|-------|---------------|--------------|
| 80-100 | ⭐ ÓTIMO | Escolha esta! |
| 60-79 | ✓ BOM | Viável, considere |
| 40-59 | ~ ACEITÁVEL | Funciona, mas... |
| 0-39 | ⚠️ RISCO | Evite se possível |

---

## 💡 O Que DJ Vê (Interface)

### Vista Expandida de 1 Cenário

```
╔══════════════════════════════════════════╗
║ #1. 🚙 Uber + Voo + Uber               ║
║ Uber até aeroporto + voo + Uber no dest║
╚══════════════════════════════════════════╝

SCORE GERAL: 86/100 ⭐ ÓTIMO

Breakdown:
├─ 💰 Custo: 85/100 (40%)
├─ 🛋️ Conforto: 80/100 (30%)
├─ ✓ Viabilidade: 100/100 (20%)
└─ ⚡ Velocidade: 85/100 (10%)

Custo Total: R$ 1.030
Lucro Estimado: R$ 1.470

💡 Uber + Voo oferece melhor custo-benefício (R$1.030
   com ótimo conforto)

✅ VANTAGENS:
• Transporte confortável
• Preço equilibrado
• Deixa boa margem de lucro

⚠️ POSSÍVEIS DESVANTAGENS:
• Voo pode sofrer atrasos

[EXPAND FOR MORE DETAILS]
```

---

## 🔧 Como DJ Usa Isso

### Fluxo Prático

```
1. DJ abre app, clica "NEGOCIAR"
   ↓
2. Preenche: cache aprovado R$ 2.500
   ↓
3. Sistema detecta: "Outro estado (SP→RJ)"
   ↓
4. CLICA: "Calcular Logística →"
   ↓
5. Sistema gera automaticamente:
   ┌────────────────────────────────┐
   │ 📍 Análise da Rota:            │
   │ Outro estado, 430km            │
   │ ~6h dirigindo (voo > rodoviário)│
   │ Recomendação: Voo é viável    │
   └────────────────────────────────┘
   
   ┌────────────────────────────────┐
   │ 🏆 Opções Classificadas:      │
   │                               │
   │ #1. Uber + Voo (86/100) ⭐   │
   │     R$ 1.030 | Lucro: R$ 1.470│
   │                               │
   │ #2. Metrô+Ônibus+Voo (72/100) │
   │     R$ 752  | Lucro: R$ 1.748 │
   │                               │
   │ #3. Carro+Estac+Voo (65/100)  │
   │     R$ 1.150| Lucro: R$ 1.350 │
   └────────────────────────────────┘
   
6. DJ CLICA na opção #1 para expandir
   ↓
7. VÊ:
   ✓ Por que é recomendado
   ✓ Vantagens e desvantagens
   ✓ Validação (é viável? bom preço?)
   ✓ Etapas se tiver multi-mode
   ↓
8. DJ CONFIRMA: "Escolho esta opção!"
   ↓
9. Sistema calcula:
   ✅ Cache: R$ 2.500
   ✅ Logística: R$ 1.030
   ✅ TOTAL: R$ 3.530
   ✅ Feliz!
```

---

## 🚨 Validações Importantes

### Alerta 1: Viabilidade Crítica

```
Se Logística > Cache:
⛔ ALERTA CRÍTICO
"Logística (R$ 2.000) > Cache (R$ 1.500)"
"Este GIG é INVIÁVEL!"
"DJ vai PERDER dinheiro!"
```

DJ pode ver logo que não vale a pena negociar esse gig.

### Alerta 2: Margem Apertada

```
Se Logística > 70% do Cache:
⚠️ AVISO MODERADO
"Logística consome 70%+ do cache"
"Pouca margem para outras despesas"
"Recomenda revisar"
```

DJ sabe que pode funcionar, mas é apertado.

### Alerta 3: Valores Irrealistas

```
Se Voo < R$ 200:
⚠️ PREÇO SUSPEITO
"Voo muito barato (< R$200)"
"Pode ser irrealista"
"Use Skyscanner para confirmar"
```

Previne DJ de cair em armadilha de preço baixo simulado.

---

## 📋 Campos Expandidos (Para Validação)

O gig agora tem:

```typescript
gig.logisticsRequired: boolean;        // Precisa calcular?
gig.logisticsScenarios: [...]           // 3-5 opções
gig.selectedLogisticsScenarioId: string // Qual escolheu?
gig.totalLogisticsCost: number;         // Custo final
gig.cacheApprovedByEvent: number;       // Cache que evento aprovou
gig.cacheApprovedAt: Date;              // Quando aprovou
gig.eventAskedAboutAgency: boolean;     // Se perguntou agência
gig.negotiationNotes: string;           // Notas livres
```

Com isso, sistema valida:
- ✅ Cache > 0?
- ✅ Logística <= Cache?
- ✅ Tem margem de lucro?
- ✅ Campos necessários preenchidos?

---

## 🎓 Exemplos de Uso Real

### Exemplo 1: Evento Local (Inviável?)

```
DJ: "Gig em São Paulo (mesma cidade)"
Cache: R$ 500

Sistema:
├─ Detecta: "Evento local"
├─ Oferece: Metrô (R$15) ou Uber (R$35)
├─ Validação: ✅ VIÁVEL
│  └─ Lucro: R$ 465 (metrô) ou R$ 465 (uber)
├─ Score: Metrô 88/100, Uber 75/100
└─ Recomendação: ⭐ Escolha Metrô (mais economico)
```

### Exemplo 2: Evento Longe (Ambíguo?)

```
DJ: "Gig em Guarulhos (mesmo estado, ~30km)"
Cache: R$ 800

Sistema:
├─ Detecta: "Mesmo estado, perto"
├─ Oferece: 
│  ├─ Carro (R$ 100)
│  ├─ Uber (R$ 90)
│  └─ Ônibus (R$ 30)
├─ Validação: ✅ TODAS VIÁVEIS
├─ Scores: Ônibus 91/100, Uber 78/100, Carro 72/100
└─ Recomendação: ⭐ Ônibus! (mais barato, ainda rápido)
```

### Exemplo 3: Evento Distante (Necessário Voo?)

```
DJ: "Gig em Brasília (outro estado, ~1.100km)"
Cache: R$ 3.000

Sistema:
├─ Detecta: "Outro estado, distante"
├─ requiresFlight: true (razão: 1.100km > 800km)
├─ Oferece 3 opções COM voo
│  ├─ Uber+Voo (R$ 1.050) → Score 87 → Lucro R$ 1.950
│  ├─ Público+Voo (R$ 800) → Score 78 → Lucro R$ 2.200
│  └─ Carro+Voo (R$ 1.200) → Score 71 → Lucro R$ 1.800
├─ Validação: ✅ TODAS VIÁVEIS
└─ Recomendação: ⭐ Público+Voo (MAIS lucro!)
```

---

## 💾 Dados Salvos (Para Histórico)

Cada vez que DJ calcula, sistema salva:

```typescript
{
  id: "uuid",
  fromCity: "São Paulo",
  toCity: "Rio de Janeiro",
  fromState: "SP",
  toState: "RJ",
  fromAddress: "Rua X, 123",  // Se fornecido
  toAddress: "Rua Y, 456",
  eventDateISO: "2026-04-15",
  distanceKm: 430,
  tripType: "round-trip",
  
  // Cenário selecionado
  selectedScenarioId: "national-uber-flight",
  selectedScenarioName: "Uber + Voo",
  totalCost: 1030,
  
  // Para futuro machine learning
  djSelectedReason: "Melhor custo-benefício",
  actualCostIfKnown: 980,  // DJ pode atualizar depois
  feedback: "Voo atrasou, mas valeu",
  
  createdAtISO: "2026-04-01...",
  usedAtISO: "2026-04-15...",
}
```

Com histórico, sistema aprende:
- Quais cenários DJ escolhe
- Se as estimativas foram corretas
- Quais transportes funcionam melhor

---

## 🎯 Conclusão

**Antes**: "Melhor opção" parecia mágica
**Depois**: DJ entende EXATAMENTE por quê

- ✅ Score 0-100 transparente
- ✅ 4 fatores ponderados
- ✅ Validação clara
- ✅ Pros/cons explícitos
- ✅ Avisos de risco
- ✅ Histórico para aprender
- ✅ Tudo documentado

**DJ fica seguro.** 🎉

