import SwiftData
import SwiftUI

struct DateRangePickerView: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Environment(\.dismiss) var dismiss
    
    var onConfirm: () -> Void = {}
    
    private let calendar = Calendar.current
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Selecionar Período")
                        .font(.headline)
                    Spacer()
                    Button("Fechar") { dismiss() }
                        .foregroundStyle(.blue)
                }
                .padding()
                
                Divider()
                
                // Date pickers with generous sizing
                ScrollView {
                    VStack(spacing: 24) {
                        // Start date
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Data de Início", systemImage: "calendar")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            DatePicker(
                                "",
                                selection: $startDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .frame(minHeight: 400)
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // End date
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Data de Término", systemImage: "calendar")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            DatePicker(
                                "",
                                selection: $endDate,
                                in: startDate...,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .frame(minHeight: 400)
                        }
                    }
                    .padding()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                
                Divider()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button(action: reset) {
                        Text("Limpar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        onConfirm()
                        dismiss()
                    }) {
                        Text("Aplicar")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func reset() {
        startDate = Date()
        endDate = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    }
}

// MARK: - Event Search with Date Filter
struct EventRadarWithDateFilter: View {
    @Query(sort: \RadarEvent.dateISO) private var radarEvents: [RadarEvent]
    @Query(sort: \EventLead.eventDate) private var leads: [EventLead]
    @Query(sort: \Gig.date) private var gigs: [Gig]

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var selectedCity: String?
    @State private var events: [RadarEvent] = []
    @State private var showDatePicker = false
    @State private var isLoading = false
    @State private var selectedRangePreset: DatePreset = .upcoming30

    private enum DatePreset: String, CaseIterable, Identifiable {
        case all = "Todos"
        case upcoming30 = "Próximos 30 dias"
        case thisMonth = "Este mês"
        case nextMonth = "Próximo mês"

        var id: String { rawValue }
    }

    private var availableCities: [String] {
        let fromRadar = radarEvents.map(\.city)
        let fromLeads = leads.map(\.city)
        let fromGigs = gigs.map(\.city)
        let fallback = ["São Paulo", "Rio de Janeiro", "Belo Horizonte", "Curitiba", "Florianópolis", "Brasília"]
        return Array(Set(fromRadar + fromLeads + fromGigs + fallback))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    private let eventDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init() {}
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Picker("Período", selection: $selectedRangePreset) {
                        ForEach(DatePreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)

                    // Date filter
                    Button(action: { showDatePicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.body)
                        }
                        .padding(10)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                    }
                    
                    // City filter
                    AccessibleMenuButton(
                        label: HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                            Text(selectedCity ?? "Cidade")
                                .font(.caption)
                        },
                        options: [
                            AccessibleMenuButton.MenuOption(label: "Todas as cidades", value: "", icon: nil)
                        ] + availableCities.map {
                            AccessibleMenuButton.MenuOption(label: $0, value: $0, icon: nil)
                        },
                        onSelect: { value in
                            selectedCity = value.isEmpty ? nil : value
                            searchEvents()
                        }
                    )
                }
                .padding()
            }
            
            Divider()
            
            // Events list
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                    Text("Nenhum evento encontrado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(events, id: \.persistentModelID) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.eventName)
                                    .fontWeight(.semibold)
                                Text("@\(event.instagramHandle.isEmpty ? "sem contato" : event.instagramHandle)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(formattedDate(for: event.dateISO))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(event.city)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DateRangePickerView(
                startDate: $startDate,
                endDate: $endDate,
                onConfirm: { searchEvents() }
            )
        }
        .onAppear {
            searchEvents()
        }
        .onChange(of: selectedRangePreset) {
            updateDatesForPreset()
            searchEvents()
        }
    }
    
    private func searchEvents() {
        isLoading = true
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)

            let filtered = radarEvents.filter { event in
                guard let eventDate = eventDateFormatter.date(from: event.dateISO) else { return false }
                let matchesDate = eventDate >= Calendar.current.startOfDay(for: startDate)
                    && eventDate <= Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate)!
                let matchesCity = selectedCity == nil || event.city.caseInsensitiveCompare(selectedCity ?? "") == .orderedSame
                return matchesDate && matchesCity
            }

            await MainActor.run {
                events = filtered
                isLoading = false
            }
        }
    }

    private func updateDatesForPreset() {
        let calendar = Calendar.current
        let now = Date()
        switch selectedRangePreset {
        case .all:
            startDate = calendar.date(byAdding: .year, value: -5, to: now) ?? now
            endDate = calendar.date(byAdding: .year, value: 5, to: now) ?? now
        case .upcoming30:
            startDate = now
            endDate = calendar.date(byAdding: .day, value: 30, to: now) ?? now
        case .thisMonth:
            startDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) ?? now
        case .nextMonth:
            let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            startDate = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? now
            endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate) ?? now
        }
    }

    private func formattedDate(for isoDate: String) -> String {
        guard let date = eventDateFormatter.date(from: isoDate) else { return isoDate }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    EventRadarWithDateFilter()
}
