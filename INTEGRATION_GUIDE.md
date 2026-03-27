# 🔗 INTEGRAÇÃO - COMO CONECTAR V2 AO FLUXO EXISTENTE

## 📍 Mapa de Integração

```
╔════════════════════════════════════════════════════════╗
║         FLUXO COMPLETO DO DJ (Negociar GIG)           ║
╚════════════════════════════════════════════════════════╝

┌─ GigNegotiationPanel (EXISTENTE)
│  └─ Preenche: Cache aprovado, notas, status
│     └─ BOTÃO: "Calcular Logística →"
│        └─ NOVO: LogisticsScenarioExplainer (V2)
│           ├─ Chama: improvedGenerateLogisticsScenarios()
│           ├─ Mostra: ranking com scores, validação
│           └─ DJ CLICA: "Escolher esta opção"
│              └─ Salva: selectedLogisticsScenarioId
│                 └─ De volta pro GigNegotiationPanel
│                    └─ Continua fluxo normal...
```

---

## 🛣️ Passo-a-Passo de Integração

### Passo 1: Importar V2 no GigNegotiationPanel

**Arquivo**: `web-app/src/features/workspace/GigNegotiationPanel.tsx`

```typescript
// NO TOPO DO ARQUIVO
import { improvedGenerateLogisticsScenarios } from './logisticsScenarioGeneratorV2';
import { LogisticsScenarioExplainer } from './LogisticsScenarioExplainer';
```

### Passo 2: Expandir Estado do Component

```typescript
const GigNegotiationPanel = () => {
  const [gig, setGig] = useState(initialGig);
  
  // === NOVO: Estados para logística ===
  const [showLogisticsCalculator, setShowLogisticsCalculator] = useState(false);
  const [logisticsAnalysis, setLogisticsAnalysis] = useState(null);
  const [logisticsScenarios, setLogisticsScenarios] = useState([]);
  const [rankedScenarios, setRankedScenarios] = useState([]);
  const [validations, setValidations] = useState({});
  const [isCalculatingLogistics, setIsCalculatingLogistics] = useState(false);
  
  // ... resto do código
};
```

### Passo 3: Função para Calcular Logística

```typescript
const handleCalculateLogistics = async () => {
  if (!gig.cacheApprovedByEvent) {
    alert('Preencha o cache primeiro');
    return;
  }
  
  setIsCalculatingLogistics(true);
  
  try {
    // Chama V2
    const result = improvedGenerateLogisticsScenarios({
      from: gig.eventLocation?.city || '',
      fromState: gig.eventLocation?.state || '',
      to: gig.djLocation?.city || '',
      toState: gig.djLocation?.state || '',
      gigFee: gig.cacheApprovedByEvent,
      userPriority: 'balanced', // ou 'cheapest', 'comfort', 'speed'
    });
    
    // Salva resultado
    setLogisticsAnalysis(result.analysis);
    setLogisticsScenarios(result.scenarios);
    setRankedScenarios(result.ranked);
    setValidations(result.validations);
    
    // Mostra UI da seleção
    setShowLogisticsCalculator(true);
    
  } catch (error) {
    console.error('Erro ao calcular logística:', error);
    alert('Erro ao gerar opções de logística');
  } finally {
    setIsCalculatingLogistics(false);
  }
};
```

### Passo 4: Render do Botão "Calcular"

```typescript
// No JSX do GigNegotiationPanel, após cache:
<section>
  <label>Cache Aprovado</label>
  <input 
    type="number" 
    value={gig.cacheApprovedByEvent || ''}
    onChange={(e) => setGig({
      ...gig, 
      cacheApprovedByEvent: parseFloat(e.target.value)
    })}
    placeholder="R$ 0.00"
  />
  
  {gig.cacheApprovedByEvent > 0 && (
    <button 
      onClick={handleCalculateLogistics}
      disabled={isCalculatingLogistics}
      style={{marginTop: '1rem'}}
    >
      {isCalculatingLogistics ? '⏳ Calculando...' : '📍 Calcular Logística →'}
    </button>
  )}
</section>
```

### Passo 5: Render do Explainer (Modal/Overlay)

```typescript
{showLogisticsCalculator && logisticsAnalysis && (
  <div style={{
    position: 'fixed',
    top: 0, left: 0, right: 0, bottom: 0,
    background: 'rgba(0,0,0,0.5)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 1000
  }}>
    <div style={{
      background: 'white',
      borderRadius: '12px',
      boxShadow: '0 10px 40px rgba(0,0,0,0.2)',
      maxWidth: '900px',
      maxHeight: '90vh',
      overflow: 'auto',
      padding: '2rem'
    }}>
      <LogisticsScenarioExplainer
        analysis={logisticsAnalysis}
        scenarios={logisticsScenarios}
        ranked={rankedScenarios}
        validations={validations}
        gigFee={gig.cacheApprovedByEvent}
        selectedScenarioId={gig.selectedLogisticsScenarioId}
        onSelect={(scenario) => {
          // DJ escolheu uma opção
          setGig({
            ...gig,
            selectedLogisticsScenarioId: scenario.id,
            selectedLogisticsScenarioName: scenario.name,
            totalLogisticsCost: scenario.totalCost,
            logisticsScenarios: logisticsScenarios,
            logisticsRequired: true,
          });
          setShowLogisticsCalculator(false);
        }}
      />
      
      <button 
        onClick={() => setShowLogisticsCalculator(false)}
        style={{marginTop: '1rem', width: '100%'}}
      >
        Fechar
      </button>
    </div>
  </div>
)}
```

---

## 🏗️ Integração com Painel Existente

### LogisticsPanel Antigo (Keep)

```typescript
// Continua para informações gerais de logística
<section>
  <h3>Logística Selecionada</h3>
  {gig.selectedLogisticsScenarioName && (
    <div>
      <strong>{gig.selectedLogisticsScenarioName}</strong>
      <p>Custo: R$ {gig.totalLogisticsCost?.toFixed(2)}</p>
      <button onClick={() => setShowLogisticsCalculator(true)}>
        ↻ Recalcular
      </button>
    </div>
  )}
</section>
```

### Structure Completa

```
GigNegotiationPanel (WRAPPER)
├─ CacheApprovedSection
│  └─ INPUT: Cache value
│  └─ BUTTON: "Calcular Logística"
│
├─ LogisticsScenarioExplainer (MODAL/OVERLAY)  ← V2 NOVO
│  └─ Route Analysis
│  └─ Ranked Scenarios
│  └─ Callback: onSelect
│
├─ SelectedLogisticsSection
│  └─ Mostra: "Opção selecionada: Uber+Voo"
│  └─ BUTTON: "Recalcular"
│
├─ NegotiationNotesSection (EXISTENTE)
│  └─ Notas livres
│
└─ SaveButton
   └─ Salva GIG completo (com logística)
```

---

## 📲 Integração iOS (SwiftUI)

### 1. Expandir Gig Model

```swift
@Model final class Gig {
    // ... campos existentes ...
    
    // NOVO: Campos de Logística
    var logisticsRequired: Bool = false
    var logisticsScenarios: [LogisticsScenario] = []
    var selectedLogisticsScenário: LogisticsScenario?
    var totalLogisticsCost: Double?
    var cacheApprovedByEvent: Double?
    var cacheApprovedAt: Date?
}
```

### 2. Criar Função de Cálculo (Swift)

```swift
// Features/Events/LogisticsCalculator.swift
import Foundation

class LogisticsCalculator {
    
    static func improvedCalculateScenarios(
        from: String,
        fromState: String,
        to: String,
        toState: String,
        gigFee: Double
    ) -> (analysis: RouteAnalysis, scenarios: [LogisticsScenario]) {
        
        // Chamar Web API para V2 (ou implementar em Swift)
        // Por enquanto: proxy para TypeScript versão
        
        let distance = calculateDistance(from: from, to: to)
        let requiresFlight = distance > 500 && fromState != toState
        
        var scenarios: [LogisticsScenario] = []
        
        if !requiresFlight {
            // Apenas transporte local
            scenarios.append(.init(
                name: "Transporte Local",
                scenarioType: .local,
                totalCost: distance < 50 ? 50 : 150
            ))
        } else {
            // Com voo
            scenarios.append(.init(
                name: "Uber + Voo",
                scenarioType: .airTransport,
                totalCost: 1050
            ))
        }
        
        return (
            analysis: RouteAnalysis(
                requiresFlight: requiresFlight,
                estimatedDistance: distance
            ),
            scenarios: scenarios
        )
    }
    
    private static func calculateDistance(from: String, to: String) -> Double {
        // Mock: seria Google Maps API na prática
        return 430
    }
}
```

### 3. View para Seleção (SwiftUI)

```swift
// Features/Events/LogisticsScenarioSelectorView.swift
struct LogisticsScenarioSelectorView: View {
    let scenarios: [LogisticsScenario]
    let analysis: RouteAnalysis
    let gigFee: Double
    @Binding var selectedScenario: LogisticsScenario?
    var onDone: () -> Void
    
    @State private var expandedId: UUID?
    
    var body: some View {
        VStack(spacing: 20) {
            // Route Analysis
            VStack(alignment: .leading, spacing: 8) {
                Text("📍 Análise da Rota")
                    .font(.headline)
                Text("Requer voo: \(analysis.requiresFlight ? "Sim" : "Não")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Scenarios List
            VStack(spacing: 12) {
                ForEach(Array(scenarios.enumerated()), id: \.element.id) { index, scenario in
                    ScenarioCard(
                        index: index + 1,
                        scenario: scenario,
                        isExpanded: expandedId == scenario.id,
                        isSelected: selectedScenario?.id == scenario.id,
                        onTap: {
                            withAnimation {
                                expandedId = expandedId == scenario.id ? nil : scenario.id
                            }
                        },
                        onSelect: {
                            selectedScenario = scenario
                        }
                    )
                }
            }
            
            Spacer()
            
            // Done Button
            Button("Confirmar") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedScenario == nil)
        }
        .padding()
        .navigationTitle("Selecione Logística")
    }
}

// Card individual
struct ScenarioCard: View {
    let index: Int
    let scenario: LogisticsScenario
    let isExpanded: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(index) \(scenario.name)")
                        .font(.headline)
                    Text(scenario.description ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(String(format: "R$ %.2f", scenario.totalCost))")
                        .font(.headline)
                        .foregroundColor(.green)
                    if isSelected {
                        Text("✓ Selecionada")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vantagens:")
                        .font(.caption).bold()
                    Text("• Bom custo")
                        .font(.caption)
                    
                    Text("Desvantagens:")
                        .font(.caption).bold()
                    Text("• Requer voo")
                        .font(.caption)
                }
                
                Button("Escolher esta opção") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.gray.opacity(0.05))
        .cornerRadius(8)
        .border(
            isSelected ? Color.green : Color.gray.opacity(0.2),
            width: 2
        )
    }
}
```

### 4. Integrar na Flow Existente

```swift
// Features/Events/GigNegotiationFlowView.swift
struct GigNegotiationFlowView: View {
    @State var gig: Gig
    @State var showLogisticsSelector = false
    @State var logisticsScenarios: [LogisticsScenario] = []
    @State var routeAnalysis: RouteAnalysis?
    
    var body: some View {
        VStack(spacing: 20) {
            // Cache Input
            HStack {
                Text("Cache Aprovado")
                TextField("R$ 0.00", value: $gig.cacheApprovedByEvent ?? 0, format: .currency(code: "BRL"))
            }
            .padding()
            
            // Calc Button
            if (gig.cacheApprovedByEvent ?? 0) > 0 {
                Button("📍 Calcular Logística") {
                    calculateLogistics()
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Selected Logistics Display
            if let selected = gig.selectedLogisticsScenário {
                VStack(alignment: .leading) {
                    Text("Logística Selecionada:")
                        .font(.caption)
                    Text(selected.name)
                        .font(.headline)
                    Text("R$ \(String(format: "%.2f", selected.totalCost))")
                        .foregroundColor(.green)
                }
                .padding()
                .background(.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .sheet(isPresented: $showLogisticsSelector) {
            if let analysis = routeAnalysis {
                LogisticsScenarioSelectorView(
                    scenarios: logisticsScenarios,
                    analysis: analysis,
                    gigFee: gig.cacheApprovedByEvent ?? 0,
                    selectedScenario: $gig.selectedLogisticsScenário,
                    onDone: {
                        showLogisticsSelector = false
                    }
                )
            }
        }
    }
    
    func calculateLogistics() {
        let result = LogisticsCalculator.improvedCalculateScenarios(
            from: gig.eventLocation?.city ?? "",
            fromState: gig.eventLocation?.state ?? "",
            to: gig.djLocation?.city ?? "",
            toState: gig.djLocation?.state ?? "",
            gigFee: gig.cacheApprovedByEvent ?? 0
        )
        
        routeAnalysis = result.analysis
        logisticsScenarios = result.scenarios
        showLogisticsSelector = true
    }
}
```

---

## 🔄 Fluxo de Dados Completo

```
┌─── GigNegotiationPanel ────────────────────────────┐
│                                                     │
│  1. DJ preenche: Cache R$ 2.500                   │
│                                                     │
│  2. CLICK: "Calcular Logística"                   │
│         ↓                                          │
│  3. State: isCalculatingLogistics = true         │
│                                                     │
│  4. CALL: improvedGenerateLogisticsScenarios({   │
│     from: "São Paulo",                            │
│     fromState: "SP",                              │
│     to: "Rio de Janeiro",                         │
│     toState: "RJ",                                │
│     gigFee: 2500                                  │
│  })                                               │
│         ↓                                          │
│  5. V2 RETURNS:                                   │
│     {                                             │
│       analysis: { requiresFlight: true, ... },   │
│       scenarios: [3 opções],                      │
│       ranked: [3 explicações],                    │
│       validations: {scores, warnings},            │
│       summary: "..."                              │
│     }                                             │
│         ↓                                          │
│  6. State Updates:                                │
│     logisticsAnalysis = {...}                     │
│     logisticsScenarios = [...]                    │
│     rankedScenarios = [...]                       │
│     validations = {...}                           │
│                                                     │
│  7. RENDER: LogisticsScenarioExplainer MODAL     │
│         ↓                                          │
│  8. DJ CLICA: Opção #1                           │
│         ↓                                          │
│  9. CALLBACK: onSelect(scenario)                 │
│         ↓                                          │
│  10. State Updates:                               │
│      gig.selectedLogisticsScenarioId = "..."     │
│      gig.selectedLogisticsScenarioName = "..."   │
│      gig.totalLogisticsCost = 1030               │
│      gig.logisticsScenarios = [...]              │
│      showLogisticsCalculator = false              │
│         ↓                                          │
│  11. MODAL CLOSES                                 │
│         ↓                                          │
│  12. SHOW: Selected logistics na UI              │
│      "Opção selecionada: Uber + Voo (R$ 1.030)" │
│         ↓                                          │
│  13. DJ CLICA: "Confirmar Negociação"            │
│         ↓                                          │
│  14. SAVE GIG COMPLETO:                          │
│      ✓ Cache: R$ 2.500                           │
│      ✓ Logística: R$ 1.030 (Uber+Voo)           │
│      ✓ Total: R$ 3.530                           │
│      ✓ Status: CONFIRMADO                        │
│                                                     │
└──────────────────────────────────────────────────┘
```

---

## ✅ Checklist de Integração

### Web (Next.js + React)

- [ ] Importar `improvedGenerateLogisticsScenarios` no GigNegotiationPanel
- [ ] Importar `LogisticsScenarioExplainer` component
- [ ] Adicionar estados (isCalculating, analysis, scenarios, ranked, validations)
- [ ] Criar função `handleCalculateLogistics()`
- [ ] Adicionar BUTTON "Calcular Logística" no DOM
- [ ] Adicionar MODAL/OVERLAY com LogisticsScenarioExplainer
- [ ] Conectar callback `onSelect` para salvar seleção no Gig
- [ ] Testar fluxo completo

### iOS (SwiftUI)

- [ ] Expandir Gig @Model com campos logística
- [ ] Criar LogisticsCalculator.swift
- [ ] Criar LogisticsScenarioSelectorView.swift
- [ ] Criar ScenarioCard.swift
- [ ] Integrar no GigNegotiationFlowView
- [ ] Testar com simulador
- [ ] Conectar salvar no SwiftData

### Backend (se tiver)

- [ ] Criar endpoint `/api/gigs/{id}/logistics-analyze`
- [ ] Conectar ao Google Maps API (distâncias)
- [ ] Conectar ao Skyscanner API (voos)
- [ ] Conectar ao Redis (cache de resultados)
- [ ] Validar cache > logistica

### Testing

- [ ] Teste local (SP → SP)
- [ ] Teste regional (SP → Campinas)
- [ ] Teste nacional (SP → RJ)
- [ ] Teste longa distância (SP → Manaus)
- [ ] Teste com cache baixo (inviável)
- [ ] Teste com múltiplos cenários

---

## 🚀 Deploy

### 1. Deploy V2 Generator

```bash
# No web-app/
npm run build
npm run test

# Commit
git add src/features/workspace/logisticsScenarioGeneratorV2.ts
git commit -m "feat: V2 logistics scenario generator with transparency"
```

### 2. Deploy Explainer Component

```bash
# Commit
git add src/features/workspace/LogisticsScenarioExplainer.tsx
git commit -m "feat: logistics scenario explainer with scoring transparency"

# Build e deploy
npm run build
vercel deploy --prod
```

### 3. Deploy iOS

```bash
# No iOS project
# Atualizar Gig model
# Compilar
# Testar no simulador
# Archive → Build → TestFlight
# Ou direto pra App Store
```

---

## 📞 Suporte to Dev

**Dúvida**: "V2 tá muito lento"
**Solução**: 
- Cache resultados no Redis (chave: `logistics-{from}-{to}`)
- Implementar memoização no client

**Dúvida**: "Voo preço tá errado"
**Solução**:
- Integrar Skyscanner API real
- Atualizar `generateNationalEventScenarios()`

**Dúvida**: "Mobile tá com lag"
**Solução**:
- Calcular no backend (endpoint `/api/logistics/calculate`)
- iOS e Web chamam API, não TypeScript local

