import SwiftData
import Foundation

// MARK: - Financial Alert Service
/// Monitors artist financial health and generates contextual alerts
/// Integrates with Dashboard for visibility

struct FinancialAlertService {
    enum AlertSeverity: String, CaseIterable {
        case critical = "🔴 Crítico"
        case warning = "🟡 Aviso"
        case info = "🔵 Info"
        
        var color: String {
            switch self {
            case .critical: return "#FF6B6B"
            case .warning: return "#FFD93D"
            case .info: return "#6BCB77"
            }
        }
    }
    
    struct FinancialAlert: Identifiable, Hashable {
        let id = UUID()
        let title: String
        let message: String
        let severity: AlertSeverity
        let action: String?
        let actionTarget: String?
        let createdAt: Date
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    // MARK: - Alert Generation
    
    /// Analyze financial data and generate relevant alerts
    static func generateAlerts(
        expenses: [Expense],
        gigs: [Gig],
        leads: [EventLead],
        negotiations: [Negotiation]
    ) -> [FinancialAlert] {
        var alerts: [FinancialAlert] = []
        
        let totalExpenses = expenses.reduce(0) { $0 + $1.amount }
        let gigRevenue = gigs.reduce(0) { $0 + $1.fee }
        let netBalance = gigRevenue - totalExpenses
        
        // 🔴 CRITICAL ALERTS
        
        // No gigs booked
        if gigs.isEmpty {
            alerts.append(FinancialAlert(
                title: "Sem eventos agendados",
                message: "Você não tem nenhum evento confirmado. Comece buscando oportunidades no Radar.",
                severity: .critical,
                action: "Explorar Radar",
                actionTarget: "events",
                createdAt: .now
            ))
        }
        
        // Negative balance (spending more than earning)
        if netBalance < 0 {
            alerts.append(FinancialAlert(
                title: "Despesas superam receitas",
                message: "Seu saldo está negativo em R$ \(Int(abs(netBalance))). Aumente as performances ou reduza custos.",
                severity: .critical,
                action: nil,
                actionTarget: nil,
                createdAt: .now
            ))
        }
        
        // Very low balance (< 10% of revenue or < R$500)
        if gigRevenue > 0 {
            let healthPct = (netBalance / gigRevenue) * 100
            if healthPct < 10 && healthPct >= 0 {
                alerts.append(FinancialAlert(
                    title: "Margem financeira baixa",
                    message: "Você está com apenas \(Int(healthPct))% de margem. Planeje para meses com menos eventos.",
                    severity: .critical,
                    action: nil,
                    actionTarget: nil,
                    createdAt: .now
                ))
            }
        }
        
        // 🟡 WARNING ALERTS
        
        // High transport costs
        let transportExpenses = expenses.filter { $0.category == "Transporte" }.reduce(0) { $0 + $1.amount }
        if transportExpenses > gigRevenue * 0.25 {
            alerts.append(FinancialAlert(
                title: "Custos de transporte altos",
                message: "Você está gastando \(Int((transportExpenses/gigRevenue)*100))% da receita com transporte. Considere consolidar eventos regionais.",
                severity: .warning,
                action: "Ver Radar Filtrado",
                actionTarget: "events",
                createdAt: .now
            ))
        }
        
        // Equipment purchases trending
        let equipmentExpenses = expenses.filter { $0.category == "Equipamento" }.reduce(0) { $0 + $1.amount }
        if equipmentExpenses > 5000 {
            alerts.append(FinancialAlert(
                title: "Investimentos em equipamento elevados",
                message: "Você já investiu R$ \(Int(equipmentExpenses)) em equipamento este ano. Priorize o retorno em eventos.",
                severity: .warning,
                action: nil,
                actionTarget: nil,
                createdAt: .now
            ))
        }
        
        // Many leads but low conversion
        let activeLeads = leads.filter { $0.status != LeadStatus.notContacted.rawValue }.count
        let closedLeads = negotiations.filter { $0.stage == LeadStatus.closed.rawValue }.count
        if activeLeads > 5 && closedLeads == 0 {
            alerts.append(FinancialAlert(
                title: "Conversão baixa em negociações",
                message: "Você tem \(activeLeads) leads ativos mas nenhum fechado. Acione o Manager IA para dicas.",
                severity: .warning,
                action: "Ir para Manager",
                actionTarget: "manager",
                createdAt: .now
            ))
        }
        
        // Seasonal cash flow warning
        let thisMonthExpenses = expenses.filter { $0.dateISO.prefix(7) == ISO8601DateFormatter().string(from: .now).prefix(7) }.reduce(0) { $0 + $1.amount }
        if thisMonthExpenses > gigRevenue * 0.6 && gigRevenue > 0 {
            alerts.append(FinancialAlert(
                title: "Fluxo de caixa tenso este mês",
                message: "Você já gastou 60%+ da receita prevista. Economize e maximize próximos eventos.",
                severity: .warning,
                action: nil,
                actionTarget: nil,
                createdAt: .now
            ))
        }
        
        // 🔵 INFO ALERTS
        
        // Opportunity: Book more gigs in high-revenue months
        let gigsCountPerMonth = Dictionary(grouping: gigs) { Int($0.date.timeIntervalSince1970) / (30*24*3600) }
        let maxGigs = gigsCountPerMonth.values.map { $0.count }.max() ?? 0
        if maxGigs >= 3 {
            alerts.append(FinancialAlert(
                title: "Seu pico está em alta!",
                message: "Você marcou \(maxGigs) eventos no mês com melhor performance. Busque mais oportunidades nesse período.",
                severity: .info,
                action: "Ver Próximos Meses",
                actionTarget: "events",
                createdAt: .now
            ))
        }
        
        // Positive trend
        if netBalance > 0 && netBalance / (gigRevenue > 0 ? gigRevenue : 1) > 0.5 {
            alerts.append(FinancialAlert(
                title: "Saúde financeira excelente!",
                message: "Sua margem está acima de 50%. Continue esse ritmo.",
                severity: .info,
                action: nil,
                actionTarget: nil,
                createdAt: .now
            ))
        }
        
        return alerts.sorted { $0.severity.rawValue < $1.severity.rawValue }
    }
    
    // MARK: - Dashboard Summary
    
    struct FinancialSummary {
        let totalRevenue: Double
        let totalExpenses: Double
        let netBalance: Double
        let healthPercentage: Int
        let healthStatus: String // "Saudável", "Atenção", "Crítico"
        let activeAlerts: Int
        let criticalAlertsCount: Int
    }
    
    static func generateSummary(
        expenses: [Expense],
        gigs: [Gig],
        leads: [EventLead],
        negotiations: [Negotiation]
    ) -> FinancialSummary {
        let totalExpenses = expenses.reduce(0) { $0 + $1.amount }
        let totalRevenue = gigs.reduce(0) { $0 + $1.fee }
        let netBalance = totalRevenue - totalExpenses
        
        let healthPct = totalRevenue > 0 ? Int((netBalance / totalRevenue) * 100) : 0
        let healthStatus = healthPct >= 60 ? "Saudável" : healthPct >= 30 ? "Atenção" : "Crítico"
        
        let alerts = generateAlerts(expenses: expenses, gigs: gigs, leads: leads, negotiations: negotiations)
        let criticalCount = alerts.filter { $0.severity == .critical }.count
        
        return FinancialSummary(
            totalRevenue: totalRevenue,
            totalExpenses: totalExpenses,
            netBalance: netBalance,
            healthPercentage: max(0, min(100, healthPct)),
            healthStatus: healthStatus,
            activeAlerts: alerts.count,
            criticalAlertsCount: criticalCount
        )
    }
    
    // MARK: - Forecasting
    
    struct FinancialForecast {
        let projectedRevenueNext30Days: Double
        let projectedExpensesNext30Days: Double
        let projectedBalanceNext30Days: Double
        let recommendation: String
    }
    
    /// Forecast cash flow for next 30 days based on pipeline
    static func forecast30Days(
        gigs: [Gig],
        expenses: [Expense],
        leads: [EventLead]
    ) -> FinancialForecast {
        let now = Date()
        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        
        // Revenue from confirmed gigs in next 30 days
        let confirmedGigs = gigs.filter { $0.date > now && $0.date < thirtyDaysLater }
        let projectedRevenue = confirmedGigs.reduce(0) { $0 + $1.fee }
        
        // Project expenses based on average monthly
        let avgMonthlyExpense = expenses.reduce(0) { $0 + $1.amount } / 3 // Last 3 months average
        
        let projectedBalance = projectedRevenue - avgMonthlyExpense
        
        var recommendation = ""
        if projectedBalance < 0 {
            recommendation = "⚠️ Próximos 30 dias podem ser negativos. Busque eventos urgentemente no Radar."
        } else if projectedBalance < avgMonthlyExpense * 0.5 {
            recommendation = "📊 Margem baixa prevista. Considere consolidar viagens e reduzir custos opcionais."
        } else if projectedBalance > avgMonthlyExpense {
            recommendation = "✅ Perspectiva positiva! Você pode investir em novos equipamentos ou marketing."
        } else {
            recommendation = "📈 Fluxo equilibrado. Mantenha o ritmo atual."
        }
        
        return FinancialForecast(
            projectedRevenueNext30Days: projectedRevenue,
            projectedExpensesNext30Days: avgMonthlyExpense,
            projectedBalanceNext30Days: projectedBalance,
            recommendation: recommendation
        )
    }
}
