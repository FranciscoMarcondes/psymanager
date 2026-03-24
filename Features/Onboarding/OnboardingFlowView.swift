import SwiftData
import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var step = 0
    @State private var stageName = ""
    @State private var city = ""
    @State private var state = ""
    @State private var artistStage = ArtistStage.growing
    @State private var mainGoal = "Suporte 360°: booking, conteúdo, gigs, logística, networking e posicionamento"
    @State private var toneOfVoice = "Misterioso, magnético e confiante"
    @State private var contentFocus = "Reels de bastidor, performance e storytelling"
    @State private var visualIdentity = "Psicodelia geométrica, neon orgânico e atmosfera futurista"

    private let totalSteps = 4

    private var currentStepTitle: String {
        switch step {
        case 0: return "Identidade artística"
        case 1: return "Fase de carreira"
        case 2: return "Tom e visual"
        default: return "Foco inicial"
        }
    }

    private var currentStepHint: String {
        switch step {
        case 0: return "Base do perfil para personalizar o manager"
        case 1: return "Define o nível de orientação e recomendações"
        case 2: return "Alinha linguagem, estética e presença digital"
        default: return "Resumo final antes de entrar no app"
        }
    }

    var body: some View {
        ZStack {
            PsyTheme.heroGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("PsyManager")
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Onboarding inteligente")
                                        .font(.subheadline)
                                        .foregroundStyle(PsyTheme.primary)
                                }
                                Spacer()
                                Image(systemName: "sparkles")
                                    .font(.title)
                                    .foregroundStyle(PsyTheme.primary.opacity(0.6))
                            }

                            Text("Seu manager digital para booking, conteúdo e estratégia artística.")
                                .font(.subheadline)
                                .foregroundStyle(PsyTheme.textSecondary)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Passo \(step + 1) de \(totalSteps)")
                                        .font(.caption)
                                        .foregroundStyle(PsyTheme.textSecondary)
                                    Spacer()
                                    Text(currentStepTitle)
                                        .font(.caption)
                                        .foregroundStyle(PsyTheme.primary)
                                }

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.12))
                                            .frame(height: 8)
                                        Capsule()
                                            .fill(PsyTheme.primary)
                                            .frame(width: geo.size.width * (Double(step + 1) / Double(totalSteps)), height: 8)
                                    }
                                }
                                .frame(height: 8)

                                HStack(spacing: 6) {
                                    ForEach(0 ..< totalSteps, id: \.self) { idx in
                                        Circle()
                                            .fill(idx <= step ? PsyTheme.primary : Color.white.opacity(0.25))
                                            .frame(width: 7, height: 7)
                                    }
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Progresso do onboarding")
                            .accessibilityValue("Passo \(step + 1) de \(totalSteps): \(currentStepTitle)")
                        }
                    }
                    .psyAppear()

                    PsyCard {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(currentStepHint)
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)

                            stepView
                                .id(step)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                        }
                    }
                    .psyAppear(delay: 0.04)

                    HStack(spacing: 12) {
                        if step > 0 {
                            Button("Voltar") {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    step -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                            .accessibilityHint("Retorna para o passo anterior")
                        }

                        Button(step == 3 ? "Entrar no app" : "Continuar") {
                            if step == 3 {
                                saveProfile()
                            } else {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    step += 1
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(PsyTheme.primary)
                        .disabled(isCurrentStepInvalid)
                        .accessibilityHint(step == 3 ? "Finaliza cadastro e abre o app" : "Avança para o próximo passo")
                    }
                }
                .padding(20)
            }
        }
        .sensoryFeedback(.selection, trigger: step)
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: 12) {
                Text("Qual e o seu nome artistico?")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                TextField("Ex.: Astral Nomad", text: $stageName)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel("Nome artístico")

                HStack {
                    TextField("Cidade", text: $city)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Cidade")
                    TextField("UF", text: $state)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .accessibilityLabel("Estado")
                }
            }
        case 1:
            VStack(alignment: .leading, spacing: 12) {
                Text("Em que fase está sua carreira?")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Picker("Fase", selection: $artistStage) {
                    ForEach(ArtistStage.allCases) { stage in
                        Text(stage.rawValue).tag(stage)
                    }
                }
                .pickerStyle(.segmented)

                Text("Atuação do manager")
                    .foregroundStyle(PsyTheme.textSecondary)

                Text("O app vai te apoiar em todas as áreas ao mesmo tempo, sem limitar a uma única prioridade.")
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 6) {
                    Text("• Booking e negociação")
                    Text("• Conteúdo e redes sociais")
                    Text("• Planejamento de gigs e logística")
                    Text("• Relacionamento com promoters e posicionamento")
                }
                .font(.caption)
                .foregroundStyle(PsyTheme.textSecondary)
            }
        case 2:
            VStack(alignment: .leading, spacing: 12) {
                Text("Como sua marca deve soar e parecer?")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                TextField("Tom de voz", text: $toneOfVoice)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Tom de voz")

                TextField("Identidade visual", text: $visualIdentity, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...4)
                    .accessibilityLabel("Identidade visual")
            }
        default:
            VStack(alignment: .leading, spacing: 12) {
                Text("O que a IA deve priorizar?", comment: "")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                TextField("Foco de conteúdo", text: $contentFocus, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...4)
                    .accessibilityLabel("Foco de conteúdo")

                PsyCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resumo inicial do manager")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(stageName.isEmpty ? "Seu projeto" : stageName) é um artista de psytrance em fase \(artistStage.rawValue.lowercased()), com suporte completo em carreira e comunicação \(toneOfVoice.lowercased()).")
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var isCurrentStepInvalid: Bool {
        switch step {
        case 0:
            return stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return false
        }
    }

    private func saveProfile() {
        let profile = ArtistProfile(
            stageName: stageName,
            genre: "Psytrance",
            city: city,
            state: state,
            artistStage: artistStage.rawValue,
            toneOfVoice: toneOfVoice,
            mainGoal: mainGoal,
            contentFocus: contentFocus,
            visualIdentity: visualIdentity
        )
        modelContext.insert(profile)
        try? SampleDataSeeder.seedIfNeeded(in: modelContext)
        try? modelContext.save()
    }
}
