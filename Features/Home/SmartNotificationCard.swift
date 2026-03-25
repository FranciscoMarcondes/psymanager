import SwiftUI

struct SmartNotificationCard: View {
    @State private var isLoading = false
    @State private var shouldDismiss = false
    
    let notification: SmartNotificationModel
    let onDismiss: () -> Void
    let onNavigate: (UUID) -> Void
    
    var body: some View {
        if !shouldDismiss {
            Button {
                onNavigate(notification.activityId)
            } label: {
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
            .buttonStyle(.plain)
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
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

#Preview {
    SmartNotificationCard(
        notification: .init(
            activityId: UUID(),
            title: "Show confirmado",
            description: "Seu show em São Paulo foi confirmado.",
            type: .success
        ),
        onDismiss: {},
        onNavigate: { _ in }
    )
    .padding()
}
