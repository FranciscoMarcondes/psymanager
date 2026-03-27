import SwiftUI
import SwiftData

struct GigNegotiationFlowView: View {
    @Environment(\.modelContext) var modelContext
    @Binding var gig: Gig
    
    var userHomeState: String = "SP"
    var userBaseCity: String = "São Paulo"
    var onComplete: (() -> Void)?
    var onGoToLogistics: (() -> Void)?
    
    @State private var step: NegotiationStep = .agencyQuestion
    @State private var selectedAgencyAnswer: AgencyAnswer? = nil
    @State private var cacheProposal: String = ""
    @State private var cacheApprovedByEvent: String = ""
    @State private var negotiationNotes: String = ""
    @State private var showValidationError = false
    @State private var validationMessage = ""
    
    enum NegotiationStep {
        case agencyQuestion
        case cacheNegotiation
        case logisticsReady
        case complete
    }
    
    enum AgencyAnswer {
        case yes
        case no
    }
    
    var isSameState: Bool {
        gig.state.uppercased() == userHomeState.uppercased()
    }
    
    var isValidToAdvance: Bool {
        !cacheApprovedByEvent.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var totalValue: Double {
        let cache = Double(cacheApprovedByEvent) ?? 0
        let logistics = gig.totalLogisticsCost ?? 0
        return cache + logistics
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 1.5) {
                    // ────── Gig Summary ──────
                    VStack(alignment: .leading, spacing: 1) {
                        HStack {
                            VStack(alignment: .leading, spacing: 0.25) {
                                Text("Evento")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(gig.title.isEmpty ? gig.city : gig.title)
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 0.25) {
                                Text("Local")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(gig.city), \(gig.state)")
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 0.25) {
                                Text("Data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(gig.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 0.25) {
                                Text("Contato")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(gig.contactName.isEmpty ? "---" : gig.contactName)
                                    .font(.body)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if isSameState {
                        HStack(spacing: 0.5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Mesmo estado (\(gig.state)) - Sem custo aéreo")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        .padding(0.75)
                        .background(Color(.systemGreen).opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // ────── Step 1: Agency Question ──────
                    VStack(alignment: .leading, spacing: 0.75) {
                        HStack(spacing: 0.5) {
                            Text("⚠️")
                            Text("Pergunta do Evento")
                                .font(.headline)
                        }
                        
                        Text("O evento perguntou se você tem agência representando você?")
                            .font(.body)
                            .lineLimit(nil)
                        
                        if selectedAgencyAnswer == nil {
                            HStack(spacing: 0.5) {
                                Button(action: { selectedAgencyAnswer = .yes }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                        Text("Sim, Tenho")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(0.75)
                                    .background(Color(.systemBlue))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                                
                                Button(action: { selectedAgencyAnswer = .no }) {
                                    HStack {
                                        Image(systemName: "xmark.circle")
                                        Text("Sou Autônomo")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(0.75)
                                    .background(Color(.systemGray4))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                                }
                            }
                        } else if selectedAgencyAnswer == .yes {
                            HStack(spacing: 0.5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Agência cuida dos detalhes")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        } else {
                            HStack(spacing: 0.5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("DJ cuida de TODOS os detalhes")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemOrange).opacity(0.1))
                    .cornerRadius(10)
                    .border(Color(.systemOrange), width: 2)
                    
                    // ────── Step 2: Cache Negotiation ──────
                    VStack(alignment: .leading, spacing: 0.75) {
                        Text("💰 Cache Proposto (SUA sugestão)")
                            .font(.headline)
                        
                        HStack {
                            Text("R$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $cacheProposal)
                                .keyboardType(.decimalPad)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 0.5) {
                            Text("✅ Cache APROVADO pelo Evento")
                                .font(.headline)
                            Text("Quanto o evento aprovou para você?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 0.75)
                        
                        HStack {
                            Text("R$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $cacheApprovedByEvent)
                                .keyboardType(.decimalPad)
                        }
                        .padding()
                        .background(cacheApprovedByEvent.isEmpty ? Color(.systemGray6) : Color(.systemGreen).opacity(0.1))
                        .cornerRadius(8)
                        .border(cacheApprovedByEvent.isEmpty ? Color.clear : Color(.systemGreen), width: 1)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // ────── Step 3: Logistics Requirement ──────
                    if !isSameState {
                        VStack(alignment: .leading, spacing: 0.75) {
                            HStack(spacing: 0.5) {
                                Text("✈️")
                                Text("Próximo: Calcular Logística")
                                    .font(.headline)
                            }
                            
                            Text("Você está viajando para \(gig.city), \(gig.state) (fora do seu estado).")
                                .font(.body)
                            
                            VStack(alignment: .leading, spacing: 0.35) {
                                Text("Precisamos calcular:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 0.25) {
                                    HStack(spacing: 0.75) {
                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                        Text("Deslocamento até aeroporto")
                                            .font(.caption2)
                                    }
                                    HStack(spacing: 0.75) {
                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                        Text("Voo de ida e volta")
                                            .font(.caption2)
                                    }
                                    HStack(spacing: 0.75) {
                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                        Text("Deslocamento do aeroporto até evento")
                                            .font(.caption2)
                                    }
                                }
                            }
                            .padding(0.75)
                            .background(Color(.systemBlue).opacity(0.05))
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(.systemBlue).opacity(0.05))
                        .cornerRadius(10)
                    }
                    
                    // ────── Step 4: Notes ──────
                    VStack(alignment: .leading, spacing: 0.5) {
                        Text("📌 Notas da Negociação")
                            .font(.headline)
                        
                        TextEditor(text: $negotiationNotes)
                            .frame(minHeight: 80)
                            .padding(0.5)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // ────── Validation Error ──────
                    if showValidationError {
                        HStack(spacing: 0.75) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color(.systemRed).opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // ────── Value Summary ──────
                    if !cacheApprovedByEvent.isEmpty {
                        VStack(alignment: .leading, spacing: 0.75) {
                            Text("💚 Valor Total do Gig")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 0.25) {
                                    Text("Cache:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("R$ \(Double(cacheApprovedByEvent) ?? 0, format: .number)")
                                        .font(.headline)
                                }
                                
                                if !isSameState && (gig.totalLogisticsCost ?? 0) > 0 {
                                    VStack(alignment: .leading, spacing: 0.25) {
                                        Text("Logística:")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("R$ \(gig.totalLogisticsCost ?? 0, format: .number)")
                                            .font(.headline)
                                    }
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 0.25) {
                                    Text("TOTAL:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("R$ \(totalValue, format: .number)")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGreen).opacity(0.05))
                        .cornerRadius(10)
                        .border(Color(.systemGreen), width: 1)
                    }
                    
                    // ────── Action Buttons ──────
                    HStack(spacing: 0.75) {
                        Button(action: handleContinue) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.headline)
                                Text(isSameState ? "Avançar para Confirmação →" : "Calcular Logística →")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isValidToAdvance ? Color(.systemBlue) : Color(.systemGray3))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(!isValidToAdvance)
                        
                        Button(action: { /* Go back */ }) {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("📝 Negociando Gig")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    func handleContinue() {
        guard isValidToAdvance else {
            showValidationError = true
            validationMessage = "Informe o cache aprovado pelo evento"
            return
        }
        
        // Update gig with negotiation data
        gig.status = "Negociacao"
        gig.cacheApprovedByEvent = Double(cacheApprovedByEvent) ?? 0
        gig.cacheApprovedAt = Date()
        gig.negotiationNotes = negotiationNotes
        gig.eventAskedAboutAgency = selectedAgencyAnswer != nil
        
        if isSameState {
            gig.logisticsRequired = false
            gig.totalLogisticsCost = 50  // Minimal local cost
            onComplete?()
        } else {
            gig.logisticsRequired = true
            onGoToLogistics?()
        }
    }
}

#Preview {
    @State var previewGig = Gig(
        title: "DJ Set - Festival",
        city: "Rio de Janeiro",
        state: "RJ",
        date: Date().addingTimeInterval(86400 * 14),
        fee: 2000,
        contactName: "João Silva",
        checklistSummary: ""
    )
    
    return GigNegotiationFlowView(
        gig: $previewGig,
        userHomeState: "SP",
        userBaseCity: "São Paulo"
    )
    .modelContainer(PreviewSampleData.container)
}
