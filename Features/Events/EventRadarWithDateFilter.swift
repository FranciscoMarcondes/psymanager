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
                
                // Date pickers inside a constrained scroll view
                ScrollView {
                    VStack(spacing: 20) {
                        // Start date
                        VStack(alignment: .leading) {
                            Label("Data de Início", systemImage: "calendar")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            DatePicker(
                                "",
                                selection: $startDate,
                                displayedComponents: [.date]
                            )
                            .datePickerStyle(.graphical)
                            .frame(maxHeight: 350)
                        }
                        
                        Divider()
                        
                        // End date
                        VStack(alignment: .leading) {
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
                            .frame(maxHeight: 350)
                        }
                    }
                    .padding()
                }
                .presentationDetents([.medium, .large])
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

    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var selectedCity: String?
    @State private var events: [RadarEvent] = []
    @State private var showDatePicker = false
    @State private var isLoading = false

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
                    // Date filter
                    Button(action: { showDatePicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text("\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                        }
                        .padding(8)
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
                        ] + Array(Set(radarEvents.map(\.city))).sorted().map {
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

    private func formattedDate(for isoDate: String) -> String {
        guard let date = eventDateFormatter.date(from: isoDate) else { return isoDate }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    EventRadarWithDateFilter()
}
