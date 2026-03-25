import SwiftUI

struct StrategyModuleView: View {
    @State private var chatMessages: [StrategyChatMessage] = []
    @State private var inputText = ""
    
    struct StrategyChatMessage: Identifiable {
        let id: UUID
        let role: String
        let content: String
        let timestamp: Date
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Módulo Estratégia")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "wand.and.sparkles")
                    .foregroundStyle(.blue)
            }
            .padding()
            .background(Color(.systemGray6))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if chatMessages.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.title)
                                .foregroundStyle(.blue)
                            Text("Comece uma conversa sobre estratégia")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(chatMessages) { message in
                            HStack {
                                if message.role == "user" {
                                    Spacer()
                                    Text(message.content)
                                        .padding(12)
                                        .background(Color.blue)
                                        .foregroundStyle(.white)
                                        .cornerRadius(12)
                                } else {
                                    Text(message.content)
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .foregroundStyle(.white)
                                        .cornerRadius(12)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            
            Divider()
            
            HStack(spacing: 8) {
                TextField("Qual é sua estratégia?", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.blue)
                }
                .disabled(inputText.isEmpty)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty else { return }
        chatMessages.append(StrategyChatMessage(
            id: UUID(),
            role: "user",
            content: inputText,
            timestamp: Date()
        ))
        inputText = ""
        
        // Simular resposta da IA
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            chatMessages.append(StrategyChatMessage(
                id: UUID(),
                role: "assistant",
                content: "Ótima estratégia! Aqui estão sugestões de conteúdo para implementar.",
                timestamp: Date()
            ))
        }
    }
}

