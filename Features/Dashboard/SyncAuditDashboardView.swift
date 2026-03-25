import SwiftUI
import SwiftData

/// Audit Dashboard - Shows sync operations history, conflicts, and statistics
struct SyncAuditDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var refreshing = false
    @State private var selectedTab: AuditTab = .stats
    @State private var filterEntityType: String? = nil
    
    @Query(sort: \SyncAuditLog.timestamp, order: .reverse) private var auditLogs: [SyncAuditLog]
    @Query(predicate: #Predicate<SyncConflict> { $0.status == "pending" }) private var pendingConflicts: [SyncConflict]
    
    enum AuditTab {
        case stats
        case history
        case conflicts
        case settings
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sync Audit")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Operações e status de sincronização")
                                .font(.footnote)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(PsyTheme.primary)
                    }
                }
                .padding(20)
                .background(PsyTheme.surface)
                
                // Tab Selection
                HStack(spacing: 0) {
                    ForEach([AuditTab.stats, .history, .conflicts, .settings], id: \.self) { tab in
                        Button(action: { selectedTab = tab }) {
                            VStack(spacing: 6) {
                                Image(systemName: tabIcon(tab))
                                    .font(.system(size: 16, weight: .semibold))
                                Text(tabLabel(tab))
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(selectedTab == tab ? .white : PsyTheme.textSecondary)
                            .background(selectedTab == tab ? PsyTheme.primary.opacity(0.2) : .clear)
                        }
                        .buttonStyle(.plain)
                        
                        if tab != .settings {
                            Divider()
                                .frame(height: 20)
                        }
                    }
                }
                .background(PsyTheme.surfaceAlt)
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selectedTab {
                        case .stats:
                            statsView
                        case .history:
                            historyView
                        case .conflicts:
                            conflictsView
                        case .settings:
                            settingsView
                        }
                    }
                    .padding(20)
                }
                
                Spacer()
            }
            .background(PsyTheme.background.ignoresSafeArea())
            .navigationTitle("Auditoria de Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(refreshing ? PsyTheme.primary.opacity(0.5) : PsyTheme.primary)
                            .rotationEffect(.degrees(refreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: refreshing)
                    }
                    .disabled(refreshing)
                }
            }
        }
    }
    
    // MARK: - Tab Views
    
    private var statsView: some View {
        let stats = SyncAuditService.getSyncStats(modelContext: modelContext)
        
        return VStack(alignment: .leading, spacing: 16) {
            PsySectionHeader(eyebrow: "Estatísticas", title: "Status Geral")
            
            // Success Rate Card
            PsyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Taxa de Sucesso")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(String(format: "%.1f", stats.successRate))%")
                            .font(.headline)
                            .foregroundStyle(stats.successRate >= 95 ? .green : stats.successRate >= 85 ? .yellow : .red)
                    }
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(PsyTheme.surfaceAlt)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(stats.successRate >= 95 ? Color.green : stats.successRate >= 85 ? Color.yellow : Color.red)
                                .frame(width: geo.size.width * (stats.successRate / 100))
                        }
                    }
                    .frame(height: 6)
                }
            }
            
            // Stats Grid
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    StatCard(
                        label: "Total Ops",
                        value: "\(stats.totalOperations)",
                        icon: "square.stack.fill"
                    )
                    StatCard(
                        label: "Falhadas",
                        value: "\(stats.failedOperations)",
                        icon: "xmark.circle.fill",
                        valueColor: stats.failedOperations > 0 ? .red : .green
                    )
                    StatCard(
                        label: "Conflitos",
                        value: "\(stats.pendingConflicts)",
                        icon: "exclamationmark.triangle.fill",
                        valueColor: stats.pendingConflicts > 0 ? .yellow : .green
                    )
                }
                
                HStack(spacing: 12) {
                    StatCard(
                        label: "Tempo Médio",
                        value: "\(stats.averageSyncDurationMs)ms",
                        icon: "timer.fill"
                    )
                    StatCard(
                        label: "Dados TX",
                        value: formatBytes(stats.totalDataTransferredBytes),
                        icon: "arrow.up.arrow.down.circle.fill"
                    )
                }
            }
        }
    }
    
    private var historyView: some View {
        VStack(alignment: .leading, spacing: 16) {
            PsySectionHeader(eyebrow: "Histórico", title: "Operações Recentes")
            
            if auditLogs.isEmpty {
                PsyCard {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(PsyTheme.primary)
                        Text("Nenhuma operação registrada")
                            .font(.subheadline)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(auditLogs.prefix(15)) { log in
                        auditLogRow(log)
                    }
                }
            }
        }
    }
    
    private var conflictsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            PsySectionHeader(eyebrow: "Conflitos", title: "Pendentes de Resolução")
            
            if pendingConflicts.isEmpty {
                PsyCard {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                        Text("Nenhum conflito pendente")
                            .font(.subheadline)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(pendingConflicts) { conflict in
                        conflictCard(conflict)
                    }
                }
            }
        }
    }
    
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            PsySectionHeader(eyebrow: "Configurações", title: "Auditoria & Limpeza")
            
            VStack(spacing: 12) {
                Button(action: cleanupOldLogs) {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Limpar Logs Antigos")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Text("Remove logs com mais de 90 dias")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                    .padding(12)
                    .background(PsyTheme.surfaceAlt.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                Button(action: exportAuditTrail) {
                    HStack {
                        Image(systemName: "arrow.up.doc.fill")
                            .foregroundStyle(PsyTheme.primary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exportar Auditoria")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                            Text("CSV com todas as operações")
                                .font(.caption)
                                .foregroundStyle(PsyTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                    .padding(12)
                    .background(PsyTheme.surfaceAlt.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func auditLogRow(_ log: SyncAuditLog) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: operationIcon(log.operationType))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(operationColor(log.operationType))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.entityType)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(log.changesSummary)
                        .font(.caption)
                        .foregroundStyle(PsyTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(log.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(PsyTheme.textSecondary)
                    if let duration = log.syncDurationMs {
                        Text("\(duration)ms")
                            .font(.caption2)
                            .foregroundStyle(PsyTheme.textSecondary)
                    }
                }
            }
            
            if let error = log.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(12)
        .background(PsyTheme.surfaceAlt.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func conflictCard(_ conflict: SyncConflict) -> some View {
        let summary = ConflictResolutionService.getSummary(for: conflict)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                Text(summary.entityTypeReadable)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text(conflict.detectedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(PsyTheme.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Local: " + summary.localChanges)
                    .font(.caption)
                    .foregroundStyle(PsyTheme.textSecondary)
                Text("Remoto: " + summary.remoteChanges)
                    .font(.caption)
                    .foregroundStyle(PsyTheme.textSecondary)
            }
            
            HStack(spacing: 8) {
                Button(action: {
                    _ = ConflictResolutionService.resolveWithLocalStrategy(conflict: conflict, modelContext: modelContext)
                }) {
                    Text("Usar Local")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(PsyTheme.primary.opacity(0.2))
                        .foregroundStyle(PsyTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    _ = ConflictResolutionService.resolveWithRemoteStrategy(conflict: conflict, modelContext: modelContext)
                }) {
                    Text("Usar Remoto")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(PsyTheme.primary.opacity(0.2))
                        .foregroundStyle(PsyTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(PsyTheme.surfaceAlt.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func operationIcon(_ type: String) -> String {
        switch type {
        case "push": return "arrow.up.circle.fill"
        case "pull": return "arrow.down.circle.fill"
        case "merge": return "arrow.2.squarepath"
        case "delete": return "trash.fill"
        case "create": return "plus.circle.fill"
        default: return "questionmark.circle"
        }
    }
    
    private func operationColor(_ type: String) -> Color {
        switch type {
        case "push": return .green
        case "pull": return .blue
        case "merge": return PsyTheme.primary
        case "delete": return .red
        case "create": return .green
        default: return .gray
        }
    }
    
    private func tabLabel(_ tab: AuditTab) -> String {
        switch tab {
        case .stats: return "Stats"
        case .history: return "Histórico"
        case .conflicts: return "Conflitos"
        case .settings: return "Config"
        }
    }
    
    private func tabIcon(_ tab: AuditTab) -> String {
        switch tab {
        case .stats: return "chart.bar.fill"
        case .history: return "list.bullet"
        case .conflicts: return "exclamationmark.bubble.fill"
        case .settings: return "gear"
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // MARK: - Actions
    
    private func refresh() {
        refreshing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            refreshing = false
        }
    }
    
    private func cleanupOldLogs() {
        SyncAuditService.cleanupOldLogs(olderThanDays: 90, modelContext: modelContext)
    }
    
    private func exportAuditTrail() {
        // TODO: Generate CSV and share
        print("TODO: Export audit trail to CSV")
    }
}

// MARK: - Stat Card Component

private struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    var valueColor: Color = PsyTheme.primary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(valueColor)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(PsyTheme.textSecondary)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(valueColor)
        }
        .padding(12)
        .background(PsyTheme.surfaceAlt.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    SyncAuditDashboardView()
        .modelContainer(try! ModelContainer(for: SyncAuditLog.self, SyncConflict.self))
}
