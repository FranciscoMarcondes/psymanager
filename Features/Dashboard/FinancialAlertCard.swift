import SwiftUI

struct FinancialAlertCard: View {
    let title: String
    let description: String
    let value: String
    let severity: AlertSeverity
    let action: (() -> Void)?
    
    enum AlertSeverity {
        case warning, critical, info
        
        var backgroundColor: Color {
            switch self {
            case .warning: return Color(red: 1.0, green: 0.6, blue: 0.0).opacity(0.1)
            case .critical: return Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.1)
            case .info: return Color(red: 0.0, green: 0.7, blue: 1.0).opacity(0.1)
            }
        }
        
        var accentColor: Color {
            switch self {
            case .warning: return Color(red: 1.0, green: 0.6, blue: 0.0)
            case .critical: return Color(red: 1.0, green: 0.3, blue: 0.3)
            case .info: return Color(red: 0.0, green: 0.7, blue: 1.0)
            }
        }
        
        var icon: String {
            switch self {
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: severity.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(severity.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(severity.accentColor)
                    
                    if action != nil {
                        Button(action: action ?? {}) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(severity.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .background(severity.backgroundColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(severity.accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        FinancialAlertCard(
            title: "Despesa Alta Esta Semana",
            description: "Você gastou 85% do seu orçamento",
            value: "R$ 4,250",
            severity: .warning,
            action: {}
        )
        
        FinancialAlertCard(
            title: "Alerta Crítico",
            description: "Orçamento mensal excedido",
            value: "R$ 15,800",
            severity: .critical,
            action: {}
        )
        
        FinancialAlertCard(
            title: "Dica de Economia",
            description: "Você pode economizar 15% cortando gastos com serviços",
            value: "R$ 1,200",
            severity: .info,
            action: {}
        )
    }
    .padding(20)
    .background(Color.black)
    .preferredColorScheme(.dark)
}
