import SwiftUI
import CoreLocation

struct QuickLogisticsCalculatorView: View {
    @StateObject private var locationResolver = LocationResolver()

    @State private var originCity = ""
    @State private var originState = ""
    @State private var destinationCity = ""
    @State private var destinationState = ""
    @State private var eventDate = Date().addingTimeInterval(60 * 60 * 24 * 14)
    @State private var returnDate = Date().addingTimeInterval(60 * 60 * 24 * 15)

    @State private var fuelPrice = "6.20"
    @State private var vehicleKmPerLiter = "10"
    @State private var tollCost = "120"
    @State private var extraRoadCosts = "0"

    @State private var estimate: LogisticsEstimate?
    @State private var calculatorMessage = ""
    @State private var useRealTimeData = false
    @State private var isLoading = false
    @State private var estimateHistory: [SavedLogisticsEstimate] = []
    @State private var webRouteMessage = ""
    @State private var isLoadingWebRoute = false

    var body: some View {
        NavigationStack {
            List {
                Section("Origem") {
                    HStack {
                        Toggle("Usar dados em tempo real", isOn: $useRealTimeData)
                        Image(systemName: APIConfiguration.isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundStyle(APIConfiguration.isConfigured ? .green : .orange)
                            .font(.caption)
                    }

                    if useRealTimeData && !APIConfiguration.isConfigured {
                        Text("As chaves de API ainda não foram configuradas. O app usa fallback local automaticamente.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if useRealTimeData {
                        Text("Provedor de voo: \(APIConfiguration.flightProviderSelection.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Usar localização atual") {
                        locationResolver.requestCurrentLocation()
                    }
                    .buttonStyle(.bordered)

                    if !locationResolver.statusMessage.isEmpty {
                        Text(locationResolver.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    TextField("Cidade", text: $originCity)
                        .textContentType(.location)
                    TextField("Estado (UF)", text: $originState)
                        .textInputAutocapitalization(.characters)
                }

                Section("Destino") {
                    TextField("Cidade", text: $destinationCity)
                        .textContentType(.location)
                    TextField("Estado (UF)", text: $destinationState)
                        .textInputAutocapitalization(.characters)
                }

                Section("Datas") {
                    DatePicker("Saída", selection: $eventDate, displayedComponents: [.date])
                    DatePicker("Retorno", selection: $returnDate, displayedComponents: [.date])
                }

                Section("Veículo") {
                    TextField("Preço combustível (R$/L)", text: $fuelPrice)
                        .keyboardType(.decimalPad)
                    TextField("Consumo (km/L)", text: $vehicleKmPerLiter)
                        .keyboardType(.decimalPad)
                    TextField("Pedágios totais (R$)", text: $tollCost)
                        .keyboardType(.decimalPad)
                    TextField("Custos extras (R$)", text: $extraRoadCosts)
                        .keyboardType(.decimalPad)

                    Button("Usar combustível médio da UF de origem") {
                        applyFuelReference()
                    }
                    .buttonStyle(.bordered)

                    Button("Sugerir pedágios pela rota") {
                        applyTollReference()
                    }
                    .buttonStyle(.bordered)
                }

                Section {
                    Button("Calcular logística") {
                        calculateLogistics()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PsyTheme.primary)
                    .frame(maxWidth: .infinity)
                    .disabled(isLoading)

                    Button(action: calcWebRoute) {
                        HStack {
                            if isLoadingWebRoute { ProgressView().tint(.white).controlSize(.small) }
                            Text(isLoadingWebRoute ? "Calculando rota..." : "Calcular por endereço (Web)")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(PsyTheme.secondary)
                    .frame(maxWidth: .infinity)
                    .disabled(isLoadingWebRoute || originCity.isEmpty || destinationCity.isEmpty)

                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Consultando dados...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !calculatorMessage.isEmpty {
                        Text(calculatorMessage)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.primary)
                    }
                    if !webRouteMessage.isEmpty {
                        Text(webRouteMessage)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.secondary)
                    }
                }

                if let estimate {
                    resultSections(for: estimate)
                }

                if !estimateHistory.isEmpty {
                    Section("Histórico recente") {
                        ForEach(estimateHistory.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(item.originLabel) → \(item.destinationLabel)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text("Modal: \(item.recommendedMode) • Rodoviário: R$ \(Int(item.roadTotal.rounded()))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let airTotal = item.airTotal {
                                    Text("Aéreo: R$ \(Int(airTotal.rounded())) • Tarifa: \(item.pricingSourceLabel ?? "-")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Text("Rota: \(item.routeSourceLabel)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calculadora Avulsa")
            .scrollContentBackground(.hidden)
            .background(PsyTheme.background)
        }
        .onAppear {
            estimateHistory = LogisticsEstimateHistoryStore.load()
        }
        .onChange(of: locationResolver.city) {
            if !locationResolver.city.isEmpty {
                originCity = locationResolver.city
            }
        }
        .onChange(of: locationResolver.state) {
            if !locationResolver.state.isEmpty {
                originState = locationResolver.state
            }
        }
    }

    @ViewBuilder
    private func resultSections(for estimate: LogisticsEstimate) -> some View {
        Section("Resultado da Estimativa") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Modal recomendado")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(estimate.recommendedMode)
                        .font(.headline)
                        .foregroundStyle(PsyTheme.primary)
                }
                Text(estimate.recommendationReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }

        Section("Custo Rodoviário") {
            VStack(alignment: .leading, spacing: 6) {
                resultRow(label: "Fonte da rota", value: estimate.road.routeSource.label)
                resultRow(label: "Distância", value: "\(Int(estimate.road.distanceKm.rounded())) km")
                resultRow(label: "Tempo estimado", value: String(format: "%.1f h", estimate.road.estimatedTravelHours))
                resultRow(label: "Combustível", value: String(format: "%.1f L", estimate.road.fuelLiters))
                resultRow(label: "Custo combustível", value: "R$ \(Int(estimate.road.fuelCost.rounded()))", highlight: true)
                resultRow(label: "Pedágios", value: "R$ \(Int(estimate.road.tollCost.rounded()))")
                resultRow(label: "Extras", value: "R$ \(Int(estimate.road.extraCosts.rounded()))")
                Divider()
                resultRow(label: "Total rodoviário", value: "R$ \(Int(estimate.road.totalRoadCost.rounded()))", highlight: true, large: true)
            }
            .font(.caption)
        }

        if let flight = estimate.flight {
            Section("Custo Aéreo") {
                VStack(alignment: .leading, spacing: 6) {
                    resultRow(label: "Fonte da tarifa", value: flight.pricingSource.label)
                    resultRow(label: "Aeroporto origem", value: "\(flight.originAirport.code) - \(flight.originAirport.name)")
                    resultRow(label: "Aeroporto destino", value: "\(flight.destinationAirport.code) - \(flight.destinationAirport.name)")
                    Divider()
                    resultRow(label: "Passagem ida", value: "R$ \(Int(flight.oneWayFare.rounded()))")
                    resultRow(label: "Passagem ida/volta", value: "R$ \(Int(flight.roundTripFare.rounded()))")
                    resultRow(label: "Bagagem + transfers", value: "R$ \(Int(flight.baggageAndTransfers.rounded()))")
                    Divider()
                    resultRow(label: "Total aéreo", value: "R$ \(Int(flight.totalAirCost.rounded()))", highlight: true, large: true)
                }
                .font(.caption)
            }

            let destinationAirports = ArtistLogisticsEstimator.airportOptions(for: destinationState)
            if !destinationAirports.isEmpty {
                Section("Aeroportos no destino") {
                    ForEach(destinationAirports) { airport in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(airport.code) - \(airport.name)")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.primary)
                            Text(airport.city)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } else {
            Section("Custo Aéreo") {
                Text("Rota entre cidades do mesmo estado: voo não é recomendado.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        Section("Comparação") {
            let roadCost = estimate.road.totalRoadCost
            let flightCost = estimate.flight?.totalAirCost ?? .infinity
            let difference = abs(roadCost - flightCost)
            let percentageDiff = flightCost.isFinite ? (difference / min(roadCost, flightCost) * 100) : 0

            VStack(alignment: .leading, spacing: 6) {
                resultRow(label: "Rodoviário", value: "R$ \(Int(roadCost.rounded()))")

                if flightCost.isFinite {
                    resultRow(label: "Aéreo", value: "R$ \(Int(flightCost.rounded()))")
                    resultRow(label: "Diferença", value: "R$ \(Int(difference.rounded())) (\(Int(percentageDiff.rounded()))%)")
                }
            }
            .font(.caption)
            .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private func resultRow(label: String, value: String, highlight: Bool = false, large: Bool = false) -> some View {
        HStack {
            Text(label)
                .fontWeight(large ? .semibold : .regular)
            Spacer()
            Text(value)
                .font(large ? .headline : .caption)
                .fontWeight(.semibold)
                .foregroundStyle(highlight ? PsyTheme.primary : .primary)
        }
    }

    private func calculateLogistics() {
        guard !originCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !originState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !destinationCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !destinationState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            calculatorMessage = "Preencha origem e destino para calcular."
            return
        }

        let fuel = Double(fuelPrice) ?? 0
        let kmPerLiter = Double(vehicleKmPerLiter) ?? 0
        let toll = Double(tollCost) ?? 0
        let extras = Double(extraRoadCosts) ?? 0

        if useRealTimeData {
            Task {
                isLoading = true
                defer { isLoading = false }

                let resolvedEstimate = await ArtistLogisticsEstimator.estimateWithRealTimeData(
                    originCity: originCity,
                    originState: originState,
                    destinationCity: destinationCity,
                    destinationState: destinationState,
                    eventDate: eventDate,
                    returnDate: returnDate,
                    vehicleKmPerLiter: kmPerLiter,
                    fuelPricePerLiter: fuel,
                    tollCost: toll,
                    extraRoadCosts: extras
                )
                estimate = resolvedEstimate
                saveEstimateToHistory(resolvedEstimate)
                calculatorMessage = APIConfiguration.isConfigured
                    ? "Estimativa atualizada com consulta externa."
                    : "APIs não configuradas. Resultado calculado com fallback local."
            }
            return
        }

        let resolvedEstimate = ArtistLogisticsEstimator.estimate(
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState,
            eventDate: eventDate,
            returnDate: returnDate,
            vehicleKmPerLiter: kmPerLiter,
            fuelPricePerLiter: fuel,
            tollCost: toll,
            extraRoadCosts: extras
        )
        estimate = resolvedEstimate
        saveEstimateToHistory(resolvedEstimate)
        calculatorMessage = "Estimativa local atualizada."
    }

    private func applyFuelReference() {
        guard let reference = BrazilLogisticsReferenceService.fuelReference(for: originState) else {
            calculatorMessage = "Sem referência de combustível para esta UF."
            return
        }
        fuelPrice = String(format: "%.2f", reference.gasolinePrice)
        calculatorMessage = "Combustível sugerido por \(reference.sourceLabel)."
    }

    private func applyTollReference() {
        guard !originState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !destinationState.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            calculatorMessage = "Preencha as UFs de origem e destino para sugerir pedágio."
            return
        }

        let distance = ArtistLogisticsEstimator.estimatedRoadDistanceKm(
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState
        )
        let suggestion = BrazilLogisticsReferenceService.suggestedTollCost(
            originState: originState,
            destinationState: destinationState,
            distanceKm: distance
        )
        tollCost = String(format: "%.0f", suggestion)
        calculatorMessage = "Pedágio sugerido por \(BrazilLogisticsReferenceService.tollSourceLabel(originState: originState, destinationState: destinationState))."
    }

    private func saveEstimateToHistory(_ estimate: LogisticsEstimate) {
        LogisticsEstimateHistoryStore.append(
            estimate: estimate,
            originCity: originCity,
            originState: originState,
            destinationCity: destinationCity,
            destinationState: destinationState,
            eventDate: eventDate
        )
        estimateHistory = LogisticsEstimateHistoryStore.load()
    }

    private func calcWebRoute() {
        let from = "\(originCity), \(originState), Brasil"
        let to = "\(destinationCity), \(destinationState), Brasil"
        isLoadingWebRoute = true
        webRouteMessage = ""
        Task {
            let result = await WebAIService.shared.estimateRoute(fromAddress: from, toAddress: to)
            await MainActor.run {
                isLoadingWebRoute = false
                if let r = result, let dist = r.oneWayDistanceKm {
                    let hrs = r.oneWayHours ?? 0
                    let tollFallback = Double(tollCost) ?? 0
                    let fuelFallback = Double(fuelPrice) ?? 0
                    let kmL = Double(vehicleKmPerLiter) ?? 10
                    let fuelTotal = (dist * 2 / kmL) * fuelFallback
                    let total = fuelTotal + tollFallback
                    webRouteMessage = String(format: "Rota: %.0f km (%.1f h) • Combustível: R$ %.0f • Total estimado: R$ %.0f", dist, hrs, fuelTotal, total)
                    tollCost = String(Int((dist * 2 * 14 / 100).rounded()))
                } else {
                    webRouteMessage = "Não foi possível calcular a rota via web. Tente o cálculo local."
                }
            }
        }
    }
}
