import SwiftUI
import Speech
import AVFoundation
import SwiftData

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
    @State private var isGenerating = false
    @State private var typingAnimation = 0
    private let typingTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

        // Voice input
        @State private var isRecording = false
        @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
        @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
        @State private var recognitionTask: SFSpeechRecognitionTask?
        @State private var audioEngine = AVAudioEngine()
        @State private var voicePermissionDenied = false

        // LearnedFacts
        @Environment(\.modelContext) private var modelContext
        @Query(sort: \LearnedFact.createdAt, order: .reverse) private var learnedFacts: [LearnedFact]
        @State private var suggestedFacts: [LearnedFact] = []
        @State private var showLearnedFactsPanel = false
        @State private var selectedFactForApproval: LearnedFact?
    
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
                        
                        // Typing indicator
                        if isGenerating {
                            TypingIndicatorView(animation: $typingAnimation)
                                .onReceive(typingTimer) { _ in
                                    typingAnimation = (typingAnimation + 1) % 3
                                }
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
                HStack(spacing: 12) {
                    ManagerMemoriesCollapsible(
                        memories: memories,
                        onSelectMemory: { memory in
                            inputText = memory.content + " "
                        }
                    )
                    
                    // Learned Facts Panel Button
                    if !learnedFacts.isEmpty {
                        Menu {
                            ForEach(learnedFacts) { fact in
                                Button(action: {}) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Label(fact.content, systemImage: "lightbulb.fill")
                                            .lineLimit(2)
                                        Text(fact.category.capitalized)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.orange)
                                Text("Aprendidos (\(learnedFacts.count))")
                                    .font(.caption)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .padding(8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                }
                
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
                    HStack(spacing: 8) {
                        TextField("Pergunte ao Manager...", text: $inputText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)

                        // Mic button
                        Button {
                            isRecording ? stopRecording() : startRecording()
                        } label: {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                                .foregroundStyle(isRecording ? .red : .secondary)
                                .symbolEffect(.pulse, isActive: isRecording)
                        }

                        // Send button
                        Button(action: sendMessage) {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(.blue)
                        }
                        .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if voicePermissionDenied {
                        Text("Permissão de microfone negada. Ative em Ajustes > PsyManager.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
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
        .sheet(isPresented: $showLearnedFactsPanel) {
            LearnedFactsReviewSheet(
                suggestedFacts: $suggestedFacts,
                onApproveFact: { fact in
                    modelContext.insert(fact)
                    try? modelContext.save()
                    
                    Task {
                        // Sync to backend
                        if let userId = UserDefaults.standard.string(forKey: "userId") {
                            await LearnedFactsService.shared.syncFactsToBackend([fact], userId: userId)
                        }
                    }
                },
                onRejectFact: { fact in
                    suggestedFacts.removeAll { $0.id == fact.id }
                    if suggestedFacts.isEmpty {
                        showLearnedFactsPanel = false
                    }
                }
            )
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
        
        isGenerating = true
        
        // Simulate AI response with typing indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let aiResponse = ChatMessage(
                id: UUID(),
                role: "assistant",
                content: "Resposta do Manager IA...",
                timestamp: Date()
            )
            messages.append(aiResponse)
            isGenerating = false
            NotificationCenter.default.post(name: NSNotification.Name("NewMessage"), object: nil)
            
            // Extract learned facts from response
            Task {
                let extracted = await LearnedFactsService.shared.extractFactsFromResponse(aiResponse.content)
                
                DispatchQueue.main.async {
                    if !extracted.isEmpty {
                        suggestedFacts = extracted
                        showLearnedFactsPanel = true
                    }
                }
            }
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

        // MARK: - Voice recognition

        private func startRecording() {
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    guard status == .authorized else {
                        voicePermissionDenied = true
                        return
                    }
                    voicePermissionDenied = false
                    do {
                        try beginAudioSession()
                    } catch {
                        isRecording = false
                    }
                }
            }
        }

        private func beginAudioSession() throws {
            recognitionTask?.cancel()
            recognitionTask = nil

            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
                if let result {
                    DispatchQueue.main.async {
                        inputText = result.bestTranscription.formattedString
                    }
                }
                if error != nil || (result?.isFinal == true) {
                    DispatchQueue.main.async { stopRecording() }
                }
            }

            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        }

        private func stopRecording() {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            try? AVAudioSession.sharedInstance().setActive(false)
            isRecording = false
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
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
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
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
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

struct TypingIndicatorView: View {
    @Binding var animation: Int
    let dots = ["●", "●", "●"]
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Text(dots[index])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                        .scaleEffect(animation == index ? 1.2 : 1.0)
                        .offset(y: animation == index ? -2 : 0)
                        .animation(.easeInOut(duration: 0.3), value: animation)
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Spacer()
        }
    }
}

// MARK: - LearnedFacts Review Sheet

struct LearnedFactsReviewSheet: View {
    @Binding var suggestedFacts: [LearnedFact]
    let onApproveFact: (LearnedFact) -> Void
    let onRejectFact: (LearnedFact) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Fatos Aprendidos Automaticamente") {
                    ForEach($suggestedFacts) { $fact in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fact.content)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                    
                                    HStack(spacing: 12) {
                                        Label(fact.category.capitalized, systemImage: "tag.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        
                                        HStack(spacing: 2) {
                                            Text("Confiança: ")
                                                .font(.caption2)
                                            Text(String(format: "%.0f%%", fact.confidence * 100))
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            
                            HStack(spacing: 8) {
                                Button(action: { onRejectFact(fact) }) {
                                    Label("Rejeitar", systemImage: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(.gray)
                                
                                Button(action: { onApproveFact(fact) }) {
                                    Label("Aprender", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .tint(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Revisar Aprendizados")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Feito") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ManagerChatWithMemories()
}
