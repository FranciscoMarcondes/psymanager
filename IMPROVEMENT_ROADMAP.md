# 🚀 Roadmap de Melhorias - PsyManager App/Web

## 📊 Resumo das Melhorias

Total: **15 melhorias críticas** | Prioridade: Imediata, Alta, Média

---

## 🔴 PRIORIDADE IMEDIATA (Semana 1)

### 1. **Perfil: Perda de Foto após Login Facebook** ⚠️ CRÍTICO
**Status**: Identificado  
**Impacto**: Dados do usuário se perdem  
**Plataformas**: Web + iOS

**Problema**:
- User loga com Facebook
- Foto e informações desaparecem após atualizar

**Solução Técnica**:
```typescript
// Em /api/auth/mobile-facebook-callback (web)
// Adicionar:
- SalvarproviderAccountId do Facebook
- Manter URL da foto do Facebook mesmo se não tiver email
- Sincronizar provider_avatar_url com psy_users
- Na sessão, carregar foto do provider se foto local vazia
```

**Implementação**:
- [ ] Verificar sync entre Facebook provider data e psy_users table
- [ ] Adicionar fallback para foto do Facebook
- [ ] Testar com login via web + iOS

---

### 2. **Avisos Inteligentes: Não Clicável + Fixo**
**Status**: Design issue  
**Impacto**: User experience ruim  
**Plataformas**: Web + iOS

**Problemas**:
- Não é clicável → deveria levar para atividade
- Fixo → deveria atualizar em tempo real
- Sem exclusão → deveria poder descartar

**Solução Técnica**:
```swift
// iOS: NotificationCard.swift (novo)
struct SmartNotificationCard: View {
    @State private var notification: SmartNotification
    
    var body: some View {
        NavigationLink(destination: ActivityDetailView(id: notification.activityId)) {
            HStack {
                VStack(alignment: .leading) {
                    Text(notification.title)
                    Text(notification.description).font(.caption2)
                }
                Spacer()
                Button(action: { dismissNotification() }) {
                    Image(systemName: "xmark.circle.fill")
                }
            }
            .onReceive(notificationTimer) { _ in
                refreshNotification()
            }
        }
    }
    
    private func dismissNotification() {
        // DELETE /api/notifications/{id}
    }
}
```

**Implementação**:
- [ ] Adicionar endpoint GET `/api/notifications` (real-time)
- [ ] WebSocket ou polling a cada 30s
- [ ] Tornar clicável → NavigationLink
- [ ] Adicionar botão fechar (DELETE)
- [ ] Aplicar em ambos web + iOS

---

### 3. **Break-even de Turnê: Minimizado**
**Status**: UI/UX  
**Impacto**: Reduz poluição visual no módulo Estúdio

**Solução**:
```swift
// iOS: TourBreakEvenCard.swift
struct TourBreakEvenCard: View {
    @State private var isExpanded = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Conteúdo detalhado
            BreakEvenDetail()
        } label: {
            HStack {
                Image(systemName: "chart.bar.fill")
                Text("Break-even: R$ 50.000")
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
            .background(PsyTheme.card)
        }
    }
}
```

**Implementação**:
- [ ] Converter para collapsed por padrão (disclosure)
- [ ] Aplicar em iOS
- [ ] Aplicar em Web (accordion)

---

## 🟠 PRIORIDADE ALTA (Semana 2)

### 4. **BackLog → Calendário Síncrono**
**Status**: Business logic issue  
**Impacto**: Fluxo complexo precisa ser refinado

**Ideia do User**:
```
Backlog (idea) 
    ↓ move
Rascunhado (pode editar, preparar)
    ↓ move
Agendado (aparece no calendário)
    ↓ move
Publicado (sai do backlog, riscado no calendário com ✓)
```

**Implementação**:
```typescript
// Database: content_plan_items table
const statuses = {
  'BACKLOG': 'idea', // Ideia não agendada
  'DRAFTED': 'preparing', // Rascunhado, pronto para agendar
  'SCHEDULED': 'calendar_visible', // No calendário
  'PUBLISHED': 'strikethrough', // Publicado, riscado
  'ARCHIVED': 'hidden' // Opcinal: arquivado
}

// Rules:
// BACKLOG → DRAFTED: pode editar conteúdo
// DRAFTED → SCHEDULED: precisa ter data (vai pro calendário)
// SCHEDULED → PUBLISHED: marca como publicado
// PUBLISHED: Move para arquivos, mostra riscado no calendário por 7 dias
```

**Implementação**:
- [ ] Migrar banco de dados: adicionar status column
- [ ] Criar endpoints PATCH `/api/content-plan/{id}/status`
- [ ] Avisar quando mudar de SCHEDULED → PUBLISHED
- [ ] UI: Mostrar status visual em cores
- [ ] Sincronizar BackLog ↔ Calendário

---

### 5. **Agendar Conteúdo + Radar: Date Picker Transpassa Tela**
**Status**: Layout bug  
**Impacto**: UX ruim, data picker fica fora da área visível

**Solução**:
```swift
// iOS: DatePickerBottomSheet.swift
struct DatePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack {
            HStack {
                Text("Selecionar Data").font(.headline)
                Spacer()
                Button("Fechar") { dismiss() }
            }
            .padding()
            
            // Modal sheet ao invés de popup
            DatePicker("Data", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
            
            Button("Confirmar", action: {
                applyDate(selectedDate)
                dismiss()
            })
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .presentationDetents([.medium, .large])
    }
}
```

**Implementação**:
- [ ] Converter date picker para modal sheet (iOS)
- [ ] Usar popover com contraints no Web
- [ ] Testar em diferentes tamanhos de tela

---

### 6. **Dark Mode: Símbolo ˆ Invisível em Popups**
**Status**: UI bug  
**Impacto**: Acessibilidade ruim

**Solução**:
```swift
// iOS: Aplicar em todos popups/menus
Menu {
    // Items
} label: {
    HStack {
        Text("Crescimento")
        Image(systemName: "chevron.down")
            .foregroundStyle(.white) // Força cor clara
    }
}
```

**Implementação**:
- [ ] Adicionar `.foregroundStyle()` explícito
- [ ] Testar em dark mode
- [ ] Aplicar em todas selection views

---

### 7. **Plano Editorial: Remover Conteúdo Publicado**
**Status**: Business logic  
**Impacto**: Confusão quando conteúdo aparece em múltiplos lugares

**Solução**:
```typescript
// Regra: Após PUBLISHED, move para "Publicados" (histórico)
// Plano Editorial mostra apenas: BACKLOG, DRAFTED, SCHEDULED
// Publicados são arquivo-only

GET /api/content-plan?status=BACKLOG,DRAFTED,SCHEDULED // Plano editorial
GET /api/content-plan?status=PUBLISHED // Histórico de publicados
```

**Implementação**:
- [ ] Adicionar status filter nos endpoints
- [ ] Criar aba "Histórico" no Plano Editorial
- [ ] Aplicar regra no Backlog também

---

### 8. **Manager IA: Ocultar "Memórias Salvas"**
**Status**: UI/UX  
**Impacto**: Reduz poluição visual

**Solução**:
```swift
// iOS: ManagerView.swift
struct ManagerChatView: View {
    @State private var messages: [ManagerMessage] = []
    @State private var showMemories = false // Default: false
    
    var body: some View {
        VStack {
            ChatMessages(messages: messages)
            
            // Memórias: Menu opcional ao invés de sempre visível
            Menu {
                ForEach(savedMemories) { memory in
                    Button(memory.name) {
                        insertMemory(memory)
                    }
                }
            } label: {
                Image(systemName: "brain.fill")
                    .foregroundStyle(.blue)
            }
            
            InputField(onSend: sendMessage)
        }
    }
}
```

**Implementação**:
- [ ] Mover memórias para Menu (+) ao invés de sempre visível
- [ ] Aplicar em Web também
- [ ] Limpar espaço visual

---

## 🟡 PRIORIDADE MÉDIA (Semana 3)

### 9. **Pesquisa por Evento: Adicionar Filtro de Datas**
**Status**: Feature missing  
**Impacto**: Melhor discovery

**Solução**:
```typescript
// GET /api/radar/events?startDate=2026-03-25&endDate=2026-04-25&genre=rock
GET /api/radar/events {
  startDate?: Date
  endDate?: Date
  genre?: string
  city?: string
  priceMin?: number
  priceMax?: number
}
```

**Implementação**:
- [ ] Adicionar DateRangeFilter component
- [ ] Criar API endpoint com filtros
- [ ] Aplicar em iOS + Web

---

### 10. **Manager IA: Memorizar com Confirmação**
**Status**: UX improvement  
**Impacto**: Feedback melhor ao user

**Solução**:
```swift
// iOS: ManagerView.swift
Button("Memorizar") {
    sendMemoryRequest()
}
.alert("Salvo!", isPresented: $showMemorySaved) {
    Button("Ok") { }
} message: {
    Text("A IA vai usar essa informação para análises futuras")
}
```

**Implementação**:
- [ ] Adicionar POST `/api/manager/memories`
- [ ] Retornar confirmação com toast/alert
- [ ] Mostrar timestamp da última memória salva

---

### 11. **Manager IA: Manager Pode Fazer Perguntas**
**Status**: Feature enhancement  
**Impacto**: Melhor AI learning

**Solução**:
```typescript
// POST /api/manager/chat - AI pode incluir questions[]
{
  role: "assistant",
  content: "Achei que você trabalha com Rock. Correto?",
  questions: [
    { id: 1, text: "Qual seu gênero principal?", type: "text" },
    { id: 2, text: "Quantos shows fez esse mês?", type: "number" }
  ]
}
```

**Implementação**:
- [ ] Adicionar system prompt para AI fazer perguntas
- [ ] UI para responder perguntas inline
- [ ] Salvar respostas como memórias

---

### 12. **Módulo Estratégia: Salvar Sugestões → Backlog**
**Status**: Critical UX issue - dados se perdem!

**Solução**:
```swift
// iOS: StrategyView.swift
struct AISuggestionCard: View {
    let suggestion: AISuggestion
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(suggestion.content)
            
            HStack {
                Button(action: { saveToBBcklog() }) {
                    Label("Salvar no Backlog", systemImage: "bookmark.fill")
                }
                
                Button(action: { saveChat() }) {
                    Label("Salvar Chat", systemImage: "message.fill")
                }
            }
        }
    }
    
    private func saveToBacklog() {
        // POST /api/content-plan
        // Com: title, description, media, status: "BACKLOG"
    }
}
```

**Implementação**:
- [ ] Adicionar botão "Salvar no Backlog"
- [ ] Permitir editar título/descrição antes de salvar
- [ ] Implementar "Salvar Chat" (thread completa)
- [ ] Adicionar "Recuperar última conversa"
- [ ] Adicionar "Limpar chat"

---

### 13. **Tarefas da Semana: Avaliar Duplicação**
**Status**: Product decision needed

**Análise**:
- **Tarefas da Semana**: Mostra tasks para completar
- **Agendar Conteúdo**: Agenda conteúdo específico

**Recomendação**:
```
Se "Tarefas da Semana" = apenas content agendado:
  → Remover e usar Agendar Conteúdo como fonte única

Se "Tarefas da Semana" = inclui outras tasks (shows, emails, etc):
  → Manter mas clarificar diferença na UI
```

**Implementação**:
- [ ] Entrevista: O que deve aparecer em "Tarefas da Semana"?
- [ ] Se duplicado: remover ou consolidar
- [ ] Se diferente: documentar regras de filtro

---

## 💎 MELHORIAS DE PERFUMARIA

### 14. **Chat Manager IA: Formatar Markdown Corretamente**
**Status**: UI/UX  
**Impacto**: Legibilidade melhor

**Problema**: Respostas com `**bold**`, `*italic*`, `- lista` aparecem com símbolos

**Solução**:
```swift
// iOS: ManagerChatBubble.swift
struct ChatBubble: View {
    let message: Message
    
    var body: some View {
        VStack(alignment: .leading) {
            // Usar markdown rendering
            Text(.init(message.content))
                .textSelection(.enabled)
                .padding()
        }
    }
}
```

**Implementação**:
- [ ] Adicionar `Text(.init())` para markdown rendering
- [ ] Testar com bold, italic, listas
- [ ] Aplicar em Web + iOS

---

### 15. **BackLog: Remover Conteúdo Publicado**
**Status**: Business logic (similar ao editorial)

**Regra**:
```
Status PUBLISHED não deve aparecer em BackLog
Mostrar em "Publicados" (histórico/arquivo)
```

**Implementação**:
- [ ] Filtrar status=PUBLISHED fora do backlog
- [ ] Criar seção "Publicados"
- [ ] Aplicar em iOS + Web

---

## 📱 BÔNUS: Sugestões do Copilot

### ✨ Melhorias Recomendadas (não mencionadas):

1. **Notificações Push**
   ```
   - Quando comentam em post
   - Quando evento novo em sua região
   - Quando alcançou meta de seguidores
   - Lembretes de conteúdo agendado
   ```

2. **Busca Global**
   ```
   - Procurar eventos, conteúdo, artistas
   - Índice full-text em PostgreSQL
   ```

3. **Dark Mode Completo**
   ```
   - Verificar todos componentes em dark mode
   - Testar todas cores em ambos temas
   ```

4. **Sincronização de Calendário Externo**
   ```
   - Google Calendar export
   - Apple Calendar integration
   - Sincronizar shows que você vai
   ```

5. **Analytics Dashboard**
   ```
   - Gráficos de crescimento
   - ROI de campanhas
   - Performance de conteúdo
   ```

6. **Integração Spotify/YouTube Real**
   ```
   - Atualizar dados automaticamente
   - Não apenas snapshot manual
   ```

---

## 🎯 PLANO DE EXECUÇÃO

### Semana 1 (Essa)
- [x] Prioridade Imediata: Perda de foto, Avisos, Break-even

### Semana 2
- [ ] Prioridade Alta: Backlog sync, Date picker, Dark mode

### Semana 3
- [ ] Prioridade Média: Search, Manager questions, Estratégia

### Semana 4
- [ ] Perfumaria + testes

---

## 📊 Estimativas de Esforço

| Item | Complexidade | Dias | Prioridade |
|------|-------------|------|-----------|
| Perda foto Facebook | Media | 1 | 🔴 |
| Avisos inteligentes | Alta | 2 | 🔴 |
| Break-even minimizado | Baixa | 0.5 | 🔴 |
| Backlog ↔ Calendário | Alta | 3 | 🟠 |
| Date picker overflow | Baixa | 1 | 🟠 |
| Dark mode símbolo | Baixa | 0.5 | 🟠 |
| Plano editorial status | Media | 1 | 🟠 |
| Ocultar memórias | Baixa | 0.5 | 🟠 |
| Search com datas | Media | 1.5 | 🟡 |
| Memorizar confirmação | Baixa | 0.5 | 🟡 |
| Manager faz perguntas | Alta | 2.5 | 🟡 |
| Estratégia salvar | Alta | 2 | 🟡 |
| Tarefas duplicação | Media | 1 | 🟡 |
| Chat markdown | Baixa | 1 | 💎 |
| Backlog publicados | Baixa | 0.5 | 💎 |

**Total**: ~18 dias = 3.6 semanas

---

## ✅ Próximas Ações

1. **Agora**: Identificar qual melhorias fazer primeira
2. **Git**: Criar branches para cada item
3. **Testing**: Testar em device real (iOS)
4. **Deploy**: Vercel auto-deploy para web

Qual dessas você quer que eu comece a implementar?
