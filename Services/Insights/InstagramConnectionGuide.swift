import Foundation

struct InstagramConnectionGuide {
    static let requirements = [
        "Conta Instagram profissional (Business ou Creator)",
        "Página do Facebook vinculada",
        "Aplicativo Meta registrado com permissões do Instagram Graph API",
        "Fluxo OAuth seguro via backend (recomendado)",
    ]

    static let note = "A conexão direta completa depende de configuração no Meta for Developers e backend para troca segura de tokens. Até lá, o app funciona com importação manual de insights."
}
