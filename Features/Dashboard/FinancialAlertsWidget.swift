import SwiftUI
import SwiftData

// MARK: - Financial Alerts Widget
/// Dashboard component displaying critical financial alerts and forecasts

struct FinancialAlertsWidget: View {
    @Query(sort: \Expense.dateISO, order: .reverse) private var expenses: [Expense]
    @Query(sort: \Gig.date) private var gigs: [Gig]
    @Query(sort: \EventLead.eventDate) private var leads: [EventLead]
    @Query(sort: \Negotiation.createdAt) private var negotiations: [Negotiation]
    
    @State private var alerts: [FinancialAlertService.FinancialAlert] = []
    @State private var summary: FinancialAlertService.FinancialSummary?
    @State private var forecast: FinancialAlertService.FinancialForecast?
    @State private var showAllAlerts = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Health Status Card
            if let summary = summary {
                HealthStatusCard(summary: summary)
                    .onTapGesture {
                        showAllAlerts = true
                    }
            }
            
            // Top 3 Alerts
            if !alerts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("⚠️ Alertas Financeiros")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if alerts.count > 3 {
                            Text("\(alerts.count)")
                                .font(.caption)
                                .padding(4)
                                .background(PsyTheme.primary.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    ForEach(alerts.prefix(3)) { alert in
                        AlertRow(alert: alert)
                    }
                    
                    if alerts.count > 3 {
                        Button {
                            showAllAlerts = true
                        } label: {
                            HStack {
                                Text("Ver todos os \(alerts.count) alertas")
                                    .font(.caption)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundStyle(PsyTheme.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(8)
                        }
                    }
                }
                .background(PsyTheme.surfaceAlt)
                .cornerRadius(10)
            }
            
            // 30-Day Forecast
            if let forecast = forecast {
                ForecastCard(forecast: forecast)
            }
        }
        .task {
            await updateAlerts()
        }
        .sheet(isPresented: $showAllAlerts) {
            AllAlertsView(alerts: alerts, summary: summary ?? FinancialAlertService.FinancialSummary(
                totalRevenue: 0,
                totalExpenses: 0,
                netBalance: 0,
                healthPercentage: 0,
                healthStatus: "N/A",
                activeAlerts: 0,
                criticalAlertsCount: 0
            ))
        }
    }
    
    private func updateAlerts() async {
        alerts = FinancialAlertService.generateAlerts(
            expenses: expenses,
            gigs: gigs,
            leads: leads,
            negotiations: negotiations
        )
        
        summary = FinancialAlertService.generateSummary(
            expenses: expenses,
            gigs: gigs,
            leads: leads,
            negotiations: negotiations
        )
        
        forecast = FinancialAlertService.forecast30Days(
            gigs: gigs,
            expenses: expenses,
            leads: leads
        )
    }
}

// MARK: - Sub-components

struct HealthStatusCard: View {
    let summary: FinancialAlertService.FinancialSummary
    
    var statusColor: Color {
        switch summary.healthStatus {
        case "Saudável": return .green
        case "Atenção": return .orange
        default: return .red
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💰 Saúde Financeira")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Status")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                            Text(summary.healthStatus)
                                .font(.headline)
                                .foregroundStyle(statusColor)
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Margem")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                            Text("\(summary.healthPercentage)%")
                                .font(.headline)
                                .foregroundStyle(PsyTheme.primary)
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("R$ \(Int(summary.totalRevenue))")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                            .foregroundStyle(.red)
                        Text("R$ \(Int(summary.totalExpenses))")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    if summary.criticalAlertsCount > 0 {
                        Text("\(summary.criticalAlertsCount) críticos")
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .fontWeight(.semibold)
                    }
                }
            }
            
            // Health bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(width: geo.size.width * CGFloat(summary.healthPercentage) / 100)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(PsyTheme.surfaceAlt)
        .cornerRadius(10)
    }
}

struct AlertRow: View {
    let alert: FinancialAlertService.FinancialAlert
    
    var severityColor: Color {
        switch alert.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(severityColor)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(severityColor)
                
                Text(alert.message)
                    .font(.caption2)
                    .foregroundStyle(PsyTheme.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if alert.action != nil {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(PsyTheme.textSecondary)
            }
        }
        .padding(10)
        .background(PsyTheme.surface)
        .cornerRadius(6)
        .padding(.horizontal, 12)
    }
}

struct ForecastCard: View {
    let forecast: FinancialAlertService.FinancialForecast
    
    var trendIcon: String {
        if forecast.projectedBalanceNext30Days > 0 {
            return "📈"
        } else if forecast.projectedBalanceNext30Days < -1000 {
            return "📉"
        } else {
            return "➡️"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(trendIcon) Próximos 30 dias")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Receita prevista")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                    Text("R$ \(Int(forecast.projectedRevenueNext30Days))")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Despesas estimadas")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                    Text("R$ \(Int(forecast.projectedExpensesNext30Days))")
                        .font(.headline)
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saldo projetado")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                    Text("R$ \(Int(forecast.projectedBalanceNext30Days))")
                        .font(.headline)
                        .foregroundStyle(forecast.projectedBalanceNext30Days >= 0 ? .green : .red)
                }
            }
            
            Text(forecast.recommendation)
                .font(.caption)
                .foregroundStyle(PsyTheme.textSecondary)
                .padding(.top, 4)
        }
        .padding(12)
        .background(PsyTheme.surfaceAlt)
        .cornerRadius(10)
    }
}

struct AllAlertsView: View {
    let alerts: [FinancialAlertService.FinancialAlert]
    let summary: FinancialAlertService.FinancialSummary
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HealthStatusCard(summary: summary)
                    .padding(16)
                
                if alerts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Sem alertas críticos!")
                            .font(.headline)
                        Text("Sua situação financeira está sob controle")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(alerts) { alert in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(alert.title)
                                        .font(.headline)
                                    Text(alert.message)
                                        .font(.caption)
                                        .foregroundStyle(PsyTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                if alert.action != nil {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(PsyTheme.textSecondary)
                                }
                            }
                        }
                        .listRowBackground(PsyTheme.surfaceAlt)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Todos os Alertas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    FinancialAlertsWidget()
}
