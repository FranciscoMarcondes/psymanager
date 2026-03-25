import SwiftUI

/// Fix para Dark Mode: chevron visível em popups/menus
extension Menu {
    func darkModeAccessible() -> some View {
        self.labelStyle(.iconOnly)
    }
}

/// Componente genérico com dropdown visível em dark mode
struct AccessibleMenuButton<LabelContent: View>: View {
    let label: LabelContent
    let options: [MenuOption]
    let onSelect: (String) -> Void
    
    struct MenuOption {
        let label: String
        let value: String
        let icon: String?
    }
    
    var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button(action: { onSelect(option.value) }) {
                    if let icon = option.icon {
                        Label(option.label, systemImage: icon)
                    } else {
                        Text(option.label)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                label
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.white) // Force white color in dark mode
            }
            .padding(8)
            .background(Color(.systemGray5))
            .cornerRadius(6)
        }
    }
}

/// Exemplo de uso
struct DarkModeFixExample: View {
    @State private var selectedOption = "crescimento"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Seleções com Chevron Visível")
                .font(.headline)
            
            // Opção 1: Menu padrão com chevron branco
            Menu {
                Button("Crescimento de seguidores", action: { selectedOption = "crescimento" })
                Button("Atrair bookings", action: { selectedOption = "bookings" })
                Button("Engajamento", action: { selectedOption = "engagement" })
            } label: {
                HStack {
                    Text(selectedOption)
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.white) // Fix: force white
                }
                .padding(10)
                .background(Color(.systemGray5))
                .cornerRadius(6)
            }
            
            // Opção 2: Componente customizado
            AccessibleMenuButton(
                label: Text("Estratégia"),
                options: [
                    .init(label: "Social Media", value: "social", icon: "figure.wave"),
                    .init(label: "Parcerias", value: "partnerships", icon: "handshake"),
                    .init(label: "Eventos", value: "events", icon: "calendar"),
                ],
                onSelect: { selectedOption = $0 }
            )
        }
        .padding()
    }
}

#Preview {
    ZStack {
        Color(.systemGray6).ignoresSafeArea()
        
        DarkModeFixExample()
    }
    .preferredColorScheme(.dark)
}
