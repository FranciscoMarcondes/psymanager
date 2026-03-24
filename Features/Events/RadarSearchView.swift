import SwiftUI
import SwiftData

struct RadarSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RadarEvent.dateISO) private var radarEvents: [RadarEvent]
    
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var selectedDateRange: DateRange = .upcoming
    @State private var selectedStates: Set<String> = []
    @State private var selectedTransports: Set<String> = []
    @State private var minBudget = ""
    @State private var maxBudget = ""
    @State private var isSearching = false
    @State private var aiSuggestions: [RadarEvent] = []
    
    private let engine = CareerManagerEngine()
    private let allStates = ["AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO"]
    private let transportTypes = ["Carro", "Ônibus", "Avião", "Trem"]
    
    private enum DateRange: String, CaseIterable, Identifiable {
        case all = "Todos"
        case upcoming = "Próximos 30 dias"
        case thisMonth = "Este mês"
        case nextMonth = "Próximo mês"
        
        var id: String { rawValue }
    }
    
    private var filteredEvents: [RadarEvent] {
        var filtered = aiSuggestions.isEmpty ? radarEvents : aiSuggestions
        
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.eventName.localizedCaseInsensitiveContains(searchText) ||
                $0.city.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Filter by date range
        let now = Date()
        let calendar = Calendar.current
        switch selectedDateRange {
        case .upcoming:
            let thirtyDaysFromNow = calendar.date(byAdding: .day, value: 30, to: now) ?? Date()
            filtered = filtered.filter { date in
                if let eventDate = ISO8601DateFormatter().date(from: date.dateISO) {
                    return eventDate > now && eventDate < thirtyDaysFromNow
                }
                return false
            }
        case .thisMonth:
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: now) ?? Date()
            filtered = filtered.filter { date in
                if let eventDate = ISO8601DateFormatter().date(from: date.dateISO) {
                    return eventDate > now && eventDate < monthEnd
                }
                return false
            }
        case .nextMonth:
            let monthStart = calendar.date(byAdding: .month, value: 1, to: now) ?? Date()
            let monthEnd = calendar.date(byAdding: .month, value: 2, to: now) ?? Date()
            filtered = filtered.filter { date in
                if let eventDate = ISO8601DateFormatter().date(from: date.dateISO) {
                    return eventDate > monthStart && eventDate < monthEnd
                }
                return false
            }
        case .all:
            break
        }
        
        // Filter by states
        if !selectedStates.isEmpty {
            filtered = filtered.filter { selectedStates.contains($0.state) }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Search & Filter Header
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyinglass")
                            .foregroundStyle(PsyTheme.textSecondary)
                        
                        TextField("Buscar eventos...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(10)
                    .background(PsyTheme.secondaryBackground)
                    .cornerRadius(8)
                    
                    Button {
                        showFilters.toggle()
                        if !showFilters {
                            selectedStates.removeAll()
                            selectedTransports.removeAll()
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(selectedStates.isEmpty && selectedTransports.isEmpty ? PsyTheme.textSecondary : PsyTheme.primary)
                    }
                    .frame(width: 44, height: 44)
                    .background(PsyTheme.secondaryBackground)
                    .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                
                // AI Search Button
                Button {
                    Task {
                        await generateAIEventSuggestions()
                    }
                } label: {
                    Label("Sugerir eventos com IA", systemImage: "sparkles")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(PsyTheme.primary)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
                .disabled(isSearching)
                .padding(.horizontal, 16)
                
                // Filter Panel
                if showFilters {
                    filterPanel
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Results
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredEvents.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundStyle(PsyTheme.textSecondary)
                        
                        Text("Nenhum evento encontrado")
                            .font(.headline)
                        
                        Text("Ajuste os filtros ou gere sugestões com IA")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredEvents) { event in
                        RadarEventRow(event: event)
                            .listRowBackground(PsyTheme.cardBackground)
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("🔍 Radar de Eventos")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    // Date Range
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Período")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Picker("", selection: $selectedDateRange) {
                            ForEach(DateRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // States Filter
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estados")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(allStates, id: \.self) { state in
                                Toggle(isOn: Binding(
                                    get: { selectedStates.contains(state) },
                                    set: { if $0 { selectedStates.insert(state) } else { selectedStates.remove(state) } }
                                )) {
                                    Text(state)
                                        .font(.caption)
                                }
                                .tint(PsyTheme.primary)
                            }
                        }
                    }
                    
                    // Transport Filter
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transporte")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 8) {
                            ForEach(transportTypes, id: \.self) { type in
                                Toggle(isOn: Binding(
                                    get: { selectedTransports.contains(type) },
                                    set: { if $0 { selectedTransports.insert(type) } else { selectedTransports.remove(type) } }
                                )) {
                                    Text(type)
                                        .font(.caption)
                                }
                                .tint(PsyTheme.primary)
                            }
                        }
                    }
                    
                    // Budget Range
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Orçamento estimado (R$)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        HStack(spacing: 12) {
                            TextField("Mín", text: $minBudget)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                            
                            Text("a")
                                .foregroundStyle(PsyTheme.textSecondary)
                            
                            TextField("Máx", text: $maxBudget)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    private func generateAIEventSuggestions() async {
        isSearching = true
        defer { isSearching = false }
        
        let prompt = """
        Recomende 5 eventos musicais/festas potenciais para eventos de DJ/música em:
        Estados interessantes: \(selectedStates.isEmpty ? "Todos" : selectedStates.joined(separator: ", "))
        Período: \(selectedDateRange.rawValue)
        
        Responda com array JSON: [{"eventName": "string", "city": "string", "state": "string", "instagram": "@handle"}]
        """
        
        do {
            let response = try await engine.ask(prompt: prompt, profile: nil)
            
            if let data = response.data(using: .utf8),
               let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                
                aiSuggestions = jsonArray.compactMap { dict in
                    RadarEvent(
                        eventName: dict["eventName"] ?? "Evento",
                        city: dict["city"] ?? "",
                        state: dict["state"] ?? "",
                        dateISO: ISO8601DateFormatter().string(from: Date()),
                        instagramHandle: dict["instagram"] ?? ""
                    )
                }
            }
        } catch {
            print("Erro ao gerar sugestões: \(error)")
        }
    }
}

struct RadarEventRow: View {
    let event: RadarEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.eventName)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("\(event.city), \(event.state)")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                }
                
                Spacer()
                
                if !event.instagramHandle.isEmpty {
                    Link(destination: URL(string: "https://instagram.com/\(event.instagramHandle.replacingOccurrences(of: "@", with: ""))")!) {
                        Image(systemName: "link.circle.fill")
                            .foregroundStyle(PsyTheme.primary)
                    }
                }
            }
        }
        .padding(12)
        .background(PsyTheme.cardBackground)
        .cornerRadius(10)
    }
}

// Simple FlowLayout helper
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = proposal.replacingUnspecifiedDimensions()
        var height: CGFloat = 0
        var lineWidth: CGFloat = 0
        var currentLineHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            if lineWidth + viewSize.width + spacing <= size.width {
                lineWidth += viewSize.width + spacing
                currentLineHeight = max(currentLineHeight, viewSize.height)
            } else {
                height += currentLineHeight + spacing
                lineWidth = viewSize.width + spacing
                currentLineHeight = viewSize.height
            }
        }
        
        if lineWidth > 0 {
            height += currentLineHeight
        }
        
        return CGSize(width: size.width, height: max(height, 44))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for view in subviews {
            let viewSize = view.sizeThatFits(.unspecified)
            
            if x + viewSize.width + spacing > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += viewSize.width + spacing
            lineHeight = max(lineHeight, viewSize.height)
        }
    }
}

#Preview {
    RadarSearchView()
}
