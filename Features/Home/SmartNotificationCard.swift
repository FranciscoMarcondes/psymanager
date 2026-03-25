import SwiftUI

struct SmartNotificationCard: View {
    @State private var isLoading = false
    @State private var shouldDismiss = false
    
    let notification: SmartNotificationModel
    let onDismiss: () -> Void
    let onNavigate: (UUID) -> Void
    
    var body: some View {
        if !shouldDismiss {
            NavigationLink(destination: ActivityDetailView(activityId: notification.activityId)) {
                HStack(spacing: 12) {
                    Image(systemName: notificationIcon)
                        .font(.headline)
                        .foregroundStyle(notificationColor)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        Text(notification.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Button(action: dismissNotification) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(notificationColor.opacity(0.3), lineWidth: 1)
                )
            }
            .onReceive(Timer.publish(every: 30).autoconnect()) { _ in
                refreshNotification()
            }
        }
    }
    
    private func dismissNotification() {
        shouldDismiss = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
    
    private func refreshNotification() {
        isLoading = true
        Task {
            // Simular refresh - pode conectar com backend
            try? await Task.sleep(nanoseconds: 500_000_000)
            isLoading = false
        }
    }
    
    private var notificationIcon: String {
        switch notification.type {
        case .alert: return "exclamationmark.circle.fill"
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "triangle.fill"
        }
    }
    
    private var notificationColor: Color {
        switch notification.type {
        case .alert: return .red
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        }
    }
}

struct SmartNotificationModel: Identifiable {
    let id: UUID
    let activityId: UUID
    let title: String
    let description: String
    let type: NotificationType
    let createdAt: Date
    
    enum NotificationType {
        case alert, info, success, warning
    }
}

struct ActivityDetailView: View {
    let activityId: UUID
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Voltar")
                    }
                }
                Spacer()
            }
            .padding()
            
            Text("Atividade #\(activityId)")
                .font(.headline)
            
            Spacer()
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    SmartNotificationCard(
        notification: .init(
            id: UUID(),
            activityId: UUID(),
            title: "Show confirmado",
            description: "Seu show em São Paulo foi confirmado.",
            type: .success,
            createdAt: Date()
        ),
        onDismiss: {},
        onNavigate: { _ in }
    )
    .padding()
}
