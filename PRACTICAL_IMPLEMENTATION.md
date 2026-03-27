# 🔧 IMPLEMENTAÇÃO PRÁTICA - CÓDIGO PRONTO PARA COPIAR

## Índice

1. [Web - Integração Completa](#web---integração-completa)
2. [iOS - Integração Completa](#ios---integração-completa)
3. [Troubleshooting](#troubleshooting)
4. [Testes](#testes)

---

## Web - Integração Completa

### Arquivo: `GigNegotiationPanel.tsx` (Antes/Depois)

#### ANTES:
```typescript
// ❌ Simples, sem logística avançada
export const GigNegotiationPanel = ({ gig, onSave }: Props) => {
  const [localGig, setLocalGig] = useState(gig);
  
  return (
    <div>
      <input 
        value={localGig.cacheApprovedByEvent || ''}
        onChange={(e) => setLocalGig({...localGig, cacheApprovedByEvent: parseFloat(e.target.value)})}
      />
      <button onClick={() => onSave(localGig)}>Salvar</button>
    </div>
  );
};
```

#### DEPOIS:
```typescript
// ✅ Com V2 integrado
import { improvedGenerateLogisticsScenarios } from './logisticsScenarioGeneratorV2';
import { LogisticsScenarioExplainer } from './LogisticsScenarioExplainer';

interface GigNegotiationPanelProps {
  gig: Gig;
  onSave: (gig: Gig) => Promise<void>;
}

export const GigNegotiationPanel = ({ gig, onSave }: GigNegotiationPanelProps) => {
  const [localGig, setLocalGig] = useState<Gig>(gig);
  const [isLoading, setIsLoading] = useState(false);
  
  // === NOVO: Estados para logística V2 ===
  const [showLogisticsCalculator, setShowLogisticsCalculator] = useState(false);
  const [logisticsAnalysis, setLogisticsAnalysis] = useState<RouteAnalysis | null>(null);
  const [logisticsScenarios, setLogisticsScenarios] = useState<LogisticsScenario[]>([]);
  const [rankedScenarios, setRankedScenarios] = useState<ScenarioRecommendationExplanation[]>([]);
  const [validations, setValidations] = useState<Record<string, ScenarioValidation>>({});
  const [isCalculatingLogistics, setIsCalculatingLogistics] = useState(false);
  
  // HANDLER: Calcular logística
  const handleCalculateLogistics = async () => {
    if (!localGig.cacheApprovedByEvent || localGig.cacheApprovedByEvent <= 0) {
      alert('⚠️ Preencha o cache aprovado primeiro');
      return;
    }

    setIsCalculatingLogistics(true);
    
    try {
      // Validação de dados necessários
      const eventCity = localGig.eventLocation?.city;
      const eventState = localGig.eventLocation?.state;
      const djCity = gig.djLocation?.city || 'São Paulo'; // default
      const djState = gig.djLocation?.state || 'SP';
      
      if (!eventCity || !eventState) {
        alert('⚠️ Local do evento não preenchido');
        setIsCalculatingLogistics(false);
        return;
      }

      // Chama V2 generator
      const result = improvedGenerateLogisticsScenarios({
        from: djCity,
        fromState: djState,
        to: eventCity,
        toState: eventState,
        gigFee: localGig.cacheApprovedByEvent,
        userPriority: 'balanced', // Pode ser 'cheapest', 'comfort', 'speed'
      });
      
      // Salva resultado nos estados
      setLogisticsAnalysis(result.analysis);
      setLogisticsScenarios(result.scenarios);
      setRankedScenarios(result.ranked);
      setValidations(result.validations);
      
      // Mostra modal
      setShowLogisticsCalculator(true);
      
    } catch (error) {
      console.error('Erro ao gerar logística:', error);
      alert('❌ Erro ao gerar opções de logística\n' + (error as Error).message);
    } finally {
      setIsCalculatingLogistics(false);
    }
  };
  
  // HANDLER: DJ selecionou uma opção
  const handleSelectLogistics = (scenario: LogisticsScenario) => {
    setLocalGig(prev => ({
      ...prev,
      logisticsRequired: true,
      selectedLogisticsScenarioId: scenario.id,
      selectedLogisticsScenarioName: scenario.name,
      totalLogisticsCost: scenario.totalCost,
      logisticsScenarios: logisticsScenarios, // Salva todas pra histórico
    }));
    setShowLogisticsCalculator(false);
  };
  
  // HANDLER: Salvar GIG completo
  const handleSaveGig = async () => {
    if (!localGig.cacheApprovedByEvent) {
      alert('⚠️ Preencha cache antes de salvar');
      return;
    }
    
    setIsLoading(true);
    try {
      await onSave({
        ...localGig,
        cacheApprovedAt: localGig.cacheApprovedAt || new Date(),
      });
      alert('✅ GIG salvo com sucesso!');
    } catch (error) {
      alert('❌ Erro ao salvar: ' + (error as Error).message);
    } finally {
      setIsLoading(false);
    }
  };
  
  return (
    <div style={{ maxWidth: '800px', margin: '0 auto' }}>
      <h2>📋 Negociação do GIG</h2>
      
      {/* ============ SEÇÃO: Cache ============ */}
      <section style={{ marginBottom: '2rem', padding: '1rem', background: '#f5f5f5', borderRadius: '8px' }}>
        <h3>💰 Cache Aprovado</h3>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
          <div>
            <label>Valor do Cache (R$)</label>
            <input 
              type="number"
              value={localGig.cacheApprovedByEvent || ''}
              onChange={(e) => {
                const val = parseFloat(e.target.value);
                setLocalGig(prev => ({
                  ...prev,
                  cacheApprovedByEvent: isNaN(val) ? undefined : val,
                }));
              }}
              placeholder="0.00"
              style={{ width: '100%', padding: '0.5rem' }}
            />
          </div>
          
          <div>
            <label>Data da Aprovação</label>
            <input 
              type="date"
              value={localGig.cacheApprovedAt?.toISOString().split('T')[0] || new Date().toISOString().split('T')[0]}
              onChange={(e) => {
                setLocalGig(prev => ({
                  ...prev,
                  cacheApprovedAt: new Date(e.target.value),
                }));
              }}
              style={{ width: '100%', padding: '0.5rem' }}
            />
          </div>
        </div>
        
        {/* Botão Calcular Logística */}
        {(localGig.cacheApprovedByEvent ?? 0) > 0 && (
          <button
            onClick={handleCalculateLogistics}
            disabled={isCalculatingLogistics}
            style={{
              marginTop: '1rem',
              width: '100%',
              padding: '0.75rem',
              background: isCalculatingLogistics ? '#ccc' : '#007AFF',
              color: 'white',
              border: 'none',
              borderRadius: '6px',
              cursor: isCalculatingLogistics ? 'not-allowed' : 'pointer',
              fontSize: '1rem',
            }}
          >
            {isCalculatingLogistics ? '⏳ Calculando opções...' : '📍 Calcular Logística →'}
          </button>
        )}
      </section>
      
      {/* ============ DISPLAY: Logística Selecionada ============ */}
      {localGig.selectedLogisticsScenarioId && (
        <section style={{ marginBottom: '2rem', padding: '1rem', background: '#e8f5e9', borderRadius: '8px', border: '2px solid #4caf50' }}>
          <h3>✅ Logística Selecionada</h3>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
            <div>
              <p style={{ margin: '0.5rem 0', color: '#555' }}>
                <strong>Opção:</strong> {localGig.selectedLogisticsScenarioName}
              </p>
            </div>
            <div>
              <p style={{ margin: '0.5rem 0', fontSize: '1.2rem', color: '#4caf50' }}>
                <strong>Custo:</strong> R$ {(localGig.totalLogisticsCost || 0).toFixed(2)}
              </p>
            </div>
          </div>
          
          {/* Calculado automaticamente */}
          <div style={{ marginTop: '1rem', padding: '1rem', background: '#fff', borderRadius: '6px' }}>
            <p style={{ margin: '0.25rem 0', color: '#666', fontSize: '0.9rem' }}>
              <strong>Resumo Financeiro:</strong>
            </p>
            <ul style={{ margin: '0.5rem 0', paddingLeft: '1.5rem', color: '#555' }}>
              <li>Cache: R$ {(localGig.cacheApprovedByEvent || 0).toFixed(2)}</li>
              <li>Logística: R$ {(localGig.totalLogisticsCost || 0).toFixed(2)}</li>
              <li style={{ fontWeight: 'bold', color: '#4caf50' }}>
                Lucro: R$ {(((localGig.cacheApprovedByEvent || 0) - (localGig.totalLogisticsCost || 0))).toFixed(2)}
              </li>
            </ul>
          </div>
          
          <button
            onClick={() => setShowLogisticsCalculator(true)}
            style={{
              marginTop: '1rem',
              width: '100%',
              padding: '0.5rem',
              background: '#f0f0f0',
              border: '1px solid #ccc',
              borderRadius: '6px',
              cursor: 'pointer',
            }}
          >
            ↻ Recalcular Logística
          </button>
        </section>
      )}
      
      {/* ============ SEÇÃO: Notas ============ */}
      <section style={{ marginBottom: '2rem', padding: '1rem', background: '#f5f5f5', borderRadius: '8px' }}>
        <h3>📝 Notas da Negociação</h3>
        <textarea
          value={localGig.negotiationNotes || ''}
          onChange={(e) => setLocalGig(prev => ({ ...prev, negotiationNotes: e.target.value }))}
          placeholder="Adicione notas sobre a negociação..."
          style={{
            width: '100%',
            minHeight: '100px',
            padding: '1rem',
            borderRadius: '6px',
            border: '1px solid #ddd',
            fontFamily: 'monospace',
          }}
        />
      </section>
      
      {/* ============ BOTÕES: Ações ============ */}
      <div style={{ display: 'flex', gap: '1rem' }}>
        <button
          onClick={handleSaveGig}
          disabled={isLoading}
          style={{
            flex: 1,
            padding: '0.75rem',
            background: isLoading ? '#ccc' : '#4caf50',
            color: 'white',
            border: 'none',
            borderRadius: '6px',
            cursor: isLoading ? 'not-allowed' : 'pointer',
            fontSize: '1rem',
            fontWeight: 'bold',
          }}
        >
          {isLoading ? '💾 Salvando...' : '✅ Confirmar Negociação'}
        </button>
        
        <button
          onClick={() => setLocalGig(gig)}
          style={{
            flex: 1,
            padding: '0.75rem',
            background: '#f0f0f0',
            border: '1px solid #ccc',
            borderRadius: '6px',
            cursor: 'pointer',
            fontSize: '1rem',
          }}
        >
          ↺ Cancelar
        </button>
      </div>
      
      {/* ============ MODAL: Logistics Calculator (V2) ============ */}
      {showLogisticsCalculator && logisticsAnalysis && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.5)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 1000,
        }}>
          <div style={{
            background: 'white',
            borderRadius: '12px',
            boxShadow: '0 10px 40px rgba(0, 0, 0, 0.2)',
            maxWidth: '900px',
            width: '95%',
            maxHeight: '90vh',
            overflow: 'auto',
            padding: '2rem',
          }}>
            <LogisticsScenarioExplainer
              analysis={logisticsAnalysis}
              scenarios={logisticsScenarios}
              ranked={rankedScenarios}
              validations={validations}
              gigFee={localGig.cacheApprovedByEvent || 0}
              selectedScenarioId={localGig.selectedLogisticsScenarioId}
              onSelect={handleSelectLogistics}
            />
            
            <div style={{ marginTop: '2rem', display: 'flex', gap: '1rem' }}>
              <button
                onClick={() => setShowLogisticsCalculator(false)}
                style={{
                  flex: 1,
                  padding: '0.75rem',
                  background: '#f0f0f0',
                  border: '1px solid #ccc',
                  borderRadius: '6px',
                  cursor: 'pointer',
                  fontSize: '1rem',
                }}
              >
                ✕ Fechar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
```

---

## iOS - Integração Completa

### Arquivo: `GigNegotiationFlowView.swift`

```swift
import SwiftUI
import SwiftData

struct GigNegotiationFlowView: View {
    @Bindable var gig: Gig
    @State private var showLogisticsSelector = false
    @State private var logisticsScenarios: [LogisticsScenario] = []
    @State private var selectedScenario: LogisticsScenario?
    @State private var isCalculating = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // ===== CACHE INPUT =====
                Section("Negociação") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Cache Aprovado", systemImage: "dollarsign.circle")
                                .font(.headline)
                            Spacer()
                            TextField(
                                "R$ 0.00",
                                value: .constant(gig.cacheApprovedByEvent ?? 0),
                                format: .currency(code: "BRL")
                            )
                            .keyboardType(.decimalPad)
                            .onChange(of: $gig.cacheApprovedByEvent) { _, newValue in
                                gig.cacheApprovedByEvent = newValue
                            }
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 150)
                        }
                        
                        DatePicker(
                            "Data de Aprovação",
                            selection: .constant(gig.cacheApprovedAt ?? Date()),
                            displayedComponents: .date
                        )
                        .onChange(of: $gig.cacheApprovedAt) { _, newValue in
                            gig.cacheApprovedAt = newValue
                        }
                    }
                    .padding(.vertical)
                }
                
                // ===== CALCULAR LOGÍSTICA BUTTON =====
                if (gig.cacheApprovedByEvent ?? 0) > 0 {
                    Button(action: calculateLogistics) {
                        HStack {
                            if isCalculating {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "mappin.circle.fill")
                            }
                            Text(isCalculating ? "Calculando..." : "Calcular Logística →")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isCalculating)
                }
                
                // ===== DISPLAY SELECTED LOGISTICS =====
                if let selectedScenario = selectedScenario {
                    Section("Logística Selecionada") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(selectedScenario.name)
                                    .font(.headline)
                                Spacer()
                                Text("R$ \(selectedScenario.totalCost, format: .currency(code: "BRL"))")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            HStack {
                                Text("Cache:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("R$ \(gig.cacheApprovedByEvent ?? 0, format: .currency(code: "BRL"))")
                            }
                            .font(.caption)
                            
                            HStack {
                                Text("Lucro:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("R$ \((gig.cacheApprovedByEvent ?? 0) - selectedScenario.totalCost, format: .currency(code: "BRL"))")
                                    .foregroundColor(.green)
                                    .fontWeight(.bold)
                            }
                            .font(.caption)
                            
                            Button("↻ Recalcular") {
                                showLogisticsSelector = true
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
                
                // ===== NOTES =====
                Section("Notas") {
                    TextEditor(text: .constant(gig.negotiationNotes ?? ""))
                        .onChange(of: $gig.negotiationNotes) { _, newValue in
                            gig.negotiationNotes = newValue
                        }
                        .frame(height: 100)
                        .border(Color(.systemGray4))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                // ===== SAVE BUTTON =====
                Button(action: saveGig) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Confirmar Negociação")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.vertical)
            }
            .padding()
            .navigationTitle("Negociar GIG")
            .sheet(isPresented: $showLogisticsSelector) {
                if !logisticsScenarios.isEmpty {
                    LogisticsScenarioSelectorView(
                        scenarios: $logisticsScenarios,
                        selectedScenario: $selectedScenario,
                        gigFee: gig.cacheApprovedByEvent ?? 0,
                        onDone: {
                            showLogisticsSelector = false
                            saveSelectedLogistics()
                        }
                    )
                }
            }
            .alert("Erro", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage ?? "Erro desconhecido")
            }
        }
    }
    
    // MARK: - Functions
    
    func calculateLogistics() {
        guard let cache = gig.cacheApprovedByEvent, cache > 0 else {
            errorMessage = "Preencha o cache primeiro"
            showError = true
            return
        }
        
        guard let eventCity = gig.eventLocation?.city,
              let eventState = gig.eventLocation?.state else {
            errorMessage = "Local do evento não preenchido"
            showError = true
            return
        }
        
        isCalculating = true
        selectedScenario = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try LogisticsCalculationService.improvedCalculateScenarios(
                    from: gig.djLocation?.city ?? "São Paulo",
                    fromState: gig.djLocation?.state ?? "SP",
                    to: eventCity,
                    toState: eventState,
                    gigFee: cache
                )
                
                DispatchQueue.main.async {
                    self.logisticsScenarios = result.scenarios
                    self.isCalculating = false
                    self.showLogisticsSelector = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Erro ao calcular: \(error.localizedDescription)"
                    self.showError = true
                    self.isCalculating = false
                }
            }
        }
    }
    
    func saveSelectedLogistics() {
        if let scenario = selectedScenario {
            gig.selectedLogisticsScenário = scenario
            gig.totalLogisticsCost = scenario.totalCost
            gig.logisticsRequired = true
        }
    }
    
    func saveGig() {
        do {
            try modelContext.save()
            // Aqui você pode navegar ou mostrar sucesso
        } catch {
            errorMessage = "Erro ao salvar: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Scenario Selector View

struct LogisticsScenarioSelectorView: View {
    @Binding var scenarios: [LogisticsScenario]
    @Binding var selectedScenario: LogisticsScenario?
    let gigFee: Double
    let onDone: () -> Void
    
    @State private var expandedId: UUID?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(scenarios.enumerated()), id: \.element.id) { index, scenario in
                            ScenarioCardView(
                                index: index + 1,
                                scenario: scenario,
                                isExpanded: expandedId == scenario.id,
                                isSelected: selectedScenario?.id == scenario.id,
                                gigFee: gigFee,
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
                    .padding()
                }
                
                Spacer()
                
                Button(action: onDone) {
                    Text("Confirmar")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedScenario != nil ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(selectedScenario == nil)
                .padding()
            }
            .navigationTitle("Selecione Logística")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Scenario Card

struct ScenarioCardView: View {
    let index: Int
    let scenario: LogisticsScenario
    let isExpanded: Bool
    let isSelected: Bool
    let gigFee: Double
    let onTap: () -> Void
    let onSelect: () -> Void
    
    var profitability: String {
        let profit = gigFee - scenario.totalCost
        let percentage = (profit / gigFee) * 100
        if profit > 0 {
            return "Lucro: R$ \(profit, format: .currency(code: "BRL")) (\(percentage, format: .number)%)"
        } else {
            return "❌ INVIÁVEL - Prejuízo de R$ \(-profit, format: .currency(code: "BRL"))"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (Always visible)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(index). \(scenario.name)")
                        .font(.headline)
                    if let desc = scenario.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("R$ \(scenario.totalCost, format: .currency(code: "BRL"))")
                        .font(.headline)
                        .foregroundColor(.green)
                    if isSelected {
                        Label("Selecionada", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            // Profitability
            Text(profitability)
                .font(.caption)
                .foregroundColor(gigFee >= scenario.totalCost ? .green : .red)
            
            // Expanded Section
            if isExpanded {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    // Advantages
                    Label("Vantagens", systemImage: "plus.circle.fill")
                        .font(.caption).bold()
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Bom custo-benefício")
                            .font(.caption2)
                        Text("• Transporte confortável")
                            .font(.caption2)
                    }
                    .padding(.bottom, 8)
                    
                    // Disadvantages
                    Label("Desvantagens", systemImage: "minus.circle.fill")
                        .font(.caption).bold()
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Possível atraso de voo")
                            .font(.caption2)
                    }
                    
                    Spacer(minLength: 8)
                    
                    // Select Button
                    Button(action: onSelect) {
                        HStack {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            Text(isSelected ? "Selecionada" : "Escolher esta opção")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(isSelected ? Color.green : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .border(
            isSelected ? Color.green : Color.gray.opacity(0.3),
            width: 2
        )
    }
}
```

---

## Troubleshooting

### ⚠️ Problema 1: "Cannot find `improvedGenerateLogisticsScenarios` in scope"

**Causa**: Arquivo `logisticsScenarioGeneratorV2.ts` não importado
**Solução**:

```typescript
// Add this import at the top of your file
import { improvedGenerateLogisticsScenarios } from './logisticsScenarioGeneratorV2';

// Or if in different folder:
import { improvedGenerateLogisticsScenarios } from '../path/to/logisticsScenarioGeneratorV2';
```

**Checklist**:
- [ ] Arquivo `logisticsScenarioGeneratorV2.ts` existe?
- [ ] Está na pasta correta? (`web-app/src/features/workspace/`)
- [ ] Import path está correto?
- [ ] Sem typos no import?

---

### ⚠️ Problema 2: "gigFee is not defined"

**Causa**: Prop `gigFee` não passado para LogisticsScenarioExplainer
**Solução**:

```typescript
// ERRADO ❌
<LogisticsScenarioExplainer 
  scenarios={scenarios}
  // falta gigFee!
/>

// CORRETO ✅
<LogisticsScenarioExplainer 
  scenarios={scenarios}
  gigFee={gig.cacheApprovedByEvent || 0}  // ← ADD THIS
/>
```

---

### ⚠️ Problema 3: "Runtime error: Cannot set property totalLogisticsCost on undefined"

**Causa**: `gig` é null/undefined
**Solução**:

```typescript
// Adicione validação:
if (!gig) {
  alert('GIG não carregado');
  return;
}

const result = improvedGenerateLogisticsScenarios({
  from: gig.eventLocation?.city || '',  // Use optional chaining
  // ...
});
```

---

### ⚠️ Problema 4: "Modal não fecha após seleção"

**Causa**: Estado `showLogisticsCalculator` não setando para false
**Solução**:

```typescript
const handleSelectLogistics = (scenario: LogisticsScenario) => {
  setLocalGig(prev => ({...prev, selectedLogisticsScenarioId: scenario.id}));
  setShowLogisticsCalculator(false);  // ← ADD THIS
};
```

---

### ⚠️ Problema 5: iOS - "Cannot convert value of type 'Double' to 'Double?'"

**Causa**: Mismatch entre binding
**Solução**:

```swift
// ERRADO ❌
TextField("R$ 0.00", value: $gig.cacheApprovedByEvent, format: .currency(code: "BRL"))
// gig.cacheApprovedByEvent é Double?, TextField quer Double

// CORRETO ✅
TextField(
    "R$ 0.00",
    value: .constant(gig.cacheApprovedB yEvent ?? 0),  // Use .constant() e nil coalescing
    format: .currency(code: "BRL")
)
.onChange(of: $gig.cacheApprovedByEvent) { _, newValue in
    gig.cacheApprovedByEvent = newValue
}
```

---

### ⚠️ Problema 6: "Validations is not being calculated"

**Causa**: `validateScenario` não sendo chamado em V2
**Solução**: Verificar que em `improvedGenerateLogisticsScenarios`:

```typescript
// Deve ter algo assim:
scenarios.forEach(scenario => {
  const validation = validateScenario(scenario, gigFee);
  validationMap[scenario.id] = validation;  // ← IMPORTANTE
});

return {
  // ...
  validations: validationMap,  // ← Pass this
};
```

---

## Testes

### Teste 1: Evento Local (SP → SP)

```javascript
const result = improvedGenerateLogisticsScenarios({
  from: "São Paulo",
  fromState: "SP",
  to: "São Paulo",
  toState: "SP",
  gigFee: 1000,
});

// Espera:
// ✅ analysis.isLocalEvent = true
// ✅ scenarios.length >= 2 (metrô, uber)
// ✅ requiresFlight = false
// ✅ Nenhum cenário com voo
console.log(result);
```

### Teste 2: Outro Estado (SP → RJ)

```javascript
const result = improvedGenerateLogisticsScenarios({
  from: "São Paulo",
  fromState: "SP",
  to: "Rio de Janeiro",
  toState: "RJ",
  gigFee: 2500,
});

// Espera:
// ✅ analysis.isNationalEvent = true
// ✅ analysis.requiresFlight = true
// ✅ scenarios.length === 3 (todas com voo)
// ✅ Ranking: score entre 60-100
// ✅ Todascenários com validação
console.log(result);
```

### Teste 3: Viabilidade Crítica

```javascript
const result = improvedGenerateLogisticsScenarios({
  from: "São Paulo",
  fromState: "SP",
  to: "Rio de Janeiro",
  toState: "RJ",
  gigFee: 500,  // Muito baixo!
});

// Espera:
// ⚠️ Todos cenários marcados como INVIÁVEL
// ⚠️ validations[scenarioId].isValid = false
// ⚠️ warnings incluem "Logística > cache"
result.ranked.forEach(r => {
  console.log(`${r.name}: ${r.scenarioId} - válido? ${result.validations[r.scenarioId].isValid}`);
});
```

### Teste 4: UI Responsiveness

**Web**:
```typescript
// Simule clique em "Calcular Logística"
fireEvent.click(screen.getByText('Calcular Logística'));

// Espera carregamento
expect(screen.getByText('Calculando opções...')).toBeInTheDocument();

// Espera modal
await waitFor(() => {
  expect(screen.getByText('LogisticsScenarioExplainer')).toBeInTheDocument();
});
```

**iOS**:
```swift
// Teste mock
let mockScenarios = [
    LogisticsScenario(id: UUID(), name: "Uber", totalCost: 100),
]

let view = LogisticsScenarioSelectorView(
    scenarios: .constant(mockScenarios),
    selectedScenario: .constant(nil),
    gigFee: 1000,
    onDone: {}
)

// Snapshot test
assertSnapshot(matching: view, as: .image)
```

---

## 🎉 Pronto!

Você tem agora:
- ✅ Código pronto pra copiar/colar (Web + iOS)
- ✅ Solutions para problemas comuns
- ✅ Exemplos de testes
- ✅ Troubleshooting completo

Próximo passo: Deploy!

