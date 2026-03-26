# LearnedFacts Integration Guide

## Executive Summary

**LearnedFacts** is a declared but **unimplemented** feature that's ready for integration. The logistics API is fully operational. Manager Chat uses memories and context but doesn't yet integrate LearnedFacts.

---

## 1. LearnedFacts: Model, Usage, and Status

### Current State: **DECLARED BUT UNUSED**

**Where it appears in code:**
- **Web Backend**: `web-app/src/app/api/manager/chat/route.ts` line 31
  ```typescript
  type ChatBody = {
    ...
    learnedFacts?: string[];  // Array of learned insights
    ...
  }
  ```

- **Usage in System Prompt** (`buildKnowledgeBlock()`, lines 572-595):
  ```typescript
  function buildKnowledgeBlock(body: ChatBody): string {
    const k = body.managerKnowledge;
    const facts = body.learnedFacts ?? [];  // Extracted but NOT used in persistence
    if (!k && facts.length === 0) {
      return "";
    }

    return `
  Base de conhecimento persistente do artista (não perder):
  ...
  - Fatos aprendidos: ${facts.length > 0 ? facts.map((f) => `• ${f}`).join(" ") : "nenhum"}
    `;
  }
  ```

### What It Should Be

**LearnedFacts** = Persistent insights the Manager AI learns about the artist during conversations. Examples:
- "Artist prefers small venues under 200 people (better intimacy)"
- "Usually negotiates 20% above initial offer"
- "Active in São Paulo, Rio, and Belo Horizonte only"
- "Avoids Friday bookings (rehearsal day)"
- "Charges 2x rate for private events"

### Model Definition (NEEDS CREATION)

**Suggested Schema for iOS/Web:**

```swift
// iOS (SwiftData Model)
@Model
final class LearnedFact {
    var id: String
    var content: String  // The actual insight
    var category: String // "preference", "pricing", "location", "availability", "technical"
    var confidence: Double // 0.0-1.0 (how certain the system is)
    var source: String // "chat_history", "user_explicit", "manual_entry"
    var extractedAt: Date
    var lastUsedInChat: Date?
    var createdAt: Date = .now
}
```

**Database (Supabase):**
```sql
CREATE TABLE learned_facts (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  content TEXT NOT NULL,
  category VARCHAR(50),
  confidence FLOAT DEFAULT 0.5,
  source VARCHAR(50),
  extracted_at TIMESTAMP,
  last_used_in_chat TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Current Views/Services Using It

**On iOS:**
- `Features/Manager/ManagerChatWithMemories.swift` - has memory system (but not LearnedFacts)
- `Services/AI/WebAIService.swift` - passes learnedFacts in ChatBody (but receives undefined)
- `Features/Strategy/StrategyModuleView.swift` - references `facts: []` as placeholder (line 235)

**On Web:**
- `web-app/src/app/api/manager/chat/route.ts` - accepts learnedFacts, includes in context but doesn't persist
- `web-app/src/app/api/manager/memories/route.ts` - stores memories but NOT facts (different from learned facts)

---

## 2. Logistics API: FULLY IMPLEMENTED

### API Endpoints

#### `POST /api/logistics/estimate`
**Purpose:** Calculate distance and time between two addresses

**Request Body:**
```json
{
  "fromAddress": "Rua das Flores 123, São Paulo-SP",
  "toAddress": "Avenida Paulista 1000, São Paulo-SP"
}
```

**Response:**
```json
{
  "oneWayDistanceKm": 8.5,
  "oneWayHours": 0.25,
  "distanceKm": 17.0,
  "estimatedHours": 0.5,
  "source": "address-route"
}
```

**Address Fields Expected:**
- `fromAddress`: Full address string (street, number, city, state)
- `toAddress`: Full address string (street, number, city, state)
- Geocoding via OpenStreetMap Nominatim (Brazil-focused)
- Routing via OSRM (OpenStreetMap Routing Machine)

#### `POST /api/logistics/toll-estimate`
**Purpose:** Estimate toll costs between state pairs

**Request Body:**
```json
{
  "fromState": "SP",
  "toState": "MG",
  "oneWayDistanceKm": 450.0,
  "tripType": "round-trip"
}
```

**Response:**
```json
{
  "estimate": 245.50,
  "rationale": "Includes 3 main highways with current toll rates",
  "source": "logistics-service"
}
```

### iOS Service Layer

**File:** `Services/AI/WebAIService.swift`

**Request Types:**
```swift
struct LogisticsEstimateRequest: Encodable {
    let fromAddress: String
    let toAddress: String
}

struct LogisticsEstimateResponse: Decodable {
    let oneWayDistanceKm: Double?
    let oneWayHours: Double?
    let distanceKm: Double?
    let estimatedHours: Double?
    let source: String?
    let error: String?
}
```

**Functions:**
```swift
func estimateRoute(fromAddress: String, toAddress: String) async -> LogisticsEstimateResponse?
func estimateToll(fromState: String, toState: String, oneWayDistanceKm: Double, tripType: String) async -> TollEstimateResponse?
```

### Address/Location Services

#### `Services/Location/LocationResolver.swift`
- **Purpose:** Get current location and reverse-geocode to city/state
- **Provides:** `city`, `state` properties
- **Method:** `requestCurrentLocation()` uses CLLocationManager + CLGeocoder
- **Output:** Resolves to Brazilian city/state format

#### `Services/Logistics/ArtistLogisticsEstimator.swift`
- **Comprehensive pricing model** combining:
  - Route distance/time (from OSRM)
  - Fuel cost (liters × price per liter)
  - Toll cost (from toll-estimate endpoint)
  - Extra road costs (user input)
  - Flight alternative (if applicable)
  - Recommendation logic (road vs. flight)

**Struct Output:**
```swift
struct LogisticsEstimate {
    let road: RoadEstimate
    let flight: FlightEstimate?
    let recommendedMode: String  // "Rodoviário" or "Aéreo"
    let recommendationReason: String
}
```

### Data Flow: Location → Address → Route → Cost

```
User Location (GPS)
        ↓
LocationResolver.requestCurrentLocation()
        ↓
City + State → Manual Input
        ↓
Full Address (street required)
        ↓
estimateRoute(fromAddress, toAddress)
        ↓
Nominatim Geocoding → Lat/Lon
        ↓
OSRM Route → Distance/Hours
        ↓
ArtistLogisticsEstimator → Full Cost Breakdown
```

---

## 3. Manager Chat Integration with Memory & Context

### Current Architecture

**File:** `Features/Manager/ManagerChatWithMemories.swift`

#### Memory System (Already Implemented)
```swift
struct ManagerMemory: Identifiable {
    let id: UUID
    let title: String
    let content: String  // Latest AI response
    let createdAt: Date
}
```

**How it works:**
1. User sends message → AI responds
2. User taps "Memorizar resposta anterior" button
3. System saves last assistant message as memory
4. Next chat shows memory menu (brain icon)
5. Tapping memory injects it into next prompt

#### Context Sent to Manager AI

**Web API Input** (`ChatBody` type):
```typescript
context?: {
  leads?: number;
  gigs?: number;
  contentIdeas?: number;
  radarEvents?: number;
  confirmedGigs?: number;
  activeLeads?: number;
  averageConfirmedFee?: number;
  latestRoadCost?: number;          // ← From logistics API
  latestDistanceKm?: number;        // ← From logistics API
  nextGigDate?: string;
  topPriority?: string;
  todaySummary?: string;
  overdueFollowUps?: number;
  overdueLeadNames?: string;
  focusCities?: string;
  spotifyFollowers?: number;
  instagramFollowers?: number;
  revenue30d?: number;
  closeRate?: number;
}
```

**Manager Knowledge** (persisted separately):
```typescript
managerKnowledge?: {
  artistBio?: string;              // Artist description
  achievements?: string;           // Notable accomplishments
  citiesPlayed?: string;           // "São Paulo, Rio, BH, Curitiba"
  venuesPlayed?: string;           // "Cine Jandira, Bunker, Grazie"
  styleAndPositioning?: string;    // "Psytrance progressive, dark, atmospheric"
  baseFeeRange?: string;           // "R$ 800 - R$ 1500"
  negotiationRules?: string;       // "Never below R$ 500 unless media value"
}
```

**Learned Facts** (currently unused):
```typescript
learnedFacts?: string[];  // Array of insights like above
```

### Chat Modes & Their Context Usage

| Mode | Context | Knowledge | LearnedFacts | Output |
|------|---------|-----------|--------------|--------|
| **conversation** | ✓ | ✓ | ✗ (could use) | Conversational responses |
| **booking** | ✓ (fee, costs) | ✓ (negotiation rules) | ✗ | Booking strategy |
| **growth-insights** | ✓ (all metrics) | ✓ | ✗ | 5-block growth plan |
| **content-briefing** | ✓ (content ideas) | ✓ | ✗ | Daily content plan |
| **ops-parser** | - | - | - | JSON action commands |

### Where LearnedFacts Should Fit

**Ideal Integration Points:**

1. **Booking Mode** - Use learned facts about pricing/preferences
   ```
   Example context:
   "- Fatos aprendidos: • Normalmente negocia 20% acima da oferta inicial • Prefere eventos em São Paulo/Rio • Nunca toca sexta-feira"
   ```

2. **Growth-Insights Mode** - Reference past patterns
   ```
   "Com base nos fatos aprendidos sobre você, vejo que toca melhor em eventos pequenos-médios. Recomendo..."
   ```

3. **Memory Display** - Distinguish "facts" from "memories"
   - Memories = AI responses saved by user
   - Facts = Patterns extracted from history

---

## 4. Directory Structure & File Locations

```
IOSSimuladorStarter/
├── Domain/
│   ├── Entities/  (SwiftData Models)
│   │   ├── ArtistProfile.swift
│   │   ├── Gig.swift
│   │   ├── EventLead.swift
│   │   ├── Negotiation.swift
│   │   ├── ManagerChatMessage.swift
│   │   └── [LearnedFact.swift] ← NEEDS CREATION
│   ├── Models/
│   │   └── SmartNotificationModel.swift
│   └── Enums/
├── Features/
│   ├── Manager/
│   │   ├── ManagerChatWithMemories.swift ← Chat & memory UI
│   │   ├── ConversationListView.swift
│   │   ├── ManagerView.swift
│   │   └── MarkdownChatBubble.swift
│   └── [Manager/LearnedFactsView.swift] ← NEEDS CREATION (optional UI)
├── Services/
│   ├── AI/
│   │   └── WebAIService.swift ← API calls
│   ├── Location/
│   │   └── LocationResolver.swift ← Geocoding
│   ├── Logistics/
│   │   ├── ArtistLogisticsEstimator.swift ← Pricing
│   │   ├── RealTimeLogisticsResolver.swift
│   │   └── BrazilLogisticsReferenceService.swift
│   └── DataSyncService.swift
└── web-app/
    └── src/app/api/
        ├── manager/
        │   ├── chat/route.ts ← Main AI endpoint
        │   └── memories/route.ts ← Memory storage
        ├── logistics/
        │   ├── estimate/route.ts ← Route calculation
        │   └── toll-estimate/route.ts ← Toll pricing
        └── mobile/
            └── sync/route.ts ← Data sync
```

---

## 5. Recommended Integration Steps

### Phase 1: Backend (1-2 days)

1. **Create Supabase Table:**
   ```sql
   CREATE TABLE learned_facts (id, user_id, content, category, confidence, source, created_at);
   ```

2. **Add Web Endpoint:** `POST /api/manager/learned-facts`
   - Extract facts from user prompt (e.g., "I never negotiate below X")
   - Store in table
   - Return on GET request

3. **Update `ChatBody` Type:**
   ```typescript
   // Change from ?:string[] to populated from database
   learnedFacts: string[];  // Fetched from DB before API call
   ```

### Phase 2: iOS Frontend (2-3 days)

1. **Create LearnedFact Model** in `Domain/Entities/LearnedFact.swift`
2. **Add to Sync:**
   - Include learned_facts in `/api/mobile/sync` payload
   - Store locally in SwiftData

3. **Update ManagerChatWithMemories:**
   - Extract actionable facts from user responses
   - Send to web endpoint
   - Display in separate "Fatos Aprendidos" section

4. **Optional: Fact Extraction Logic**
   - Watch for patterns like "always/never/prefer"
   - Confirmation dialog before saving

### Phase 3: Display & Context (1-2 days)

1. **Show in Chat Context:** Include in system prompt
2. **Facts Management UI:** Simple list to edit/delete
3. **Analytics:** Track which facts are most useful

---

## Key Integration Points Summary

| Feature | Status | Location | Next Step |
|---------|--------|----------|-----------|
| **LearnedFacts Model** | ❌ Not Created | Need: `Domain/Entities/LearnedFact.swift` | Create Swift model + DB table |
| **LearnedFacts API** | ❌ Not Implemented | Need: `web-app/api/manager/learned-facts/` | Create POST/GET endpoints |
| **LearnedFacts Extraction** | ❌ Not Implemented | iOS Chat Handler | Add NLP/pattern matching |
| **LearnedFacts in Chat Context** | ⚠️ Partial | `buildKnowledgeBlock()` line 586 | Ensure fetched from DB |
| **Logistics API** | ✅ Complete | `web-app/api/logistics/` + `Services/AI/WebAIService.swift` | Use as-is |
| **Location Resolver** | ✅ Complete | `Services/Location/LocationResolver.swift` | Use as-is |
| **Memory System** | ✅ Complete | `Features/Manager/ManagerChatWithMemories.swift` | Enhance with fact distinction |

---

## Example: Complete Flow with LearnedFacts

```
User: "Tenho show amanhã em SP. Meu lugar nunca paga menos de R$ 1000"
                ↓
iOS: Extracts fact: "Artist's minimum fee: R$ 1000"
                ↓
iOS: Sends to POST /api/manager/learned-facts
                ↓
Web: Saves to database
                ↓
Next booking negotiation:
                ↓
Web: Fetches learned_facts for this artist
                ↓
Manager AI receives:
"- Fatos aprendidos: • Minimum fee: R$ 1000"
                ↓
AI Response: "Para SP, já que seu mínimo é R$ 1000 e é um show amanhã, sugiro...[strategy based on fact]"
```

