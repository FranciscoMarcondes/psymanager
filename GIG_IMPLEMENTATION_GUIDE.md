# 🚀 GIG JOURNEY - GUIA DE IMPLEMENTAÇÃO

## Você Alterou Isso:

### ✅ 1. Modelos de Dados (Pronto)

**iOS**: `Domain/Entities/Gig.swift`
- ✅ Adicionado `TransportMode` enum (8 modos)
- ✅ Adicionado `TransportLeg` model (etapas de viagem)
- ✅ Adicionado `LogisticsScenario` model (opções completas)
- ✅ Expandido `Gig` model com campos de negociação e logística

**Web**: `web-app/src/features/workspace/types.ts`
- ✅ Expandido `Gig` type com novos campos
- ✅ Adicionado `LogisticsScenario` type
- ✅ Adicionado `TransportLeg` type
- ✅ Expandido `TransportMode` para 8 opções

---

### ✅ 2. Lógica de Cenários (Pronto)

**Web**: `web-app/src/features/workspace/logisticsScenarioGenerator.ts`
- ✅ Função para gerar automaticamente 3-5 cenários
- ✅ Suporte: mesmo estado (road only) vs. outro estado (+ flight)
- ✅ Múltiplos modos de transporte com custo estimado
- ✅ Tags de recomendação automática ("Melhor custo", "Mais rápido", etc.)

Exemplo de uso:
```typescript
const scenarios = generateLogisticsScenarios({
  fromCity: "São Paulo",
  fromState: "SP",
  toCity: "Rio de Janeiro",
  toState: "RJ",
  eventDateISO: "2026-04-15",
  fuelPrice: 6.2,
  kmPerLiter: 10,
});

console.log(scenarios.scenarios); // [3-5 options]
console.log(scenarios.recommendedIndex); // 1 (best value)
```

---

### ✅ 3. Componentes UI (Pronto)

#### Web

**`web-app/src/features/workspace/GigNegotiationPanel.tsx`**
- ✅ Pergunta "Você tem agência?" com SIM/NAO
- ✅ Campo para cache proposto (DJ) vs. cache aprovado (evento)
- ✅ Rastreamento de notas de negociação
- ✅ Aviso automático se for outro estado (necessário cálculo de logística)
- ✅ Resumo de valor total (cache + logística)

**`web-app/src/features/workspace/LogisticsScenarioSelector.tsx`**
- ✅ Exibição visual de 3-5 cenários em cards
- ✅ Expandível para ver detalhes (custo breakdown, etapas)
- ✅ Seleção com feedback visual (border azul quando selecionado)
- ✅ Tags de recomendação coloridas
- ✅ Dicas de seleção (melhor custo, conforto, rapidez)

#### iOS

**`Features/Events/GigNegotiationFlowView.swift`**
- ✅ Fluxo guiado em etapas
- ✅ Pergunta agência com botões SIM/NAO
- ✅ Campos para cache proposto e aprovado
- ✅ Notas de negociação TextEditor
- ✅ Validação (bloqueia avanço sem cache aprovado)
- ✅ Resumo de valor em destaque (verde)

---

## 📋 PRÓXIMOS PASSOS (INTEGRAÇÃO)

### Passo 1: Conectar GigNegotiationPanel ao Booking (Web)

**Arquivo**: `web-app/src/features/workspace/BookingPanel.tsx`

```typescript
// Após clicar em um gig na lista, mostrar GigNegotiationPanel
const [negotiatingGigId, setNegotiatingGigId] = useState<string | null>(null);

// No render:
if (negotiatingGigId) {
  const gig = data.gigs.find(g => g.id === negotiatingGigId);
  return (
    <GigNegotiationPanel
      gig={gig}
      userHomeState={userHomeState}  // Get from profile
      userBaseCity={userBasCity}      // Get from profile
      onUpdate={(updatedGig) => {
        onUpdate((prev) => ({
          ...prev,
          gigs: prev.gigs.map(g => g.id === updatedGig.id ? updatedGig : g),
        }));
        setNegotiatingGigId(null);
      }}
      onGoToLogistics={() => {
        setActiveTab("logistics");
        setSelectedGigForLogistics(negotiatingGigId);
      }}
    />
  );
}
```

### Passo 2: Usar Cenários no LogisticsPanel (Web)

**Arquivo**: `web-app/src/features/workspace/LogisticsPanel.tsx`

```typescript
useEffect(() => {
  // Se gig já tem cenários pré-calculados, mostrá-los
  if (selectedGigId && data.gigs) {
    const gig = data.gigs.find(g => g.id === selectedGigId);
    if (gig?.logisticsScenarios && gig.logisticsScenarios.length > 0) {
      // Show LogisticsScenarioSelector instead of calculator
      setShowScenarioSelector(true);
      setScenarios(gig.logisticsScenarios);
    }
  }
}, [selectedGigId, data.gigs]);

// Se usário seleciona um cenário:
function handleScenarioSelected(scenario: LogisticsScenario) {
  onUpdate((prev) => ({
    ...prev,
    gigs: prev.gigs.map(g => 
      g.id === selectedGigId 
        ? { ...g, selectedLogisticsScenarioId: scenario.id, totalLogisticsCost: scenario.totalCost }
        : g
    ),
  }));
  showToast(`Cenário selecionado: ${scenario.name}`);
}
```

### Passo 3: Integrar GigNegotiationFlowView no iOS

**Arquivo**: `Features/Events/EventPipelineView.swift`

```swift
// Quando DJ clica em "Negociar" na gig:
NavigationLink(destination: GigNegotiationFlowView(
  gig: $gig,
  userHomeState: "SP",  // Get from @AppStorage or model
  userBaseCity: "São Paulo",
  onComplete: {
    // Save to SwiftData, animate back
    try? modelContext.save()
    dismiss()
  },
  onGoToLogistics: {
    // Navigate to logistics calculator
    navigateToLogisticsTab = true
  }
)) {
  HStack {
    Image(systemName: "checkmark.circle")
    Text("Negociar")
  }
}
```

### Passo 4: Popúlar Cenários Automaticamente

**Qualquer lugar que cria um novo Lead/Gig**:

```typescript
// Ao converter Lead → Negociacao
const generateInitialScenarios = async (gig: Gig) => {
  const scenarios = generateLogisticsScenarios({
    fromCity: userProfile.baseCity,
    fromState: userProfile.state,
    toCity: gig.city,
    toState: gig.state,
    eventDateISO: gig.dateISO,
    fuelPrice: 6.2,
    kmPerLiter: 10,
  });
  
  return scenarios.scenarios;
};
```

---

## 🎯 FLUXO COMPLETO (Usuário)

```
1️⃣ DJ VÊ LEAD NA PIPELINE
   (evento respondeu positivamente)
   └─ Clica para NEGOCIAR

2️⃣ PERGUNTA: VOCÊ TEM AGÊNCIA?
   ├─ SIM: Agência cuida dos detalhes
   └─ NAO: DJ cuida de tudo

3️⃣ INFORMAR CACHE
   ├─ SUA proposta: R$ XXXX
   └─ APROVADO pelo evento: R$ XXXX (obrigatório)

4️⃣ SE FOR OUTRO ESTADO
   → "Próximo: Calcular Logística"
   → Sistema gera automaticamente 3-5 cenários

5️⃣ DJ SELECIONA MELHOR OPÇÃO
   ├─ Por custo (R$ XXX)
   ├─ Por modo (carro, uber, transporte público)
   ├─ Vê breakdown completo (estacionamento, voo, etc.)
   └─ Clica para confirmar

6️⃣ LOGÍSTICA ADICIONADA AO GIG
   ├─ Total = Cache + Logística
   ├─ Vai para Break-even automático
   └─ DJ confirma que entra em calendário

7️⃣ GIG STATUS = CONFIRMADO ✅
   └─ Bloqueado na agenda
```

---

## 🔧 DETALHES TÉCNICOS

### TransportMode Emoji Mapping
```
🚗 Carro
🚕 Compartilhado
🚙 Uber
🚕 Taxi
🚌 Ônibus
🚇 Metrô
🚂 Trem
✈️ Voo
```

### Custo Estimado (Heurístico)

**Mesma UF**:
- Combustível: distância ÷ consumo do carro × preço fuel
- Pedágio: ~R$ 0,15 por km (conservador)
- TOTAL ≈ 50-200 km

**Outro UF**:
- Rodoviário até aeroporto + transporte próprio: R$ 200-400
- Voo doméstico: R$ 400-800 (Skyscanner API ideal)
- Uber no destino: R$ 150-300
- TOTAL ≈ R$ 750-1.500

### Ordem de Prioridade

1. Mesmo estado → Mostrar só rodoviário
2. Outro estado → Gerar cenários com voo
3. Multi-mode → Metrô + ônibus + voo

---

## 🧪 TESTE MANUAL

### Cenário 1: Gig Mesma UF
```
Origem: São Paulo, SP
Destino: Campinas, SP
Esperado: Só rodoviário, sem voo
```

### Cenário 2: Gig Outro UF
```
Origem: São Paulo, SP
Destino: Rio de Janeiro, RJ
Esperado: 3-5 cenários com voo + diferentes modos
```

### Cenário 3: Publicidade Local
```
Origem: São Paulo, SP
Destino: São Paulo, SP
Esperado: Não pede logística (mesma cidade)
```

---

## 🚨 POTENCIAIS PROBLEMAS

| Problema | Solução |
|----------|---------|
| Cenários tardam a gerar | Fazer async, mostrar spinner |
| Voo muito caro/barato | Usar Skyscanner API, refinar heurística |
| DJ esquece cache | Validação obrigatória, toast de erro |
| Múltiplos modos não exibem bem | Usar componente de modal ou carousel |
| Não sincroniza com Break-even | Passar totalLogisticsCost via callback |

---

## 📊 ARQUIVOS MODIFICADOS

```
✅ Domain/Entities/Gig.swift
   └─ TransportMode, TransportLeg, LogisticsScenario, Gig expandido

✅ web-app/src/features/workspace/types.ts
   └─ Tipos atualizados para novo modelo

✅ web-app/src/features/workspace/logisticsScenarioGenerator.ts
   └─ Novo, fun generador de cenários

✅ web-app/src/features/workspace/GigNegotiationPanel.tsx
   └─ Novo, painel de negociação com agência/cache/notas

✅ web-app/src/features/workspace/LogisticsScenarioSelector.tsx
   └─ Novo, seletor visual para cenários

✅ Features/Events/GigNegotiationFlowView.swift
   └─ Novo, fluxo em SwiftUI para iOS
```

---

## 🎓 LIÇÕES APRENDIDAS

1. **Múltiplos cenários**: DJ precisa ver opções (custo vs. conforto)
2. **Etapas claras**: Agência → Cache → Logística → Confirmação
3. **Validação proativa**: Não deixar avanço sem dados necessários
4. **Detalhes visíveis**: Breakdown de custos, não só o total
5. **Multi-mode**: Public transport é viável para alguns DJs

---

## 📞 SUPORTE

Se encontrar erros ou tiver dúvidas:

1. Verifique se `gig.state` está em formato 2-letra (SP, RJ, etc.)
2. Confirme que `userHomeState` é passado corretamente
3. Teste com datas futuras (not past)
4. Valide cache & logística costs são > 0

**Boa sorte na implementação! 🎉**

