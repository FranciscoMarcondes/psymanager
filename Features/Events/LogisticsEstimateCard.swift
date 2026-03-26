import SwiftUI

/// LogisticsEstimateCard — Show route and cost estimates for a gig
struct LogisticsEstimateCard: View {
    let gig: Gig
    let artistLocation: String // e.g., "São Paulo, SP"
    
    @State private var estimate: LogisticsAPIManager.LogisticsCompleteEstimate?
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Logística do Deslocamento", systemImage: "car.fill")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if let error = error {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            } else if let est = estimate {
                VStack(alignment: .leading, spacing: 12) {
                    // Distance & Time
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Distância")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f km", est.distance.distanceKm))
                                .font(.headline)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tempo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f h", est.totalHours))
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Modo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(est.recommendedMode == "flight" ? "✈️ Aéreo" : "🚗 Rodoviário")
                                .font(.headline)
                        }
                    }
                    
                    Divider()
                    
                    // Cost breakdown
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Combustível")
                                .font(.caption)
                            Spacer()
                            Text("R$ \(String(format: "%.2f", est.fuelCost))")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Pedágios")
                                .font(.caption)
                            Spacer()
                            Text("R$ \(String(format: "%.2f", est.tolls.estimate))")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Total Estimado")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("R$ \(String(format: "%.2f", est.totalCost))")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    // Info
                    Text(est.tolls.rationale)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            } else {
                Button(action: loadEstimate) {
                    Label("Calcular Logística", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onAppear {
            if estimate == nil && !isLoading {
                loadEstimate()
            }
        }
    }
    
    private func loadEstimate() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let gigAddress = "\(gig.city), \(gig.state)"
                let est = try await LogisticsAPIManager.shared.completeEstimate(
                    fromCity: artistLocation.split(separator: ",").first.map(String.init) ?? "São Paulo",
                    fromState: artistLocation.split(separator: ",").last.map(String.init) ?? "SP",
                    toCity: gig.city,
                    toState: gig.state
                )
                
                DispatchQueue.main.async {
                    self.estimate = est
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = "Não foi possível calcular. Tente novamente."
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    LogisticsEstimateCard(
        gig: Gig(
            id: UUID(),
            title: "Show Beneficente",
            city: "Belo Horizonte",
            state: "MG",
            date: .now.addingTimeInterval(86400 * 7),
            venue: "Casa de Shows ABC",
            notes: "",
            fee: 1500
        ),
        artistLocation: "São Paulo, SP"
    )
}
