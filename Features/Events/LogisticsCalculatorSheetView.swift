import SwiftUI

struct LogisticsCalculatorSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    let gig: Gig
    @Binding var isPresented: Bool
    
    @State private var fromCity: String = ""
    @State private var fromState: String = ""
    @State private var toCity: String = ""
    @State private var toState: String = ""
    @State private var outboundDate: Date = Date()
    @State private var returnDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 2)
    @State private var fuelPrice: String = "6.50"
    @State private var kmPerLiter: String = "12"
    @State private var estimatedTollCost: String = "50"
    @State private var estimatedDistance: Double? = nil
    @State private var estimatedCost: Double? = nil
    @State private var isCalculating = false
    @State private var airportTransportMode: String = "uber"
    @State private var airportTransportCost: String = "80"
    @State private var needsAirportTransport: Bool = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "car.fill")
                                    .foregroundStyle(PsyTheme.primary)
                                Text("Logística")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                            Text("\(gig.title) — \(gig.city)")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    
                    // Route Inputs
                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Rota")
                                .font(.headline)
                                .foregroundStyle(PsyTheme.primary)
                            
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Cidade de saída")
                                        .font(.caption)
                                    TextField("Cidade", text: $fromCity)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("UF", text: $fromState)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(PsyTheme.textSecondary)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Destino (gig)")
                                        .font(.caption)
                                    TextField("", text: .constant(gig.city))
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(true)
                                    TextField("", text: .constant(gig.state))
                                        .textFieldStyle(.roundedBorder)
                                        .disabled(true)
                                }
                            }
                        }
                    }
                    
                    // Dates
                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Datas")
                                .font(.headline)
                                .foregroundStyle(PsyTheme.primary)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Ida")
                                        .font(.caption)
                                    DatePicker("", selection: $outboundDate, displayedComponents: [.date])
                                        .tint(PsyTheme.primary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Volta")
                                        .font(.caption)
                                    DatePicker("", selection: $returnDate, displayedComponents: [.date])
                                        .tint(PsyTheme.primary)
                                }
                            }
                        }
                    }
                    
                    // Vehicle & Costs
                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Veículo e custos")
                                .font(.headline)
                                .foregroundStyle(PsyTheme.primary)
                            
                            HStack {
                                Text("Preço combustível (R$/L)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $fuelPrice)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            HStack {
                                Text("Consumo (km/L)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $kmPerLiter)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            HStack {
                                Text("Pedágio estimado (R$)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $estimatedTollCost)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                            }
                            
                            Button(action: calculateRoute) {
                                HStack {
                                    if isCalculating {
                                        ProgressView()
                                            .tint(.white)
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "magnifyingglass")
                                    }
                                    Text("Calcular rota")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(PsyTheme.primary)
                            .disabled(fromCity.isEmpty || toCity.isEmpty)
                        }
                    }
                    
                    // Airport Transport (if coming from another state)
                    if fromState != toState {
                        PsyCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "airplane")
                                                .foregroundStyle(PsyTheme.primary)
                                            Text("Transporte ao aeroporto")
                                                .font(.headline)
                                                .foregroundStyle(PsyTheme.primary)
                                        }
                                        Text("DJ precisa se deslocar até o aeroporto?")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $needsAirportTransport)
                                        .tint(PsyTheme.primary)
                                }
                                
                                if needsAirportTransport {
                                    Divider()
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Modal")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                        Picker("", selection: $airportTransportMode) {
                                            Text("🚗 Carro próprio").tag("carro")
                                            Text("🚙 Uber/Taxi").tag("uber")
                                            Text("🚌 Ônibus").tag("bus")
                                        }
                                        .pickerStyle(.segmented)
                                        .tint(PsyTheme.primary)
                                        
                                        HStack {
                                            Image(systemName: airportTransportMode == "carro" ? "fuelpump" : (airportTransportMode == "uber" ? "car.2" : "bus.fill"))
                                                .foregroundStyle(PsyTheme.primary)
                                                .font(.caption)
                                            Text(airportTransportMode == "carro" ? "Custo combustível estimado" : "Custo da corrida")
                                                .font(.caption)
                                            Spacer()
                                            TextField("", text: $airportTransportCost)
                                                .keyboardType(.decimalPad)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 100)
                                        }
                                        
                                        HStack(spacing: 4) {
                                            Image(systemName: "info.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                            Text("Este valor será somado ao break-even")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Results
                    if let distance = estimatedDistance, let cost = estimatedCost {
                        PsyCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Estimativa")
                                    .font(.headline)
                                    .foregroundStyle(PsyTheme.primary)
                                
                                HStack {
                                    Text("Distância")
                                        .font(.caption)
                                    Spacer()
                                    Text("\(Int(distance)) km")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(PsyTheme.primary)
                                }
                                
                                HStack {
                                    Text("Custo rodoviário (ida + volta)")
                                        .font(.caption)
                                    Spacer()
                                    Text("R$ \(Int(cost * 2))")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.orange)
                                }
                                
                                if needsAirportTransport && !airportTransportCost.isEmpty {
                                    Divider()
                                    HStack {
                                        Image(systemName: "airplane")
                                            .foregroundStyle(PsyTheme.primary)
                                            .font(.caption)
                                        Text("Transporte ao aeroporto")
                                            .font(.caption)
                                        Spacer()
                                        Text("R$ \(Int(Double(airportTransportCost.replacingOccurrences(of: ",", with: ".")) ?? 0))")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(PsyTheme.primary)
                                    }
                                    
                                    Divider()
                                    HStack {
                                        Text("TOTAL (deslocamento completo)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text("R$ \(Int((cost * 2) + (Double(airportTransportCost.replacingOccurrences(of: ",", with: ".")) ?? 0)))")
                                            .font(.headline.bold())
                                            .foregroundStyle(.green)
                                    }
                                } else {
                                    HStack {
                                        Text("Custo por apresentação")
                                            .font(.caption)
                                        Spacer()
                                        Text("R$ \(Int(cost))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Logística")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { isPresented = false }
                }
            }
        }
        .onAppear {
            toCity = gig.city
            toState = gig.state
        }
    }
    
    private func calculateRoute() {
        isCalculating = true
        
        // Simulated calculation (in real app, call API)
        // For now, using a simple distance estimation formula
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Simple distance estimation (in production, use real API)
            let estimatedDistanceValue = Double.random(in: 200...800)
            let fuelPriceValue = Double(fuelPrice.replacingOccurrences(of: ",", with: ".")) ?? 6.5
            let kmPerLiterValue = Double(kmPerLiter.replacingOccurrences(of: ",", with: ".")) ?? 12
            let tollCostValue = Double(estimatedTollCost.replacingOccurrences(of: ",", with: ".")) ?? 50
            
            let fuelCost = (estimatedDistanceValue / kmPerLiterValue) * fuelPriceValue
            let totalCost = fuelCost + tollCostValue
            
            await MainActor.run {
                estimatedDistance = estimatedDistanceValue
                estimatedCost = totalCost
                isCalculating = false
            }
        }
    }
}
