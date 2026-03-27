import SwiftUI
import SwiftData

struct GigEditFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let gig: Gig
    @Binding var isPresented: Bool
    
    @State private var title: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var contactName: String = ""
    @State private var checklistSummary: String = ""
    @State private var fee: String = ""
    @State private var status: String = "Confirmado"
    @State private var date: Date = Date()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Editar gig")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                            Text("Atualize informações operacionais e status.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    
                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Nome da gig", text: $title)
                                .textFieldStyle(.roundedBorder)
                            
                            HStack(spacing: 10) {
                                TextField("Cidade", text: $city)
                                    .textFieldStyle(.roundedBorder)
                                TextField("UF", text: $state)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 70)
                            }
                            
                            TextField("Contratante", text: $contactName)
                                .textFieldStyle(.roundedBorder)
                            
                            HStack(spacing: 10) {
                                TextField("Fee (R$)", text: $fee)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 100)
                                
                                Picker("Status", selection: $status) {
                                    Text("Confirmado").tag("Confirmado")
                                    Text("Em negociação").tag("Negociacao")
                                    Text("Lead").tag("Lead")
                                    Text("Completo").tag("Completo")
                                    Text("Cancelado").tag("Cancelado")
                                }
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Seção de Data compacta
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Data e hora")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.compact)
                                    .tint(PsyTheme.primary)
                                    .labelsHidden()
                            }
                            
                            TextField("Checklist", text: $checklistSummary, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                                .frame(minHeight: 60)
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Editar gig")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        gig.title = title
                        gig.city = city
                        gig.state = state
                        gig.date = date
                        gig.fee = Double(fee) ?? gig.fee
                        gig.contactName = contactName
                        gig.checklistSummary = checklistSummary
                        gig.status = status
                        
                        try? modelContext.save()
                        isPresented = false
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            title = gig.title
            city = gig.city
            state = gig.state
            contactName = gig.contactName
            checklistSummary = gig.checklistSummary
            fee = String(gig.fee)
            status = gig.status
            date = gig.date
        }
    }
}
