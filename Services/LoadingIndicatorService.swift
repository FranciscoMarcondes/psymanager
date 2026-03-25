import SwiftUI
import Combine

/// Centralized loading state management with progress simulation
/// Provides consistent visual feedback across the app
@MainActor
final class LoadingIndicatorService: ObservableObject {
    @Published var isLoading = false
    @Published var progress: Double = 0.0
    @Published var message: String = ""
    @Published var stage: LoadingStage = .startup
    
    private var progressTimer: Timer?
    private var lastProgress: Double = 0.0
    
    enum LoadingStage {
        case startup
        case analyzing
        case processing
        case syncing
        case completing
        case done
        
        var description: String {
            switch self {
            case .startup: return "Inicializando..."
            case .analyzing: return "Analisando..."
            case .processing: return "Processando..."
            case .syncing: return "Sincronizando..."
            case .completing: return "Finalizando..."
            case .done: return "Concluído"
            }
        }
    }
    
    func startLoading(message: String = "Carregando...", stage: LoadingStage = .startup) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = true
            self?.message = message
            self?.stage = stage
            self?.progress = 0.0
            self?.lastProgress = 0.0
            self?.simulateProgress()
        }
    }
    
    func updateProgress(to value: Double, message: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.progress = min(value, 0.99) // Never reach 100% until done
            if let msg = message {
                self?.message = msg
            }
        }
    }
    
    func updateStage(_ stage: LoadingStage, message: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?.stage = stage
            if let msg = message {
                self?.message = msg
            }
        }
    }
    
    func finishLoading(message: String? = nil) {
        progressTimer?.invalidate()
        progressTimer = nil
        DispatchQueue.main.async { [weak self] in
            self?.progress = 1.0
            self?.stage = .done
            if let msg = message {
                self?.message = msg
            }
            
            // Auto-hide after 0.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isLoading = false
            }
        }
    }
    
    private func simulateProgress() {
        progressTimer?.invalidate()
        
        // Simulate progress with diminishing increments
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let increment = (1.0 - self.progress) * 0.1 // Slow down as we approach 1
            self.progress = min(self.progress + increment, 0.95)
            
            // Vary message based on progress
            if self.progress > 0.7, self.stage == .analyzing {
                self.updateStage(.processing)
            }
        }
    }
    
    func reset() {
        progressTimer?.invalidate()
        progressTimer = nil
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.progress = 0.0
            self?.message = ""
            self?.stage = .startup
        }
    }
}

/// Reusable loading overlay view
struct LoadingOverlay: View {
    @ObservedObject var service: LoadingIndicatorService
    var animationDuration: Double = 0.3
    
    var body: some View {
        if service.isLoading {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                // Loading content
                VStack(spacing: 24) {
                    // Progress circle with animated ring
                    ZStack {
                        Circle()
                            .stroke(PsyTheme.surfaceAlt, lineWidth: 8)
                        
                        Circle()
                            .trim(from: 0, to: service.progress)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        PsyTheme.primary,
                                        PsyTheme.primary.opacity(0.6)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 4) {
                            Text("\(Int(service.progress * 100))%")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(service.stage.description)
                                .font(.caption2)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    .frame(width: 120, height: 120)
                    .animation(.linear(duration: 0.1), value: service.progress)
                    
                    // Message
                    VStack(spacing: 8) {
                        Text(service.message)
                            .font(.headline)
                            .foregroundStyle(.white)
                        
                        // Sub-message with spinner
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(PsyTheme.primary)
                                .scaleEffect(0.8)
                            Text("Processando...")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(32)
                .background(PsyTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
            .animation(.easeInOut(duration: animationDuration), value: service.isLoading)
        }
    }
}

/// Minimal loading indicator (for inline use)
struct MinimalLoadingIndicator: View {
    @ObservedObject var service: LoadingIndicatorService
    
    var body: some View {
        if service.isLoading {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(PsyTheme.primary)
                    .controlSize(.small)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.message)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Text("\(Int(service.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                }
                
                Spacer()
                
                // Progress dot animation
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { idx in
                        Circle()
                            .fill(PsyTheme.primary.opacity(Double(idx) * 0.3 + 0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(service.isLoading ? 1.0 : 0.8)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .delay(Double(idx) * 0.15)
                                    .repeatForever(autoreverses: true),
                                value: service.isLoading
                            )
                    }
                }
                .frame(width: 28)
            }
            .padding(12)
            .background(PsyTheme.surfaceAlt.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

// MARK: - Preview & Example Usage

#if DEBUG
struct LoadingIndicatorService_Previews: PreviewProvider {
    static var previews: some View {
        let service = LoadingIndicatorService()
        
        ZStack {
            PsyTheme.background.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Button("Show Loading") {
                    service.startLoading(message: "Carregando dados...")
                }
                
                Button("Update Progress") {
                    service.updateProgress(to: 0.5, message: "Processando...")
                }
                
                Button("Finish") {
                    service.finishLoading(message: "Concluído!")
                }
                
                Spacer()
            }
            .padding()
            
            LoadingOverlay(service: service)
        }
    }
}
#endif
