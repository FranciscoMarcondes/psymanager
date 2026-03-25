import SwiftData
import SwiftUI

struct ManagerView: View {
    @Environment(\.modelContext) private var modelContext

    let profile: ArtistProfile

    @State private var input = ""
    @State private var isSending = false
    @State private var streamingAssistantText = ""
    @State private var sendTask: Task<Void, Never>?
    @State private var learnedFacts: [String] = []
    @State private var newFactInput = ""
    @State private var showLearnedFacts = false
    @AppStorage("manager.useWebAI") private var useWebAI = true
    @State private var showQuickPrompts = false

    @Query(sort: \ManagerChatMessage.createdAt) private var messages: [ManagerChatMessage]

    private let engine = CareerManagerEngine()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Hero
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Manager IA")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Copiloto com foco em \(profile.mainGoal.lowercased()).")
                                        .font(.footnote)
                                        .foregroundStyle(PsyTheme.textSecondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "brain.head.profile")
                                    .font(.title)
                                    .foregroundStyle(PsyTheme.primary.opacity(0.6))
                            }
                        }
                    }
                    .psyAppear()

                    PsySectionHeader(eyebrow: "Prompts", title: "Comece por aqui")
                        .psyAppear(delay: 0.04)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Learned Facts panel
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { withAnimation { showLearnedFacts.toggle() } }) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(PsyTheme.warning)
                            Text("Fatos aprendidos (\(learnedFacts.count))")
                                .font(.subheadline).fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: showLearnedFacts ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        .padding(14)
                        .background(PsyTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if showLearnedFacts {
                        VStack(alignment: .leading, spacing: 8) {
                            if learnedFacts.isEmpty {
                                Text("Nenhum fato registrado. Adicione insights sobre sua carreira.")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)
                                    .padding(.horizontal, 4)
                            } else {
                                ForEach(Array(learnedFacts.enumerated()), id: \.offset) { idx, fact in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundStyle(PsyTheme.primary)
                                        Text(fact)
                                            .font(.caption)
                                            .foregroundStyle(PsyTheme.textSecondary)
                                        Spacer()
                                        Button { removeFact(at: idx) } label: {
                                            Image(systemName: "xmark")
                                                .font(.caption2)
                                                .foregroundStyle(PsyTheme.textSecondary)
                                        }
                                    }
                                }
                            }
                            HStack {
                                TextField("Novo fato...", text: $newFactInput)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                Button("Adicionar") { addFact() }
                                    .disabled(newFactInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(PsyTheme.primary)
                            }
                        }
                        .padding(14)
                        .background(PsyTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    Toggle(isOn: $useWebAI) {
                        Label("Manager avançado (web IA)", systemImage: "globe")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .tint(PsyTheme.primary)
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showQuickPrompts.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Prompts rápidos")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: showQuickPrompts ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        .padding(12)
                        .background(PsyTheme.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if showQuickPrompts {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(ManagerPromptLibrary.quickPrompts, id: \.self) { prompt in
                                    Button {
                                        send(prompt)
                                    } label: {
                                        Text(prompt)
                                            .font(.footnote)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.white)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 12)
                                            .frame(width: 170, alignment: .leading)
                                            .background(PsyTheme.surfaceAlt)
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                    .stroke(PsyTheme.primary.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                .psyAppear(delay: 0.08)

                // Chat
                VStack(alignment: .leading, spacing: 14) {
                    PsySectionHeader(eyebrow: "Conversa", title: "Manager em ação")
                    
                    // 🧠 Manager with Memories Integration (NEW)
                    HStack {
                        Image(systemName: "brain.fill")
                            .font(.caption)
                            .foregroundStyle(PsyTheme.primary)
                        Text("Manager com Memórias")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(PsyTheme.textSecondary)
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(PsyTheme.primary)
                    }
                    .padding(8)
                    .background(PsyTheme.surfaceAlt.opacity(0.5))
                    .cornerRadius(8)

                    if messages.isEmpty {
                        PsyCard {
                            HStack(spacing: 12) {
                                Image(systemName: "brain")
                                    .font(.title2)
                                    .foregroundStyle(PsyTheme.primary)
                                Text("Escolha um prompt ou escreva uma pergunta sobre booking, conteúdo, branding ou estratégia.")
                                    .font(.subheadline)
                                    .foregroundStyle(PsyTheme.textSecondary)
                            }
                        }
                    } else {
                        ForEach(messages) { message in
                            PsyChatBubble(role: message.role, text: message.text)
                        }
                    }

                    if !streamingAssistantText.isEmpty {
                        PsyChatBubble(role: "assistant", text: streamingAssistantText)
                    }

                    if isSending && streamingAssistantText.isEmpty {
                        PsyCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(PsyTheme.primary)
                                        .controlSize(.small)
                                    Text("Manager analisando...")
                                        .font(.caption)
                                        .foregroundStyle(PsyTheme.textSecondary)
                                }
                                PsySkeletonLine()
                                PsySkeletonLine(width: 220)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .animation(.easeInOut(duration: 0.2), value: messages.count)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Manager IA")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.selection, trigger: messages.count)
            .onAppear { loadLearnedFacts() }
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
            .onDisappear {
                sendTask?.cancel()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Limpar") {
                        sendTask?.cancel()
                        streamingAssistantText = ""
                        isSending = false
                        for message in messages {
                            modelContext.delete(message)
                        }
                        try? modelContext.save()
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Pergunte ao seu manager...", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .accessibilityLabel("Mensagem para o manager")
                .accessibilityHint("Digite sua pergunta sobre carreira, booking ou conteúdo")
            Button {
                send(input)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
                            ? PsyTheme.textSecondary
                            : PsyTheme.primary
                    )
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                    .accessibilityLabel("Enviar mensagem")
                    .accessibilityHint("Envia a pergunta para o manager IA")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func send(_ prompt: String) {
        let cleaned = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        modelContext.insert(ManagerChatMessage(role: "user", text: cleaned))
        try? modelContext.save()
        isSending = true
        streamingAssistantText = ""
        input = ""

        sendTask?.cancel()
        sendTask = Task {
            let answer: String
            if useWebAI {
                answer = await WebAIService.shared.ask(
                    artistName: profile.stageName,
                    prompt: cleaned,
                    mode: "conversation"
                )
            } else {
                answer = await engine.ask(prompt: cleaned, profile: profile)
            }

            for character in answer {
                if Task.isCancelled { return }
                streamingAssistantText.append(character)
                try? await Task.sleep(for: .milliseconds(12))
            }

            if Task.isCancelled { return }
            modelContext.insert(ManagerChatMessage(role: "assistant", text: answer))
            try? modelContext.save()
            streamingAssistantText = ""
            isSending = false
        }
    }

    private func addFact() {
        let fact = newFactInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fact.isEmpty, !learnedFacts.contains(fact) else { return }
        learnedFacts.append(fact)
        saveLearnedFacts()
        newFactInput = ""
    }

    private func removeFact(at index: Int) {
        guard learnedFacts.indices.contains(index) else { return }
        learnedFacts.remove(at: index)
        saveLearnedFacts()
    }

    private func saveLearnedFacts() {
        let joined = learnedFacts.joined(separator: "|||")
        UserDefaults.standard.set(joined, forKey: "manager.learnedFacts.store")
    }

    private func loadLearnedFacts() {
        let joined = UserDefaults.standard.string(forKey: "manager.learnedFacts.store") ?? ""
        learnedFacts = joined.isEmpty ? [] : joined.components(separatedBy: "|||").filter { !$0.isEmpty }
    }
}
