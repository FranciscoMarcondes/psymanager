import SwiftUI

struct ManagerMemoriesCollapsible: View {
    @State private var isExpanded = false
    let memories: [ManagerMemory]
    let onSelectMemory: (ManagerMemory) -> Void
    
    struct ManagerMemory: Identifiable {
        let id: UUID
        let title: String
        let content: String
        let createdAt: Date
    }
    
    var body: some View {
        if !memories.isEmpty {
            Menu {
                ForEach(memories) { memory in
                    Button(action: { onSelectMemory(memory) }) {
                        Label(memory.title, systemImage: "sparkles")
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "brain.fill")
                        .foregroundStyle(.blue)
                    Text("Memórias Salvas")
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(6)
            }
        }
    }
}

struct ManagerChatWithMemories: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var memories: [ManagerMemoriesCollapsible.ManagerMemory] = []
    @State private var showMemorySaved = false
    
    struct ChatMessage: Identifiable {
        let id: UUID
        let role: String // "user" or "assistant"
        let content: String
        let timestamp: Date
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewMessage"))) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            VStack(spacing: 8) {
                // Memories menu (collapsed by default)
                ManagerMemoriesCollapsible(
                    memories: memories,
                    onSelectMemory: { memory in
                        inputText = memory.content + " "
                    }
                )
                
                HStack(spacing: 8) {
                    TextField("Pergunte ao Manager...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.blue)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                
                // Memory save button
                Button(action: saveCurrentAsMemory) {
                    Label("Memorizar resposta anterior", systemImage: "bookmark")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.bordered)
                .disabled(messages.filter { $0.role == "assistant" }.isEmpty)
            }
            .padding()
        }
        .alert("Resposta Memorizada!", isPresented: $showMemorySaved) {
            Button("OK") { }
        } message: {
            Text("A IA vai usar essa informação para análises futuras sobre você.")
        }
    }
    
    private func sendMessage() {
        let userMessage = ChatMessage(
            id: UUID(),
            role: "user",
            content: inputText,
            timestamp: Date()
        )
        messages.append(userMessage)
        inputText = ""
        
        // Simulate AI response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiResponse = ChatMessage(
                id: UUID(),
                role: "assistant",
                content: "Resposta do Manager IA...",
                timestamp: Date()
            )
            messages.append(aiResponse)
            NotificationCenter.default.post(name: NSNotification.Name("NewMessage"), object: nil)
        }
    }
    
    private func saveCurrentAsMemory() {
        if let lastAssistantMessage = messages.filter({ $0.role == "assistant" }).last {
            let memory = ManagerMemoriesCollapsible.ManagerMemory(
                id: UUID(),
                title: "Memória \(Date().formatted(date: .abbreviated, time: .shortened))",
                content: lastAssistantMessage.content,
                createdAt: Date()
            )
            memories.append(memory)
            showMemorySaved = true
        }
    }
}

struct ChatBubble: View {
    let message: ManagerChatWithMemories.ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == "assistant" {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading) {
                    Text(.init(message.content))
                        .textSelection(.enabled)
                    Text(message.timestamp.formatted(time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Spacer()
            } else {
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(message.content)
                        .textSelection(.enabled)
                    Text(message.timestamp.formatted(time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.blue.opacity(0.7))
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
        }
    }
}

#Preview {
    ManagerChatWithMemories()
}
