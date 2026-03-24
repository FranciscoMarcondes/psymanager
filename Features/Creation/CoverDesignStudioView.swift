import SwiftUI

struct CoverDesignStudioView: View {
    let profile: ArtistProfile
    @State private var selectedPlatforms: Set<String> = ["Spotify", "YouTube"]
    @State private var trackName = ""
    @State private var mood = "energético"
    
    private let moods = ["energético", "melancólico", "experimental", "groovy", "dark"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PsyHeroCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Estúdio de capas")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Direção visual multi-plataforma")
                                        .font(.subheadline)
                                        .foregroundStyle(PsyTheme.primary)
                                }
                                Spacer()
                                Image(systemName: "photo.artframe")
                                    .font(.title)
                                    .foregroundStyle(PsyTheme.primary.opacity(0.6))
                            }
                            Text("Recomendações visuais para suas faixas em múltiplas plataformas")
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    
                    platformSelectionSection
                    generatorInputSection
                    
                    if !selectedPlatforms.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            PsySectionHeader(eyebrow: "Designs", title: "Recomendações por plataforma")
                            
                            ForEach(Array(selectedPlatforms).sorted(), id: \.self) { platformName in
                                if let format = CoverDesignFormat(rawValue: platformName) {
                                    platformRecommendationCard(format: format)
                                }
                            }
                        }
                    } else {
                        PsyCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selecione ao menos uma plataforma")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("As recomendações visuais aparecem aqui automaticamente após escolher os destinos de lançamento.")
                                    .font(.caption)
                                    .foregroundStyle(PsyTheme.textSecondary)
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
    
    private var platformSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Plataformas", title: "Selecione onde vai lançar")
            
            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    // Streaming de Áudio
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎵 Streaming de Áudio")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(PsyTheme.primary)
                        
                        HStack(spacing: 10) {
                            platformToggle("Spotify", isSelected: selectedPlatforms.contains("Spotify"))
                            platformToggle("Apple Music", isSelected: selectedPlatforms.contains("Apple Music"))
                        }
                        HStack(spacing: 10) {
                            platformToggle("SoundCloud", isSelected: selectedPlatforms.contains("SoundCloud"))
                            platformToggle("Bandcamp", isSelected: selectedPlatforms.contains("Bandcamp"))
                        }
                    }
                    
                    Divider()
                        .overlay(Color.white.opacity(0.1))
                    
                    // Social Media
                    VStack(alignment: .leading, spacing: 8) {
                        Text("📱 Social Media")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(PsyTheme.primary)
                        
                        HStack(spacing: 10) {
                            platformToggle("Reel", isSelected: selectedPlatforms.contains("Reel"))
                            platformToggle("TikTok", isSelected: selectedPlatforms.contains("TikTok"))
                        }
                        HStack(spacing: 10) {
                            platformToggle("Instagram Story", isSelected: selectedPlatforms.contains("Instagram Story"))
                            platformToggle("YouTube", isSelected: selectedPlatforms.contains("YouTube"))
                        }
                    }
                    
                    Divider()
                        .overlay(Color.white.opacity(0.1))
                    
                    // Streaming de Vídeo e Comunidade
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🎬 Vídeo e Comunidade")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(PsyTheme.primary)
                        
                        HStack(spacing: 10) {
                            platformToggle("Twitch", isSelected: selectedPlatforms.contains("Twitch"))
                            platformToggle("Discord", isSelected: selectedPlatforms.contains("Discord"))
                        }
                        HStack(spacing: 10) {
                            platformToggle("Beatsport", isSelected: selectedPlatforms.contains("Beatsport"))
                        }
                    }
                }
            }
        }
    }
    
    private func platformToggle(_ name: String, isSelected: Bool) -> some View {
        Button(action: {
            if isSelected {
                selectedPlatforms.remove(name)
            } else {
                selectedPlatforms.insert(name)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? PsyTheme.primary : PsyTheme.secondary)
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(isSelected ? Color.white.opacity(0.05) : Color.clear)
            .cornerRadius(6)
        }
    }
    
    private var generatorInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PsySectionHeader(eyebrow: "Input", title: "Contexto da faixa")
            
            PsyCard {
                VStack(spacing: 16) {
                    TextField("Nome da faixa (opcional)", text: $trackName)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("Mood/Vibe", selection: $mood) {
                        ForEach(moods, id: \.self) { m in
                            Text(m.capitalized).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }
    
    private func platformRecommendationCard(format: CoverDesignFormat) -> some View {
        let recommendation = CoverDesignGenerator.generateForTrack(
            trackName: trackName.isEmpty ? "Untitled" : trackName,
            profile: profile,
            format: format,
            mood: mood
        )
        
        return PsyCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header com formato
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.format)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(format.description)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .foregroundStyle(PsyTheme.primary)
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.1))
                
                // Dimensões
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dimensões")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.primary)
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tamanho")
                                .font(.caption2)
                                .foregroundStyle(PsyTheme.textSecondary)
                            Text(recommendation.sizingTips)
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Resolução")
                                .font(.caption2)
                                .foregroundStyle(PsyTheme.textSecondary)
                            Text(format.dpi)
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.1))
                
                // Paleta de cores
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paleta de cores")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.primary)
                    
                    HStack(spacing: 8) {
                        colorCircle(recommendation.colorPalette.primary, label: "Primária")
                        colorCircle(recommendation.colorPalette.secondary, label: "Secundária")
                        colorCircle(recommendation.colorPalette.accent, label: "Acentuada")
                        colorCircle(recommendation.colorPalette.background, label: "Fundo")
                    }
                    
                    Text(recommendation.colorPalette.rationale)
                        .font(.caption2)
                        .foregroundStyle(PsyTheme.textSecondary)
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.1))
                
                // Composição
                VStack(alignment: .leading, spacing: 8) {
                    Text("Composição sugerida")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.primary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        bulletPoint("Layout: \(recommendation.composition.layout)")
                        bulletPoint("Elemento principal: \(recommendation.composition.mainElement)")
                        bulletPoint("Tipografia: \(recommendation.composition.tipography)")
                        bulletPoint(recommendation.composition.safeZones)
                    }
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.1))
                
                // Motivos visuais
                VStack(alignment: .leading, spacing: 8) {
                    Text("Elementos visuais")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.primary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(recommendation.visualMotifs, id: \.self) { motif in
                            bulletPoint(motif)
                        }
                    }
                }
                
                Divider()
                    .overlay(Color.white.opacity(0.1))
                
                // Notas de design
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dicas específicas")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.primary)
                    Text(recommendation.designNotes)
                        .font(.caption2)
                        .foregroundStyle(PsyTheme.textSecondary)
                        .lineLimit(nil)
                }
            }
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(PsyTheme.primary)
            Text(text)
                .font(.caption)
                .foregroundStyle(PsyTheme.textSecondary)
            Spacer()
        }
    }
    
    private func colorCircle(_ hexColor: String, label: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color(hex: hexColor) ?? .gray)
                .frame(width: 40, height: 40)
                .border(Color.white.opacity(0.2), width: 1)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(PsyTheme.textSecondary)
        }
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
