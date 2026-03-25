import SwiftUI

struct MarkdownChatBubble: View {
    let message: String
    let isAssistant: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isAssistant {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(.init(formatMarkdown(message)))
                        .textSelection(.enabled)
                        .lineSpacing(4)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            } else {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text(.init(formatMarkdown(message)))
                        .textSelection(.enabled)
                        .lineSpacing(4)
                }
                .padding(12)
                .background(Color.blue.opacity(0.8))
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
    }
    
    private func formatMarkdown(_ text: String) -> String {
        var result = text
        
        // Remove markdown characters for better readability
        // Bold: **text** -> text (keep bold via AttributedString)
        result = result.replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
        
        // Italic: *text* -> text
        result = result.replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
        
        // Code: `text` -> text
        result = result.replacingOccurrences(of: "`(.+?)`", with: "$1", options: .regularExpression)
        
        // Lists: - item -> • item
        result = result.replacingOccurrences(of: "^- ", with: "• ", options: .regularExpression)
        
        return result
    }
}

// Versão com melhor suporte a markdown
struct EnhancedMarkdownChatBubble: View {
    let message: String
    let isAssistant: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isAssistant {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                    .frame(width: 24, alignment: .top)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Render markdown properly
                    Text(.init(message))
                        .textSelection(.enabled)
                        .lineSpacing(4)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            } else {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(.init(message))
                        .textSelection(.enabled)
                        .lineSpacing(4)
                }
                .padding(12)
                .background(Color.blue.opacity(0.8))
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        EnhancedMarkdownChatBubble(
            message: "Aqui estão algumas sugestões:**\\n- Aumentar conteúdo\\n- Parcerias com marcas\\n- Lives semanais",
            isAssistant: true
        )
        
        EnhancedMarkdownChatBubble(
            message: "Adorei as ideias!",
            isAssistant: false
        )
    }
    .padding()
}
