import SwiftUI

struct BreakEvenCalculatorSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let gig: Gig
    @Binding var isPresented: Bool
    
    @State private var grossFee: String = ""
    @State private var agencyPercent: String = "15"
    @State private var taxPercent: String = "8"
    @State private var flight: String = ""
    @State private var hotel: String = ""
    @State private var transport: String = ""
    @State private var food: String = ""
    @State private var other: String = ""
    @State private var showSaveSuccess = false
    
    var calculatedBreakEven: (net: Double, margin: Int, status: String) {
        let gross = Double(grossFee.replacingOccurrences(of: ",", with: ".")) ?? 0
        let agency = Double(agencyPercent.replacingOccurrences(of: ",", with: ".")) ?? 0
        let tax = Double(taxPercent.replacingOccurrences(of: ",", with: ".")) ?? 0
        let flightCost = Double(flight.replacingOccurrences(of: ",", with: ".")) ?? 0
        let hotelCost = Double(hotel.replacingOccurrences(of: ",", with: ".")) ?? 0
        let transportCost = Double(transport.replacingOccurrences(of: ",", with: ".")) ?? 0
        let foodCost = Double(food.replacingOccurrences(of: ",", with: ".")) ?? 0
        let otherCost = Double(other.replacingOccurrences(of: ",", with: ".")) ?? 0
        
        let agencyValue = gross * (agency / 100)
        let taxValue = gross * (tax / 100)
        let operationalCosts = flightCost + hotelCost + transportCost + foodCost + otherCost
        let net = gross - agencyValue - taxValue - operationalCosts
        let margin = gross > 0 ? Int((net / gross) * 100) : 0
        let status = gross <= 0 ? "" : net > 0 ? "Lucro" : net == 0 ? "Break-even" : "Prejuízo"
        
        return (net, margin, status)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "chart.bar.xaxis")
                                    .foregroundStyle(PsyTheme.primary)
                                Text("Break-even")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }
                            Text("\(gig.title) — \(gig.city)")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                            if let logistics = gig.totalLogisticsCost, logistics > 0 {
                                Text("Logística vinculada: R$ \(Int(logistics))")
                                    .font(.caption2)
                                    .foregroundStyle(PsyTheme.primary)
                            }
                        }
                    }
                    
                    // Inputs
                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Receita")
                                .font(.headline)
                                .foregroundStyle(PsyTheme.primary)
                            
                            HStack {
                                Text("Cachê bruto (R$)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $grossFee)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            Divider()
                            
                            Text("Descontos")
                                .font(.headline)
                                .foregroundStyle(PsyTheme.primary)
                            
                            HStack {
                                Text("Agência (%)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $agencyPercent)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            HStack {
                                Text("Impostos (%)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $taxPercent)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            Divider()
                            
                            Text("Custos operacionais")
                                .font(.headline)
                                .foregroundStyle(PsyTheme.primary)
                            
                            HStack {
                                Text("Passagem aérea (R$)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $flight)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            HStack {
                                Text("Hospedagem (R$)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $hotel)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            HStack {
                                Text("Transporte local (R$)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $transport)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            HStack {
                                Text("Alimentação (R$)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $food)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            HStack {
                                Text("Outros (R$)")
                                    .font(.caption)
                                Spacer()
                                TextField("", text: $other)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                        }
                    }
                    
                    // Result
                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resultado")
                                .font(.headline)
                                .foregroundStyle(PsyTheme.primary)
                            
                            HStack {
                                Text("Lucro líquido")
                                    .font(.caption)
                                Spacer()
                                Text("R$ \(Int(calculatedBreakEven.net))")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(calculatedBreakEven.net > 0 ? .green : (calculatedBreakEven.net == 0 ? .orange : .red))
                            }
                            
                            HStack {
                                Text("Margem")
                                    .font(.caption)
                                Spacer()
                                Text("\(calculatedBreakEven.margin)%")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(calculatedBreakEven.margin > 0 ? .green : (calculatedBreakEven.margin == 0 ? .orange : .red))
                            }
                            
                            if !calculatedBreakEven.status.isEmpty {
                                HStack {
                                    Text("Status")
                                        .font(.caption)
                                    Spacer()
                                    Text(calculatedBreakEven.status)
                                        .font(.subheadline.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(calculatedBreakEven.status == "Lucro" ? Color.green.opacity(0.2) : (calculatedBreakEven.status == "Break-even" ? Color.orange.opacity(0.2) : Color.red.opacity(0.2)))
                                        .foregroundStyle(calculatedBreakEven.status == "Lucro" ? .green : (calculatedBreakEven.status == "Break-even" ? .orange : .red))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Break-even")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Salvar") {
                        let gross = Double(grossFee.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let agency = Double(agencyPercent.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let tax = Double(taxPercent.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let flightCost = Double(flight.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let hotelCost = Double(hotel.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let transportCost = Double(transport.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let foodCost = Double(food.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let otherCost = Double(other.replacingOccurrences(of: ",", with: ".")) ?? 0

                        let snapshot = BreakEvenCalculation(
                            gigTitle: gig.title,
                            gigCity: gig.city,
                            gigId: String(describing: gig.persistentModelID),
                            grossFee: gross,
                            agencyPercent: agency,
                            taxPercent: tax,
                            flight: flightCost,
                            hotel: hotelCost,
                            transport: transportCost,
                            food: foodCost,
                            other: otherCost
                        )
                        modelContext.insert(snapshot)

                        gig.breakEvenNet = calculatedBreakEven.net
                        gig.breakEvenMarginPct = calculatedBreakEven.margin
                        gig.breakEvenStatus = calculatedBreakEven.status
                        gig.breakEvenUpdatedAt = Date()
                        gig.fee = gross
                        if transportCost > 0 {
                            gig.totalLogisticsCost = transportCost
                        }

                        do {
                            try modelContext.save()
                            showSaveSuccess = true
                        } catch {
                            // Keep sheet open if save fails.
                        }
                    }
                    .disabled((Double(grossFee.replacingOccurrences(of: ",", with: ".")) ?? 0) <= 0)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { isPresented = false }
                }
            }
        }
        .alert("dados atualizado com sucesso.", isPresented: $showSaveSuccess) {
            Button("OK") {
                isPresented = false
            }
        }
        .onAppear {
            grossFee = String(gig.fee)
            if let logistics = gig.totalLogisticsCost, logistics > 0 {
                transport = String(Int(logistics))
            }
        }
    }
}
