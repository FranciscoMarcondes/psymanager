import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var allConversations: [Conversation]
    @Query(sort: \ArtistProfile.createdAt) private var profiles: [ArtistProfile]
    
    @State private var showNewConversation = false
    @State private var selectedMode: String = "strategy"
    @State private var selectedConversation: Conversation?
    @State private var showArchived = false
    
    private var activeConversations: [Conversation] {
        allConversations.filter { !$0.isArchived }
    }
    
    private var archivedConversations: [Conversation] {
        allConversations.filter { $0.isArchived }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with Mode Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("💬 Histórico de Conversas")
                        .font(.headline)
                    
                    Picker("Modo", selection: $selectedMode) {
                        Text("Estratégia").tag("strategy")
                        Text("Booking").tag("booking")
                        Text("Bio").tag("bio")
                        Text("Reel").tag("reel")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .background(PsyTheme.surface)
                
                // Active Conversations
                if activeConversations.isEmpty && !showArchived {
                    emptyState
                } else {
                    List {
                        if !activeConversations.isEmpty {
                            Section("Ativas") {
                                ForEach(activeConversations.filter { $0.mode == selectedMode }) { conversation in
                                    NavigationLink(destination: ConversationDetailView(conversation: conversation)) {
                                        ConversationRowView(conversation: conversation)
                                    }
                                    .listRowBackground(PsyTheme.surfaceAlt)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            conversation.isArchived = true
                                            try? modelContext.save()
                                        } label: {
                                            Label("Arquivar", systemImage: "archivebox")
                                        }
                                    }
                                }
                            }
                        }
                        
                        if !archivedConversations.isEmpty && showArchived {
                            Section("Arquivadas") {
                                ForEach(archivedConversations.filter { $0.mode == selectedMode }) { conversation in
                                    ConversationRowView(conversation: conversation)
                                        .swipeActions(edge: .trailing) {
                                            Button {
                                                conversation.isArchived = false
                                                try? modelContext.save()
                                            } label: {
                                                Label("Restaurar", systemImage: "arrowshape.turn.up.left")
                                            }
                                            .tint(.blue)
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    
                    // Show Archived Toggle
                    if !archivedConversations.isEmpty {
                        HStack {
                            Spacer()
                            Button {
                                showArchived.toggle()
                            } label: {
                                Text(showArchived ? "Ocultar arquivadas" : "Ver arquivadas")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.primary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewConversation = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(PsyTheme.primary)
                    }
                }
            }
            .sheet(isPresented: $showNewConversation) {
                NewConversationSheet(isPresented: $showNewConversation)
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.right.and.bubble.left")
                .font(.system(size: 48))
                .foregroundStyle(PsyTheme.textSecondary)
            
            Text("Sem conversas ainda")
                .font(.headline)
            
            Text("Comece uma nova conversa para receber sugestões estratégicas do seu manager IA")
                .font(.caption)
                .foregroundStyle(PsyTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Button {
                showNewConversation = true
            } label: {
                Label("Nova Conversa", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(PsyTheme.primary)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 40)
    }
}

struct ConversationRowView: View {
    let conversation: Conversation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(conversation.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text(conversation.summary)
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(conversation.mode.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PsyTheme.primary.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(PsyTheme.textSecondary)
                }
            }
        }
        .padding(10)
    }
}

struct ConversationDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ArtistProfile.createdAt) private var profiles: [ArtistProfile]
    @State private var conversation: Conversation
    @State private var userInput = ""
    @State private var isGenerating = false
    
    private let engine = CareerManagerEngine()
    
    init(conversation: Conversation) {
        _conversation = State(initialValue: conversation)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages List
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(conversation.messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding(16)
            }
            .background(PsyTheme.background)
            
            // Input Area
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Mensagem...", text: $userInput)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isGenerating)
                    
                    Button {
                        Task {
                            await sendMessage()
                        }
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .background(isGenerating ? PsyTheme.textSecondary : PsyTheme.primary)
                    .cornerRadius(8)
                    .disabled(userInput.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)
                }
                .padding(12)
                
                if isGenerating {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Manager está pensando...")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .background(PsyTheme.surface)
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() async {
        let userMessage = ManagerChatMessage(
            role: "user",
            text: userInput,
            createdAt: Date()
        )
        
        conversation.addMessage(userMessage)
        userInput = ""
        isGenerating = true
        
        let prompt = """
        Contexto: \(conversation.mode) | Modo: \(conversation.title)
        Mensagem do usuário: \(userMessage.text)
        
        Responda de forma concisa e acionável em português.
        """

        let profileContext = profiles.first ?? ArtistProfile(
            stageName: "DJ Fantasma",
            genre: "Psytrance",
            city: "São Paulo",
            state: "SP",
            artistStage: "Emergente",
            toneOfVoice: "Direto",
            mainGoal: "Booking mais gigs",
            contentFocus: "Shows ao vivo",
            visualIdentity: "Borda onirica"
        )

        let response = await engine.ask(prompt: prompt, profile: profileContext)

        let aiMessage = ManagerChatMessage(
            role: "assistant",
            text: response,
            createdAt: Date()
        )

        conversation.addMessage(aiMessage)
        try? modelContext.save()
        
        isGenerating = false
    }
}

struct MessageBubble: View {
    let message: ManagerChatMessage
    
    var body: some View {
        HStack {
            if message.role == "assistant" {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .font(.subheadline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(PsyTheme.primary.opacity(0.15))
                .cornerRadius(12)
                
                Spacer()
            } else {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.subheadline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(PsyTheme.primary)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
    }
}

struct NewConversationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    @State private var title = ""
    @State private var selectedMode = "strategy"
    
    let modes = [("strategy", "🎯 Estratégia"), ("booking", "🎤 Booking"), ("bio", "✍️ Bio"), ("reel", "🎬 Reel")]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Título da Conversa")
                        .font(.subheadline)
                    
                    TextField("Ex: Plano de prospecção Q2", text: $title)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Modo")
                        .font(.subheadline)
                    
                    VStack(spacing: 8) {
                        ForEach(modes, id: \.0) { mode, label in
                            Button {
                                selectedMode = mode
                            } label: {
                                HStack {
                                    Text(label)
                                    Spacer()
                                    if selectedMode == mode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(PsyTheme.primary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(selectedMode == mode ? PsyTheme.primary.opacity(0.1) : PsyTheme.surface)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    let conversation = Conversation(
                        title: title.isEmpty ? "Nova Conversa" : title,
                        mode: selectedMode
                    )
                    modelContext.insert(conversation)
                    try? modelContext.save()
                    isPresented = false
                } label: {
                    Text("Criar Conversa")
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(PsyTheme.primary)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Nova Conversa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    ConversationListView()
}
