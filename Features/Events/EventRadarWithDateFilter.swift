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
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    @State private var selectedGenre: String?
    @State private var selectedCity: String?
    @State private var events: [RadarEvent] = []
    @State private var showDatePicker = false
    @State private var isLoading = false
    
    struct RadarEvent: Identifiable {
        let id: UUID
        let name: String
        let date: Date
        let city: String
        let genre: String
        let venue: String
    }
    
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
                    
                    // Genre filter
                    Menu {
                        Button("Todos os Gêneros", action: { selectedGenre = nil })
                        Button("Rock", action: { selectedGenre = "rock" })
                        Button("Pop", action: { selectedGenre = "pop" })
                        Button("Hip-Hop", action: { selectedGenre = "hiphop" })
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note")
                            Text(selectedGenre ?? "Gênero")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(8)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                    }
                    
                    // City filter
                    Menu {
                        Button("Todas as cidades", action: { selectedCity = nil })
                        Button("São Paulo", action: { selectedCity = "sp" })
                        Button("Rio de Janeiro", action: { selectedCity = "rj" })
                        Button("Belo Horizonte", action: { selectedCity = "bh" })
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                            Text(selectedCity ?? "Cidade")
                                .font(.caption)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(8)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                    }
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
                List(events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.name)
                                    .fontWeight(.semibold)
                                Text(event.venue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(event.date.formatted(date: .abbreviated, time: .omitted))
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
            // Simulação - conectar com API real
            try? await Task.sleep(nanoseconds: 800_000_000)
            // Aqui conectar: GET /api/radar/events?startDate=X&endDate=Y&genre=X&city=Y
            isLoading = false
        }
    }
}

#Preview {
    EventRadarWithDateFilter()
}
