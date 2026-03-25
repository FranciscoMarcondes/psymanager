import SwiftUI
import SwiftData

/// Inline quick action buttons extracted from AI suggestions
/// Shows top 5 actions with 1-tap execution
struct QuickActionsButtonRow: View {
    @Environment(\.modelContext) private var modelContext
    let suggestions: [QuickActionService.QuickAction]
    let onActionExecuted: (String) -> Void
    
    @State private var executedActionId: String?
    @State private var executionFeedback = ""
    @State private var showCompletionBadge = false
    
    var body: some View {
        if suggestions.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Ações rápidas")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(PsyTheme.textSecondary)
                    .padding(.horizontal, 2)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, suggestion in
                            QuickActionButton(
                                action: suggestion,
                                isExecuted: executedActionId == suggestion.type.rawValue,
                                onExecute: { executeAction(suggestion) }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                if showCompletionBadge {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(executionFeedback)
                            .font(.caption)
                            .foregroundStyle(PsyTheme.textSecondary)
                        Spacer()
                    }
                    .padding(8)
                    .background(PsyTheme.surfaceAlt.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(PsyTheme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    
    private func executeAction(_ action: QuickActionService.QuickAction) {
        executedActionId = action.type.rawValue
        HapticFeedbackService.tapAction() // Haptic feedback on tap
        
        // Execute based on action type
        switch action.type {
        case .createContent:
            let title = action.extractedData["content_type"] ?? action.title
            QuickActionService.quickSaveContent(
                title: title,
                objective: action.extractedData["action_type"],
                contentType: "Social Post",
                modelContext: modelContext
            )
            executionFeedback = "Adicionado ao rascunho"
            
        case .addTask:
            let title = action.extractedData["source_text"] ?? action.title
            QuickActionService.quickSaveTask(
                title: title,
                description: "Sugestão do Manager IA",
                modelContext: modelContext
            )
            executionFeedback = "Tarefa criada"
            
        case .followUpLead:
            QuickActionService.quickSaveLeadFollowUp(
                leadName: action.extractedData["lead_name"] ?? "Unknown",
                actionType: action.extractedData["method"] ?? "call",
                modelContext: modelContext
            )
            executionFeedback = "Follow-up agendado"
            
        case .captureInsight:
            let insight = action.extractedData["source_text"] ?? action.title
            QuickActionService.quickSaveContent(
                title: "Insight: \(insight)",
                objective: "Preservar aprendizado",
                contentType: "Insight",
                modelContext: modelContext
            )
            executionFeedback = "Insight guardado"
            
        default:
            executionFeedback = "\(action.type.displayName) iniciado"
        }
        
        showCompletionBadge = true
        HapticFeedbackService.savedSuccessfully() // Success haptic
        onActionExecuted(action.type.rawValue)
        
        // Auto-hide feedback after 2s
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCompletionBadge = false
                executedActionId = nil
            }
        }
    }
}

/// Individual quick action button
private struct QuickActionButton: View {
    let action: QuickActionService.QuickAction
    let isExecuted: Bool
    let onExecute: () -> Void
    
    var body: some View {
        Button(action: onExecute) {
            VStack(alignment: .center, spacing: 4) {
                Image(systemName: action.type.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isExecuted ? .green : PsyTheme.primary)
                
                Text(action.type.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
            }
            .frame(width: 70, height: 70)
            .background(
                Group {
                    if isExecuted {
                        PsyTheme.primary.opacity(0.2)
                    } else if action.isHighPriority {
                        PsyTheme.primary.opacity(0.15)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(PsyTheme.primary.opacity(0.4), lineWidth: 1.5)
                            )
                    } else {
                        PsyTheme.surfaceAlt
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                Group {
                    if isExecuted {
                        Image(systemName: "checkmark")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }
            )
            .scaleEffect(isExecuted ? 0.95 : 1.0)
            .sensoryFeedback(.selection, trigger: isExecuted)
        }
        .disabled(isExecuted)
    }
}

#Preview {
    VStack {
        QuickActionsButtonRow(
            suggestions: [
                QuickActionService.QuickAction(
                    type: .createContent,
                    title: "Criar Conteúdo",
                    subtitle: "Post sobre última apresentação",
                    extractedData: [:],
                    priority: 5
                ),
                QuickActionService.QuickAction(
                    type: .followUpLead,
                    title: "Seguir Lead",
                    subtitle: "Contatar promoter do Rio",
                    extractedData: ["method": "call"],
                    priority: 4
                ),
                QuickActionService.QuickAction(
                    type: .addTask,
                    title: "Adicionar Tarefa",
                    subtitle: "Revisar contrato",
                    extractedData: [:],
                    priority: 3
                )
            ],
            onActionExecuted: { _ in }
        )
        .padding()
        .background(PsyTheme.background)
    }
}
