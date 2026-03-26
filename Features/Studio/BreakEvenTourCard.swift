import SwiftUI

struct BreakEvenTourCard: View {
    var isExpanded: Binding<Bool>
    let tourData: TourBreakEvenData
    var onOpenDetails: (() -> Void)? = nil
    
    struct TourBreakEvenData {
        let name: String
        let targetRevenue: Double
        let currentCosts: Double
        let projection: String
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Receita Alvo", systemImage: "target")
                    Spacer()
                    Text(formatCurrency(tourData.targetRevenue))
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Label("Custos Atuais", systemImage: "dollarsign.circle")
                    Spacer()
                    Text(formatCurrency(tourData.currentCosts))
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                HStack {
                    Label("Projeção", systemImage: "chart.line.uptrend.xyaxis")
                    Spacer()
                    Text(tourData.projection)
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                }

                if let onOpenDetails {
                    Button("Abrir detalhamento financeiro") {
                        onOpenDetails()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 8)
        } label: {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(PsyTheme.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Break-even: \(tourData.name)")
                        .fontWeight(.semibold)
                    Text("Expandir para ver detalhes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .tint(PsyTheme.primary)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "BRL"
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "R$ 0"
    }
}

#Preview {
    @State var isExpanded = false
    return BreakEvenTourCard(
        isExpanded: $isExpanded,
        tourData: .init(
            name: "Brasil 2026",
            targetRevenue: 50000,
            currentCosts: 30000,
            projection: "Break-even em 3 shows"
        )
    )
    .padding()
}
