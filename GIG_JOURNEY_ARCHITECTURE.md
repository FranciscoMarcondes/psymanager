# 🎭 GIG JOURNEY ARCHITECTURE
## Refactored Gig Model & Complete DJ Workflow

---

## 1. DJ'S GIG JOURNEY (End-to-End)

```
LEAD (Prospecting)
    ↓
    DJ busca contato via networking, leads, messages
    
NEGOCIACAO (Negotiation Phase)
    ↓
    • Evento responde positivamente
    • Evento pergunta: "Você tem agência?"
    • DJ calcula seu CACHE (taxa mínima)
    • Evento aprova cache
    
LOGISTICS PHASE (If not in-state)
    ↓
    Origem: DJ Home City/UF
    Destino: Evento City/UF
    
    IF same UF:
    ├─ Calculate round-trip cost (road only)
    └─ Simple: fuel + tolls + extras
    
    IF different UF (cross-state):
    ├─ Calculate road cost to nearest airport
    ├─ SELECT transportation to airport:
    │  ├─ 🚗 Carro próprio (+ estacionamento aeroporto)
    │  ├─ 🚙 Uber/Taxi
    │  ├─ 🚌 Ônibus
    │  ├─ 🚇 Metrô
    │  └─ MULTI-MODE: Metrô + Ônibus, Uber + Ônibus, etc.
    │
    ├─ FLIGHT legs (if closing with all-inclusive fee):
    │  ├─ Departure airport (closest to DJ home)
    │  └─ Arrival airport (closest to event)
    │
    └─ Calculate airport back to home/event
        ├─ Same modes as "to airport"
        └─ Usually similar cost
    
    TOTAL LOGISTICS = Road to airport + Flight + Airport back
    
DECISION PHASE
    ↓
    • DJ evaluates all transport scenarios
    • Calculates profitability vs cache
    • Chooses best option for negotiation
    
CONFIRMATION
    ↓
    • Event approves logistics + cache
    • DJ confirms: add to calendar, reserve (blocks agenda)
    • Status: CONFIRMADO

CONTRACT PHASE (Already in platform)
    ↓
    • Register expenses (flights, transport, fuel, parking)
    • Calculate break-even
    • Plan content creation during trip
    • Archive for tax purposes
```

---

## 2. REFACTORED GIG MODEL

### Swift (iOS)

```swift
@Model
final class Gig {
    // Core info
    var title: String
    var city: String
    var state: String  // 2-letter code (SP, RJ, etc)
    var date: Date
    var fee: Double
    var contactName: String
    var checklistSummary: String
    
    // Status workflow
    var status: String  // "Lead" | "Negociacao" | "Confirmado"
    
    // Negotiation phase
    var cacheApprovedByEvent: Double?  // Value event approved for cache
    var cacheApprovedAt: Date?
    var negotiationNotes: String?
    
    // Logistics planning
    var logisticsRequired: Bool = false  // User must calculate if true
    var selectedLogisticsScenario: LogisticsScenario?  // Selected option from calculator
    var totalLogisticsCost: Double?  // Final agreed cost
    
    // Transport breakdown (for detailed logistics)
    var transportToAirport: TransportMode?  // Carro, Uber, Onibus, Metro, etc
    var flightCostEstimate: Double?  // One-way flight cost
    var airportParkingCost: Double?  // If using own car
    var transportFromAirport: TransportMode?  // Usually same as "to"
    
    // Multi-mode combinations
    var multiModeLegs: [TransportLeg] = []  // Metrô → Ônibus → Flight → Uber
    
    // Confirmation
    var addedToCalendar: Bool = false
    var reminderScheduled: Bool = false
    
    // Expenses tied to this gig
    var registeredExpenses: [Expense] = []  // Flights, transport, meals, etc
    var breakEvenData: BreakEvenCalculation?  // Link to BE calculation
}

struct LogisticsScenario: Codable {
    var id: String
    var name: String  // "Uber + Flight" | "Metro + Onibus + Flight" | etc
    var description: String
    
    // Cost breakdown
    var roadCostToAirport: Double
    var transportToAirportMode: TransportMode
    var transportToAirportCost: Double
    
    var flightCost: Double?  // If applicable
    var parkingCost: Double?  // If using car
    
    var transportFromAirportMode: TransportMode?
    var transportFromAirportCost: Double?
    
    var totalCost: Double { 
        roadCostToAirport + transportToAirportCost + 
        (flightCost ?? 0) + (parkingCost ?? 0) + 
        (transportFromAirportCost ?? 0)
    }
    
    var recommendedFor: String?  // "Best value", "Fastest", "Most comfortable"
}

struct TransportLeg: Codable, Identifiable {
    var id = UUID()
    var order: Int  // 1, 2, 3...
    var mode: TransportMode  // What transport type
    var from: String  // City/location
    var to: String  // City/location
    var estimatedCost: Double
    var estimatedDuration: String  // "1h 30min"
}

enum TransportMode: String, CaseIterable, Codable {
    case car = "Carro"
    case carSharing = "Compartilhado"
    case uber = "Uber"
    case taxi = "Taxi"
    case bus = "Ônibus"
    case metro = "Metrô"
    case train = "Trem"
    case flight = "Voo"
    
    var emoji: String {
        switch self {
        case .car: return "🚗"
        case .carSharing: return "🚕"
        case .uber: return "🚙"
        case .taxi: return "🚕"
        case .bus: return "🚌"
        case .metro: return "🚇"
        case .train: return "🚂"
        case .flight: return "✈️"
        }
    }
}
```

### TypeScript (Web)

```typescript
// web-app/src/features/workspace/types.ts

export interface Gig {
  // Core
  id: string;
  title?: string;
  venue: string;
  city: string;
  state: string;  // 2-letter code
  dateISO: string;
  fee: number;
  contact?: string;
  notes?: string;
  
  // Workflow
  status: "Lead" | "Negociacao" | "Confirmado";
  
  // Negotiation
  cacheApprovedByEvent?: number;
  cacheApprovedAt?: string;
  negotiationNotes?: string;
  
  // Logistics
  logisticsRequired: boolean;
  selectedLogisticsScenario?: LogisticsScenario;
  totalLogisticsCost?: number;
  
  // Transport breakdown
  transportToAirport?: TransportMode;
  flightCostEstimate?: number;
  airportParkingCost?: number;
  transportFromAirport?: TransportMode;
  multiModeLegs: TransportLeg[];
  
  // Confirmation
  addedToCalendar: boolean;
  reminderScheduled: boolean;
  
  // Relations
  registeredExpenseIds: string[];
  breakEvenCalculationId?: string;
}

export interface LogisticsScenario {
  id: string;
  name: string;
  description: string;
  
  roadCostToAirport: number;
  transportToAirportMode: TransportMode;
  transportToAirportCost: number;
  
  flightCost?: number;
  parkingCost?: number;
  
  transportFromAirportMode?: TransportMode;
  transportFromAirportCost?: number;
  
  totalCost: number;
  recommendedFor?: "Best value" | "Fastest" | "Most comfortable";
}

export interface TransportLeg {
  id: string;
  order: number;
  mode: TransportMode;
  from: string;
  to: string;
  estimatedCost: number;
  estimatedDuration: string;
}

export type TransportMode = 
  | "Carro" 
  | "Compartilhado" 
  | "Uber" 
  | "Taxi" 
  | "Ônibus" 
  | "Metrô" 
  | "Trem" 
  | "Voo";
```

---

## 3. GIG JOURNEY FLOW UI/UX

### Phase 1: Lead Management
```
┌─────────────────────────────────────────┐
│                  LEAD                    │
├─────────────────────────────────────────┤
│ 📱 Novo Contato (venue, contact, cache) │
│ 📋 Checklist inicial: Contract, Photo  │
│ 📅 Data prevista                        │
│ 💬 Notas de negociação                  │
│ 🎯 Ações: Enviar proposta, Agendar call│
└─────────────────────────────────────────┘
```

### Phase 2: Negotiation
```
┌──────────────────────────────────────────┐
│            NEGOCIACAO                    │
├──────────────────────────────────────────┤
│ ✅ Evento respondeu positivamente       │
│ 📊 Evento pergunta: AGÊNCIA? (SIM/NAO)  │
│ 💰 Cache proposto: R$ 2.000             │
│ ⏳ Evento APROVA cache? SIM ✓           │
│                                          │
│ ➜ PRÓXIMO: Calcular Logística          │
│   (Se for OUTRO ESTADO)                │
└──────────────────────────────────────────┘
```

### Phase 3: Logistics Calculation
```
┌──────────────────────────────────────────┐
│          CALCULAR LOGÍSTICA              │
├──────────────────────────────────────────┤
│ Origem: São Paulo, SP                   │
│ Destino: Rio de Janeiro, RJ             │
│ Data: 2026-04-15                        │
│                                          │
│ CENÁRIO 1: Carro próprio + Voo         │
│ ├─ Rodoviário SP → Aeroporto: R$ 350   │
│ ├─ Estacionamento: R$ 120               │
│ ├─ Voo ida+volta: R$ 800               │
│ ├─ Uber Aeroporto → Local: R$ 150      │
│ └─ TOTAL: R$ 1.420                     │
│                                          │
│ CENÁRIO 2: Uber + Voo                   │
│ ├─ Uber SP → Aeroporto: R$ 240         │
│ ├─ Voo ida+volta: R$ 800               │
│ ├─ Uber Aeroporto → Local: R$ 180      │
│ └─ TOTAL: R$ 1.220 ⭐ MELHOR VALOR    │
│                                          │
│ CENÁRIO 3: Ônibus + Metrô + Voo        │
│ ├─ Metrô SP → Terminal: R$ 8           │
│ ├─ Ônibus Terminal → Aeroporto: R$ 45  │
│ ├─ Voo ida+volta: R$ 800               │
│ ├─ Ônibus Aeroporto → Hotel: R$ 45     │
│ └─ TOTAL: R$ 898 ⭐ MAIS ECONÔMICO     │
└──────────────────────────────────────────┘
```

### Phase 4: Decision & Confirmation
```
┌──────────────────────────────────────────┐
│         FECHANDO O GIG                  │
├──────────────────────────────────────────┤
│ Evento APROVA:                          │
│ • Cache: R$ 2.000                       │
│ • Logística: R$ 1.220                   │
│                                          │
│ ✅ TOTAL BRUTO: R$ 3.220               │
│ (Break-even: já incluso 15% taxa)      │
│                                          │
│ 📌 DJ CONFIRMA:                         │
│ ├─ Adicionar agenda (bloqueado)        │
│ ├─ Lembrete 7 dias antes               │
│ ├─ Atribuir logística escolhida        │
│ └─ Status: CONFIRMADO ✓                │
└──────────────────────────────────────────┘
```

---

## 4. KEY IMPROVEMENTS

### ✅ Covers 80%+ of DJ Scenarios

| Scenario | Covered |
|----------|---------|
| Same state (road only) | ✅ Yes |
| Cross-state (car + flight) | ✅ Yes |
| Public transport (metro + bus) | ✅ Yes |
| Mixed modes (metro + ônibus + flight) | ✅ Yes |
| Multiple flight options | ✅ Yes |
| Parking costs | ✅ Yes |
| Different airport combos | ✅ Yes |
| Negotiation tracking | ✅ Yes |
| Cache approval workflow | ✅ Yes |

### 🎯 UX Improvements

1. **Clear Status Flow**
   - Lead → Negociação → Confirmado
   - Each phase has clear actions & requirements

2. **Multiple Logistics Scenarios**
   - 3-5 options shown side-by-side
   - Cost breakdown visible
   - Marked: "Best value" | "Fastest" | "Most comfortable"

3. **Negotiation Tracking**
   - Record when event asked about agency
   - Cache approval value & date
   - Notes for follow-ups

4. **Multi-Mode Support**
   - Metrô → Ônibus → Flight → Uber
   - Each leg shows cost & estimated duration
   - Total at end for comparison

5. **Expense Linking**
   - Register actual expenses against chosen scenario
   - Compare actual vs estimated
   - Learning for future calculations

---

## 5. IMPLEMENTATION PHASES

### Phase 1: Data Model (TODAY)
- ✅ Expand Gig struct with new fields
- ✅ Add LogisticsScenario & TransportMode
- ✅ Add TransportLeg for multi-mode

### Phase 2: Logistics Calculator (Week 1)
- Generate 3-5 scenarios automatically
- Include flight price estimator API
- Support multi-mode combinations

### Phase 3: GigJourneyFlow UI (Week 2)
- Lead form with agency question
- Negotiation tracker
- Scenario selector (visual comparison)
- Confirmation checklist

### Phase 4: Testing & Refinement (Week 3)
- Test with real DJ workflows
- Adjust scenario generation logic
- Optimize performance

---

## 6. API ENDPOINTS NEEDED

```typescript
// POST /api/logistics/flight-estimate
{
  fromAirport: "GIG",  // Rio
  toAirport: "GRU",    // São Paulo
  departDate: "2026-04-15",
  returnDate: "2026-04-16"
}
// Returns: { price: 800, provider: "Skyscanner" }

// POST /api/logistics/scenarios
{
  fromCity: "São Paulo",
  fromState: "SP",
  toCity: "Rio de Janeiro",
  toState: "RJ",
  eventDate: "2026-04-15",
  vehicleConsumption: 10,
  fuelPrice: 6.20
}
// Returns: [ LogisticsScenario[], recommendedIndex ]

// POST /api/logistics/multimode-estimate
{
  legs: [
    { mode: "Metro", from: "Home", to: "Terminal", estimatedCost: 8 },
    { mode: "Onibus", from: "Terminal", to: "Airport", estimatedCost: 45 },
    { mode: "Flight", airports: ["GRU", "SDU"], estimatedCost: 800 },
    ...
  ]
}
// Returns: { totalCost, duration, feasibility }
```

---

## 7. NEXT STEPS

1. Read this architecture with development team
2. Prioritize: which scenario is highest ROI?
3. Start with same-state (80% of gigs), add flights after
4. User test with 3-5 DJs doing real negotiations
5. Iterate based on feedback

**Estimated Implementation Time**: 2-3 weeks for full feature

