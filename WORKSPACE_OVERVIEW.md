# Workspace Structure & Implementation Overview

**Date**: 2026-03-26  
**Project**: PsyManager (iOS + Web App)  
**Scope**: Project structure, models, status values, break-even functionality, form implementations

---

## Project Architecture

```
IOSSimuladorStarter/
├── App/                          # iOS app bootstrap & routing
│   ├── AppRootView.swift
│   ├── PsyManagerApp.swift
│   └── RootTabView.swift
├── Domain/                       # Business entities & domain models
│   ├── Entities/                 # Core data models
│   ├── Enums/                    # Status & type enums
│   └── Models/
├── Features/                     # Feature modules (iOS)
│   ├── Booking/
│   ├── Components/
│   ├── Creation/                 # Content creation studio
│   ├── Dashboard/
│   ├── Events/
│   ├── Finances/                 # Financial management
│   ├── Home/
│   ├── Manager/                  # AI virtual manager
│   ├── Onboarding/
│   ├── Profile/
│   ├── Strategy/
│   └── Studio/                   # Break-even tools
├── Services/                     # External integrations
│   ├── AI/
│   ├── Calendar/
│   ├── Location/
│   ├── Networking/
│   ├── Notifications/
│   └── Insights/
├── Core/                         # Design system & shared utilities
│   └── DesignSystem/
├── Models/                       # Standalone model definitions
│   └── LearnedFact.swift
├── web-app/                      # Next.js web application
│   ├── src/
│   │   ├── app/                  # Next.js app directory
│   │   ├── components/
│   │   ├── features/             # Feature modules (web)
│   │   │   ├── events/
│   │   │   └── workspace/        # Main workspace panel
│   │   ├── hooks/
│   │   ├── lib/
│   │   └── middleware.ts
│   ├── public/
│   ├── supabase/                 # Supabase client config
│   └── package.json
└── database-migrations/          # SQL schema migrations
```

---

## 1. Gig & Lead Models with Status Values

### 1.1 iOS Side Models

#### **Gig Model** ([Domain/Entities/Gig.swift](Domain/Entities/Gig.swift))
```swift
@Model
final class Gig {
    var title: String
    var city: String
    var state: String
    var date: Date
    var fee: Double
    var contactName: String
    var checklistSummary: String
    var addedToCalendar: Bool
    var reminderScheduled: Bool
}
```
**Status**: No explicit status field in iOS Gig model (handled at financial reporting level)

---

#### **EventLead Model** ([Domain/Entities/EventLead.swift](Domain/Entities/EventLead.swift))
```swift
@Model
final class EventLead {
    var name: String
    var city: String
    var state: String
    var eventDate: Date
    var venue: String
    var instagramHandle: String
    var status: String              // ← Flexible status tracking
    var notes: String
    var promoter: PromoterContact?
}
```
**Status Field**: Stores status as String (flexible)

---

#### **Negotiation Model** ([Domain/Entities/Negotiation.swift](Domain/Entities/Negotiation.swift))
```swift
@Model
final class Negotiation {
    var stage: String               // ← Negotiation stage ("em negociação" equivalent)
    var offeredFee: Double
    var desiredFee: Double
    var notes: String
    var nextActionDate: Date
    var createdAt: Date
    var promoter: PromoterContact?
    var lead: EventLead?
}
```
**Key Field**: `stage` field tracks negotiation progress

---

### 1.2 Web App Side Models

**Location**: [web-app/src/features/workspace/types.ts](web-app/src/features/workspace/types.ts)

#### **GigStatus Type**
```typescript
export type GigStatus = "Confirmado" | "Negociacao" | "Lead";
```
**Status Values**:
- `"Confirmado"` → Confirmed gig (has fee, active)
- `"Negociacao"` → Under negotiation ("em negociação")
- `"Lead"` → Potential opportunity (not yet negotiating)

---

#### **LeadStatus Type**
```typescript
export type LeadStatus =
  | "Novo"                    // New lead
  | "Mensagem enviada"        // Message sent
  | "Aguardando"              // Awaiting response
  | "Negociando"              // Under negotiation
  | "Fechado";                // Closed (converted to gig)
```

---

#### **Gig Interface** (Web)
```typescript
export type Gig = {
  id: string;
  title?: string;
  city: string;
  venue: string;
  dateISO: string;
  fee?: number;
  contactName?: string;
  notes?: string;
  status: GigStatus;
};
```

---

#### **BookingLead Interface** (Web)
```typescript
export type BookingLead = {
  id: string;
  eventName: string;
  city?: string;
  instagram: string;
  status: LeadStatus;
  notes?: string;
  nextFollowUpISO: string;
  promoterId?: string;
};
```

---

## 2. Break-Even Functionality

### 2.1 iOS Implementation

**Primary Location**: [Features/Finances/FinancesView.swift](Features/Finances/FinancesView.swift)

#### State Variables
```swift
@State private var beGrossFee = ""
@State private var beAgencyPct = "15"      // Default agency commission %
@State private var beTaxPct = "8"          // Default tax %
@State private var beFlight = ""
@State private var beHotel = ""
@State private var beTransport = ""
@State private var beFood = ""
@State private var beOther = ""
```

#### Calculation Logic
```swift
private var beGross: Double { Double(beGrossFee.replacingOccurrences(of: ",", with: ".")) ?? 0 }
private var beAgencyValue: Double { beGross * ((Double(beAgencyPct) ?? 0) / 100) }
private var beTaxValue: Double { beGross * ((Double(beTaxPct) ?? 0) / 100) }
private var beOperational: Double {
    let flight = Double(beFlight.replacingOccurrences(of: ",", with: ".")) ?? 0
    let hotel = Double(beHotel.replacingOccurrences(of: ",", with: ".")) ?? 0
    let transport = Double(beTransport.replacingOccurrences(of: ",", with: ".")) ?? 0
    let food = Double(beFood.replacingOccurrences(of: ",", with: ".")) ?? 0
    let other = Double(beOther.replacingOccurrences(of: ",", with: ".")) ?? 0
    return flight + hotel + transport + food + other
}
private var beNet: Double { beGross - beAgencyValue - beTaxValue - beOperational }
private var beMarginPct: Int { beGross > 0 ? Int((beNet / beGross) * 100) : 0 }
private var beStatus: String {
    guard beGross > 0 else { return "" }
    if beNet > 0 { return "Lucro" }
    if beNet == 0 { return "Break-even" }
    return "Prejuízo"
}
```

#### UI Component
**Location**: [Features/Studio/BreakEvenTourCard.swift](Features/Studio/BreakEvenTourCard.swift)

```swift
struct BreakEvenTourCard: View {
    var isExpanded: Binding<Bool>
    let tourData: TourBreakEvenData
    
    struct TourBreakEvenData {
        let name: String
        let targetRevenue: Double
        let currentCosts: Double
        let projection: String
    }
}
```

#### Financial Health Dashboard
```swift
private var confirmedGigs: [Gig] {
    gigs.filter { $0.fee > 0 }
}

private var tourBreakEvenData: BreakEvenTourCard.TourBreakEvenData {
    let targetRevenue = confirmedGigs.reduce(0) { $0 + $1.fee }
    let currentCosts = expenses.reduce(0) { $0 + $1.amount }
    let confirmedCount = confirmedGigs.count
    // ... projection logic
}
```

---

### 2.2 Web App Implementation

**Primary Location**: [web-app/src/features/workspace/FinancesPanel.tsx](web-app/src/features/workspace/FinancesPanel.tsx)

#### Break-Even Section
```typescript
const beGross = parseFloat(beGrossFee.replace(",", ".")) || 0;
const beAgency = Math.max(0, parseFloat(beAgencyPct.replace(",", ".")) || 0);
const beTax = Math.max(0, parseFloat(beTaxPct.replace(",", ".")) || 0);
const beFlightCost = parseFloat(beFlight.replace(",", ".")) || 0;
const beHotelCost = parseFloat(beHotel.replace(",", ".")) || 0;
const beLocalTransportCost = parseFloat(beLocalTransport.replace(",", ".")) || 0;
const beFoodCost = parseFloat(beFood.replace(",", ".")) || 0;
const beOther = parseFloat(beOtherCosts.replace(",", ".")) || 0;

const beAgencyValue = beGross * (beAgency / 100);
const beTaxValue = beGross * (beTax / 100);
const beOperationalCosts = beFlightCost + beHotelCost + beLocalTransportCost + beFoodCost + beOther;
const beNet = beGross - beAgencyValue - beTaxValue - beOperationalCosts;
const beMarginPct = beGross > 0 ? Math.round((beNet / beGross) * 100) : 0;
const beStatus = beGross <= 0 ? "" : beNet > 0 ? "Lucro" : beNet === 0 ? "Break-even" : "Prejuízo";
```

#### Integration with Logistics
```typescript
type Props = {
  data: WorkspaceData;
  onUpdate: (updater: (prev: WorkspaceData) => WorkspaceData) => void;
  breakEvenTransportSeed?: number;  // Pre-fill from Logistics panel
};

// Pre-fill transport cost from Logistics
useEffect(() => {
  if (!breakEvenTransportSeed || breakEvenTransportSeed <= 0) return;
  setBreakEvenExpanded(true);
  setBeLocalTransport(String(breakEvenTransportSeed));
}, [breakEvenTransportSeed]);
```

#### Gig Linking
```typescript
const gigOptions = data.gigs
  .filter((g) => g.status === "Confirmado")
  .sort((a, b) => a.dateISO.localeCompare(b.dateISO));

// When gig selected, auto-populate fee
if (gig && typeof gig.fee === "number" && gig.fee > 0) {
  setBeGrossFee(String(gig.fee));
}
```

#### UI Controls
- **Toggle**: "🧮 Break-even de turnê" expandable section
- **Form Grid**: 8-field calculator (fee, agency%, tax%, flight, hotel, transfer, food, other)
- **Results Display**: Agency value, taxes, operational costs, net result, margin percentage
- **Status Badge**: "Lucro" (profit), "Break-even", "Prejuízo" (loss)

---

## 3. Form & Edit Implementations

### 3.1 iOS Forms

#### Gig Form (implied from app flow)
**Location**: Multiple features access Gig creation
- Used in: Creation, Events, Dashboard flows
- Model: [Domain/Entities/Gig.swift](Domain/Entities/Gig.swift)
- No dedicated form view found; creation likely inline in feature views

#### Lead/Event Form
**Location**: [Features/Events/EventPipelineView.swift](Features/Events/EventPipelineView.swift)
- Manages EventLead entries
- Integrates with Negotiation tracking

#### Expense Form
**Location**: [Features/Finances/FinancesView.swift](Features/Finances/FinancesView.swift) (implicit)
- Form state managed in FinancesView
- Categories: Equipamento, Transporte, Marketing, Produção musical, Alimentação, Hospedagem, Software/Assinatura, Cachê pago, Outro

#### Calendar Integration
**Location**: [Services/Calendar/CalendarService.swift](Services/Calendar/CalendarService.swift)
- Integrates with EventKit for native iOS calendar
- Used by: Gig creation, task scheduling

---

### 3.2 Web App Forms

#### **BookingPanel.tsx** - Comprehensive Booking Management
**Location**: [web-app/src/features/workspace/BookingPanel.tsx](web-app/src/features/workspace/BookingPanel.tsx)

**Sub-tabs**: leads | gigs | promoters | templates

##### Lead Form
```typescript
const [leadEvent, setLeadEvent] = useState("");
const [leadCity, setLeadCity] = useState("");
const [leadIg, setLeadIg] = useState("");
const [leadNotes, setLeadNotes] = useState("");
const [leadFollowUp, setLeadFollowUp] = useState("");

function addLead(e: FormEvent) {
  const newLead: BookingLead = {
    id: crypto.randomUUID(),
    eventName: leadEvent.trim(),
    city: leadCity.trim() || undefined,
    instagram: leadIg.trim(),
    status: "Novo",
    notes: leadNotes.trim() || undefined,
    nextFollowUpISO: leadFollowUp || new Date().toISOString().slice(0, 10),
  };
}
```
**Status Options**: "Novo" → "Mensagem enviada" → "Aguardando" → "Negociando" → "Fechado"

##### Gig Form
```typescript
const [gigTitle, setGigTitle] = useState("");
const [gigCity, setGigCity] = useState("");
const [gigVenue, setGigVenue] = useState("");
const [gigDate, setGigDate] = useState("");
const [gigFee, setGigFee] = useState("");
const [gigContact, setGigContact] = useState("");
const [gigStatus, setGigStatus] = useState<GigStatus>("Confirmado");

function addGig(e: FormEvent) {
  const newGig: Gig = {
    id: crypto.randomUUID(),
    title: gigTitle.trim() || `${gigVenue.trim()} — ${gigCity.trim()}`,
    city: gigCity.trim(),
    venue: gigVenue.trim(),
    dateISO: gigDate,
    fee: gigFee ? parseFloat(gigFee) : undefined,
    status: gigStatus,
  };
}
```
**Status Options**: "Confirmado" | "Negociacao" | "Lead"

##### Promoter Form
```typescript
const [proName, setProName] = useState("");
const [proCity, setProCity] = useState("");
const [proState, setProState] = useState("");
const [proIg, setProIg] = useState("");
const [proPhone, setProPhone] = useState("");
const [proEmail, setProEmail] = useState("");
const [proNotes, setProNotes] = useState("");
```

##### Message Template Form
```typescript
const [tplTitle, setTplTitle] = useState("");
const [tplBody, setTplBody] = useState("");
const [tplCategory, setTplCategory] = useState<TemplateCategory>("Abordagem inicial");
```

---

#### **FinancesPanel.tsx** - Financial Management
**Location**: [web-app/src/features/workspace/FinancesPanel.tsx](web-app/src/features/workspace/FinancesPanel.tsx)

**Sub-tabs**: overview | expenses | income

##### Expense Form
```typescript
const CATEGORIES: ExpenseCategory[] = [
  "Equipamento", "Transporte", "Marketing", "Produção musical",
  "Alimentação", "Hospedagem", "Software / Assinatura",
  "Cachê pago (DJ convidado)", "Outro",
];

const [newDate, setNewDate] = useState(new Date().toISOString().slice(0, 10));
const [newDesc, setNewDesc] = useState("");
const [newAmount, setNewAmount] = useState("");
const [newCategory, setNewCategory] = useState<ExpenseCategory>("Equipamento");
const [newNotes, setNewNotes] = useState("");

function addExpense(ev: FormEvent) {
  const expense: ProjectExpense = {
    id: crypto.randomUUID(),
    dateISO: newDate,
    description: newDesc.trim(),
    amount: parseFloat(newAmount.replace(",", ".")),
    category: newCategory,
    notes: newNotes.trim() || undefined,
  };
}
```

---

#### **LogisticsPanel.tsx** - Route & Cost Calculation
**Location**: [web-app/src/features/workspace/LogisticsPanel.tsx](web-app/src/features/workspace/LogisticsPanel.tsx)

**Sub-tabs**: calculator | trips | history

##### Trip Plan Form
```typescript
const [tripFrom, setTripFrom] = useState("");
const [tripTo, setTripTo] = useState("");
const [tripDate, setTripDate] = useState("");
const [tripTransport, setTripTransport] = useState<TransportMode>("Carro");
const [tripBudget, setTripBudget] = useState("");
```

##### Logistics Calculator
```typescript
const [fromCity, setFromCity] = useState("");
const [fromState, setFromState] = useState("");
const [toCity, setToCity] = useState("");
const [toState, setToState] = useState("");
const [fromAddress, setFromAddress] = useState("");
const [toAddress, setToAddress] = useState("");
const [eventDate, setEventDate] = useState("");
const [fuelPrice, setFuelPrice] = useState("6.20");
const [kmPerLiter, setKmPerLiter] = useState("10");
const [tollCost, setTollCost] = useState("0");
const [tripType, setTripType] = useState<TripType>("round-trip");
```

**Features**:
- Nominatim geocoding integration for address suggestions
- Geolocation support
- Route distance estimation
- Break-even transport cost seed integration

---

#### **ContentStudioPanel.tsx** - Content Planning & Creation
**Location**: [web-app/src/features/workspace/ContentStudioPanel.tsx](implied presence)

**Supported Content Types**: Reel | Carrossel | Post | Story  
**Content Status**: Ideia | Roteirizado | Agendado | Publicado  
**Content Objectives**: Alcance | Engajamento | Conversao | Prova social

---

#### **ManagerPanel.tsx** - AI Assistant Interaction
**Location**: [web-app/src/features/workspace/ManagerPanel.tsx](implied presence)

**Functionality**:
- Conversational interface with AI manager
- Knowledge base management (artist bio, achievements, fee ranges, negotiation rules)
- Archived conversations
- Smart command parsing (add_task, complete_task, add_gig, add_radar_event, etc.)

---

## 4. Expense Model

### 4.1 iOS Expense Model
**Location**: [Domain/Entities/Expense.swift](Domain/Entities/Expense.swift)

```swift
@Model
final class Expense {
    var dateISO: String                  // "yyyy-MM-dd"
    var descriptionText: String
    var amount: Double
    var category: String                 // Flexible category field
    var notes: String
}
```

---

### 4.2 Web Expense Model
**Location**: [web-app/src/features/workspace/types.ts](web-app/src/features/workspace/types.ts)

```typescript
export type ProjectExpense = {
  id: string;
  dateISO: string;
  description: string;
  amount: number;
  category: ExpenseCategory;
  notes?: string;
};

export type ExpenseCategory =
  | "Equipamento"
  | "Transporte"
  | "Marketing"
  | "Produção musical"
  | "Alimentação"
  | "Hospedagem"
  | "Software / Assinatura"
  | "Cachê pago (DJ convidado)"
  | "Outro";
```

---

## 5. Financial Metrics & Dashboard

### 5.1 iOS Metrics
```swift
private var confirmedGigRevenue: Double {
    gigs.filter { $0.fee > 0 }.reduce(0) { $0 + $1.fee }
}

private var totalExpenses: Double {
    expenses.reduce(0) { $0 + $1.amount }
}

private var netBalance: Double { gigRevenue - totalExpenses }

private var healthPct: Int {
    guard gigRevenue > 0 else { return 0 }
    return min(100, max(0, Int((netBalance / gigRevenue) * 100)))
}

private var healthLabel: String {
    healthPct >= 60 ? "Saudável" : healthPct >= 30 ? "Atenção" : "Crítico"
}
```

### 5.2 Web Dashboard Integration
**Financial Health Score**: Percentage of revenue retained as profit  
**Color Coding**:
- 🟢 ≥60% = "Saudável" (Healthy)
- 🟡 30-59% = "Atenção" (Warning)
- 🔴 <30% = "Crítico" (Critical)

---

## 6. API & Backend Integration

### 6.1 Web App API Routes
**Location**: [web-app/src/app/api/](web-app/src/app/api/)

Available endpoints:
- `/api/auth/` - Authentication
- `/api/content-plan/` - Content management
- `/api/debug/` - Debug utilities
- `/api/generate-cover/` - Cover generation
- `/api/generate-cover-prompt/` - Cover prompt generation
- `/api/instagram/` - Instagram integration
- `/api/logistics/` - Logistics calculations
- `/api/manager/` - AI manager
- `/api/mobile/` - Mobile sync
- `/api/notifications/` - Notifications
- `/api/radar/` - Event radar
- `/api/spotify/` - Spotify integration
- `/api/templates/` - Message templates (PUT for sync)
- `/api/workspace/` - Workspace CRUD
- `/api/voice/` - Voice processing

### 6.2 Database
**Type**: Supabase (PostgreSQL)  
**Location**: [database-migrations/](database-migrations/)

---

## 7. Key Integration Points

### 7.1 Logistics ↔ Break-Even Handoff
```typescript
// LogisticsPanel passes calculated transport cost to FinancesPanel
<FinancesPanel
  onUpdate={onUpdate}
  breakEvenTransportSeed={transportCostResult}
/>

// FinancesPanel pre-fills transport field
useEffect(() => {
  if (!breakEvenTransportSeed || breakEvenTransportSeed <= 0) return;
  setBreakEvenExpanded(true);
  setBeLocalTransport(String(breakEvenTransportSeed));
}, [breakEvenTransportSeed]);
```

### 7.2 Gig Linking to Break-Even
- Select confirmed gig → auto-populate fee
- iOS: via selectedBreakEvenGig binding
- Web: via selectedGigId dropdown

### 7.3 Lead → Gig Conversion
- When LeadStatus changes to "Fechado" (closed), trigger gig creation
- iOS: EventLead + Negotiation → Gig
- Web: updateLeadStatus("Fechado") → navigate to Gigs tab

---

## Summary Table: Status Values

| Concept | iOS | Web | Purpose |
|---------|-----|-----|---------|
| **Gig Status** | EventLead.status | GigStatus | Track gig booking stage |
| **Lead Status** | EventLead.status | LeadStatus | Track prospect engagement |
| **Negotiation** | Negotiation.stage | Implicit in status | Document fee discussions |
| **Content Status** | SocialContentPlanItem.status | ContentStatus | Track content lifecycle |
| **Em Negociação** | "Negociação"/custom | "Negociacao" (Gig) / "Negociando" (Lead) | Under fee discussion |

---

## Key Files Reference

| Component | iOS | Web |
|-----------|-----|-----|
| Gig Model | [Domain/Entities/Gig.swift](Domain/Entities/Gig.swift) | [workspace/types.ts](web-app/src/features/workspace/types.ts) |
| Event Lead | [Domain/Entities/EventLead.swift](Domain/Entities/EventLead.swift) | [workspace/types.ts](web-app/src/features/workspace/types.ts) |
| Break-Even UI | [Features/Finances/FinancesView.swift](Features/Finances/FinancesView.swift) | [FinancesPanel.tsx](web-app/src/features/workspace/FinancesPanel.tsx) |
| Break-Even Card | [Features/Studio/BreakEvenTourCard.swift](Features/Studio/BreakEvenTourCard.swift) | N/A |
| Logistics | [Features/Events/](Features/Events/) | [LogisticsPanel.tsx](web-app/src/features/workspace/LogisticsPanel.tsx) |
| Booking Forms | Scattered in Features | [BookingPanel.tsx](web-app/src/features/workspace/BookingPanel.tsx) |
| Calendar | [Services/Calendar/CalendarService.swift](Services/Calendar/CalendarService.swift) | N/A (implicit in dates) |

