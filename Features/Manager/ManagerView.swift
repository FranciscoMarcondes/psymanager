import SwiftData
import SwiftUI

struct ManagerView: View {
    @Environment(\.modelContext) private var modelContext

    let profile: ArtistProfile

    @State private var input = ""
    @State private var isSending = false
    @State private var streamingAssistantText = ""
    @State private var sendTask: Task<Void, Never>?

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

                // Chips horizontais
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
                            .accessibilityLabel("Prompt rápido: \(prompt)")
                            .accessibilityHint("Envia este prompt para o manager IA")
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 4)
                .psyAppear(delay: 0.08)

                // Chat
                VStack(alignment: .leading, spacing: 14) {
                    PsySectionHeader(eyebrow: "Conversa", title: "Manager em ação")

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
            let answer = await engine.ask(prompt: cleaned, profile: profile)

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
}
