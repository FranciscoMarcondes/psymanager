import SwiftUI

struct CoverDesignStudioView: View {
    let profile: ArtistProfile
    @State private var currentStep = 1
    @State private var wizardPurpose = ""
    @State private var wizardTitle = ""
    @State private var wizardFeeling = ""
    @State private var wizardStyle = ""
    @State private var wizardDetails = ""
    @State private var generatedPrompt = ""
    @State private var isCopied = false
        @State private var isGeneratingImage = false
        @State private var generatedImageURLString = ""
        @State private var imageGenError = ""

    private let purposes = ["Capa de álbum", "Capa do YouTube", "Capa de playlist", "Post Instagram", "Capa de música", "Flyer de evento"]
    private let styles = ["Ultra-realista", "Arte digital", "Neon / Futurista", "Quadrinhos", "Abstrato", "Aquarela", "Minimalista", "Cartoon 3D"]

    private var stepLabel: String {
        switch currentStep {
        case 1: return "Para que é essa arte?"
        case 2: return "Título e sentimento"
        case 3: return "Estilo visual"
        default: return "Detalhes finais"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Criar arte com IA")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Gera prompt profissional para Bing Image Creator")
                                        .font(.subheadline)
                                        .foregroundStyle(PsyTheme.primary)
                                }
                                Spacer()
                                Image(systemName: "wand.and.stars")
                                    .font(.title)
                                    .foregroundStyle(PsyTheme.primary.opacity(0.6))
                            }
                            Text("Responda algumas perguntas — montamos um prompt para gerar sua arte gratuitamente.")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }

                    // Step indicators
                    PsyCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                ForEach(1...4, id: \.self) { step in
                                    Button {
                                        if step < currentStep { currentStep = step }
                                    } label: {
                                        Text("\(step)")
                                            .font(.system(size: 13, weight: .bold))
                                            .frame(width: 28, height: 28)
                                            .background(currentStep >= step ? PsyTheme.primary : Color.white.opacity(0.15))
                                            .foregroundStyle(currentStep >= step ? .black : PsyTheme.textSecondary)
                                            .clipShape(Circle())
                                    }
                                    .disabled(step >= currentStep)
                                }
                                Text(stepLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(PsyTheme.textSecondary)
                                    .padding(.leading, 4)
                                Spacer()
                            }

                            Divider().overlay(Color.white.opacity(0.1))

                            // Step content
                            switch currentStep {
                            case 1: step1View
                            case 2: step2View
                            case 3: step3View
                            default: step4View
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Capas")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Step views

    private var step1View: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1. Para que é essa arte?")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(purposes, id: \.self) { opt in
                    chipButton(opt, isSelected: wizardPurpose == opt) { wizardPurpose = opt }
                }
            }
            Button { withAnimation { currentStep = 2 } } label: {
                Text("Próximo →")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(wizardPurpose.isEmpty ? PsyTheme.primary.opacity(0.3) : PsyTheme.primary)
                    .foregroundStyle(wizardPurpose.isEmpty ? PsyTheme.textSecondary : .black)
                    .cornerRadius(8)
            }
            .disabled(wizardPurpose.isEmpty)
        }
    }

    private var step2View: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2. Sua música / arte")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
            TextField("Nome da capa / título da música *", text: $wizardTitle)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(8)
                .foregroundStyle(.white)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $wizardFeeling)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                if wizardFeeling.isEmpty {
                    Text("Como essa música te faz sentir? (ex: energia tribal, melancolia noturna…)")
                        .foregroundStyle(PsyTheme.textSecondary)
                        .font(.callout)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            HStack(spacing: 8) {
                Button { withAnimation { currentStep = 1 } } label: {
                    Text("← Voltar").foregroundStyle(PsyTheme.textSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.white.opacity(0.08)).cornerRadius(8)
                }
                Button { withAnimation { currentStep = 3 } } label: {
                    Text("Próximo →").frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background((wizardTitle.trimmingCharacters(in: .whitespaces).isEmpty || wizardFeeling.trimmingCharacters(in: .whitespaces).isEmpty) ? PsyTheme.primary.opacity(0.3) : PsyTheme.primary)
                        .foregroundStyle((wizardTitle.trimmingCharacters(in: .whitespaces).isEmpty || wizardFeeling.trimmingCharacters(in: .whitespaces).isEmpty) ? PsyTheme.textSecondary : .black)
                        .cornerRadius(8)
                }
                .disabled(wizardTitle.trimmingCharacters(in: .whitespaces).isEmpty || wizardFeeling.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var step3View: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("3. Estilo visual")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(styles, id: \.self) { opt in
                    chipButton(opt, isSelected: wizardStyle == opt) { wizardStyle = opt }
                }
            }
            HStack(spacing: 8) {
                Button { withAnimation { currentStep = 2 } } label: {
                    Text("← Voltar").foregroundStyle(PsyTheme.textSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.white.opacity(0.08)).cornerRadius(8)
                }
                Button { withAnimation { currentStep = 4 } } label: {
                    Text("Próximo →").frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(wizardStyle.isEmpty ? PsyTheme.primary.opacity(0.3) : PsyTheme.primary)
                        .foregroundStyle(wizardStyle.isEmpty ? PsyTheme.textSecondary : .black)
                        .cornerRadius(8)
                }
                .disabled(wizardStyle.isEmpty)
            }
        }
    }

    private var step4View: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("4. Detalhes extras (opcional)")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.white)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $wizardDetails)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(8)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                if wizardDetails.isEmpty {
                    Text("Cores predominantes, elementos específicos, referências artísticas, texto na imagem…")
                        .foregroundStyle(PsyTheme.textSecondary)
                        .font(.callout)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            HStack(spacing: 8) {
                Button { withAnimation { currentStep = 3 } } label: {
                    Text("← Voltar").foregroundStyle(PsyTheme.textSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.white.opacity(0.08)).cornerRadius(8)
                }
                Button { buildPrompt() } label: {
                    Label("✨ Montar prompt", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(PsyTheme.primary)
                        .foregroundStyle(.black)
                        .cornerRadius(8)
                }
            }

            if !generatedPrompt.isEmpty {
                Divider().overlay(Color.white.opacity(0.1))

                Text("Prompt gerado — edite se quiser:")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(PsyTheme.primary)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $generatedPrompt)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(8)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                        .font(.caption)
                }

                Button {
                    UIPasteboard.general.string = generatedPrompt
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
                } label: {
                    Label(isCopied ? "Copiado!" : "📋 Copiar prompt", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isCopied ? Color.green.opacity(0.8) : Color.white.opacity(0.12))
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }

                Text("Cole esse prompt no Bing Image Creator (bing.com/images/create) para gerar sua arte gratuitamente.")
                    .font(.caption2)
                    .foregroundStyle(PsyTheme.textSecondary)

                // Generate image via backend
                Divider().overlay(Color.white.opacity(0.1))

                Button {
                    Task { await generateImage() }
                } label: {
                    Label(isGeneratingImage ? "Gerando imagem..." : "🖼 Gerar imagem com IA",
                          systemImage: isGeneratingImage ? "hourglass" : "wand.and.stars")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isGeneratingImage ? PsyTheme.primary.opacity(0.3) : Color.purple.opacity(0.8))
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                }
                .disabled(isGeneratingImage)

                if !imageGenError.isEmpty {
                    Text(imageGenError)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                if !generatedImageURLString.isEmpty, let url = URL(string: generatedImageURLString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(PsyTheme.primary.opacity(0.5), lineWidth: 1)
                                )
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.orange)
                                Text("Não foi possível carregar a imagem")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.white)
                                Text("Verifique a conexão e tente novamente")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        default:
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(PsyTheme.primary)
                                Text("Gerando arte...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                        }
                    }
                }

                Text("Gerado via DALL-E / Pollinations. Resultado pode variar.")
                    .font(.caption2)
                    .foregroundStyle(PsyTheme.textSecondary)
            }
        }
    }

    // MARK: - Helpers

    private func chipButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption).fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? PsyTheme.primary : Color.white.opacity(0.08))
                .foregroundStyle(isSelected ? .black : .white)
                .cornerRadius(6)
        }
    }

    private func buildPrompt() {
        let genre = profile.genre.isEmpty ? "música eletrônica" : profile.genre
        let artistName = profile.stageName.isEmpty ? "artista" : profile.stageName
        let details = wizardDetails.trimmingCharacters(in: .whitespaces)
        let extraLine = details.isEmpty ? "" : " Detalhes adicionais: \(details)."

        generatedPrompt = """
        Criar arte visual para \(wizardPurpose.lowercased()) de \(artistName).
        Título: "\(wizardTitle)". Gênero: \(genre).
        Sentimento / conceito: \(wizardFeeling).
        Estilo visual: \(wizardStyle).\(extraLine)
        Imagem de alta qualidade, composição profissional para uso em plataformas digitais.
        """
    }

    private func generateImage() async {
        guard !generatedPrompt.isEmpty else { return }
        isGeneratingImage = true
        imageGenError = ""
        generatedImageURLString = ""

        struct GenerateRequest: Encodable {
            let prompt: String
        }
        struct GenerateResponse: Decodable {
            let imageUrl: String?
            let url: String?
            let error: String?
        }

        let baseURL = UserDefaults.standard.string(forKey: "psy.web.baseURL")
            ?? "https://web-app-eight-hazel.vercel.app"

        guard let endpoint = URL(string: "\(baseURL)/api/generate-cover") else {
            imageGenError = "URL inválida."
            isGeneratingImage = false
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        do {
            request.httpBody = try JSONEncoder().encode(GenerateRequest(prompt: generatedPrompt))
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                imageGenError = "Erro do servidor. Verifique a chave OPENAI_API_KEY no backend."
                isGeneratingImage = false
                return
            }
            let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
            if let url = decoded.imageUrl ?? decoded.url {
                generatedImageURLString = url
            } else {
                imageGenError = decoded.error ?? "Resposta inesperada do servidor."
            }
        } catch {
            imageGenError = "Falha na conexão: \(error.localizedDescription)"
        }
        isGeneratingImage = false
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        
        guard scanner.scanHexInt64(&rgbValue) else { return nil }
        
        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue, opacity: 1.0)
    }
}
