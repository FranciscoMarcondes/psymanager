import Foundation
import SwiftData

/// Service for logging and tracking all sync operations
/// Provides audit trail, performance metrics, and conflict detection
struct SyncAuditService {
    
    // MARK: - Audit Recording
    
    /// Log a sync operation
    static func logOperation(
        type: String, // "push", "pull", "merge", "delete", "create"
        entityType: String,
        entityId: String,
        changesSummary: String = "",
        conflictDetected: Bool = false,
        resolutionStrategy: String? = nil,
        statusCode: Int? = nil,
        errorMessage: String? = nil,
        syncDurationMs: Int? = nil,
        dataSize: Int? = nil,
        modelContext: ModelContext
    ) {
        let log = SyncAuditLog(
            operationType: type,
            entityType: entityType,
            entityId: entityId,
            changesSummary: changesSummary,
            conflictDetected: conflictDetected,
            resolutionStrategy: resolutionStrategy,
            statusCode: statusCode,
            errorMessage: errorMessage,
            syncDurationMs: syncDurationMs,
            dataSize: dataSize
        )
        
        modelContext.insert(log)
        try? modelContext.save()
    }
    
    // MARK: - Version Creation
    
    /// Create a version snapshot of a content item
    static func createVersion(
        for item: SocialContentPlanItem,
        versionNumber: Int,
        createdBy: String,
        changeDescription: String,
        modelContext: ModelContext
    ) {
        let version = ContentItemVersion(
            itemId: item.id?.uuidString ?? UUID().uuidString,
            versionNumber: versionNumber,
            createdBy: createdBy,
            changeDescription: changeDescription,
            title: item.title,
            contentType: item.contentType,
            objective: item.objective,
            status: item.status,
            pillar: item.pillar,
            hook: item.hook,
            caption: item.caption,
            cta: item.cta,
            hashtags: item.hashtags,
            notes: item.notes,
            scheduledDate: item.scheduledDate
        )
        
        modelContext.insert(version)
        try? modelContext.save()
    }
    
    // MARK: - Audit Query
    
    /// Get audit logs for an entity
    static func getAuditTrail(
        for entityId: String,
        entityType: String,
        modelContext: ModelContext,
        limit: Int = 50
    ) -> [SyncAuditLog] {
        let descriptor = FetchDescriptor<SyncAuditLog>(
            predicate: #Predicate { log in
                log.entityId == entityId && log.entityType == entityType
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            let logs = try modelContext.fetch(descriptor)
            return Array(logs.prefix(limit))
        } catch {
            print("❌ Failed to fetch audit trail: \(error)")
            return []
        }
    }
    
    /// Get recent sync operations (last N hours)
    static func getRecentOperations(
        hoursBack: Int = 24,
        modelContext: ModelContext
    ) -> [SyncAuditLog] {
        let cutoffDate = Date().addingTimeInterval(-Double(hoursBack * 3600))
        
        let descriptor = FetchDescriptor<SyncAuditLog>(
            predicate: #Predicate { log in
                log.timestamp >= cutoffDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch recent operations: \(error)")
            return []
        }
    }
    
    /// Get failed sync operations
    static func getFailedOperations(
        modelContext: ModelContext
    ) -> [SyncAuditLog] {
        let descriptor = FetchDescriptor<SyncAuditLog>(
            predicate: #Predicate { log in
                log.errorMessage != nil
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch failed operations: \(error)")
            return []
        }
    }
    
    /// Get conflicts requiring resolution
    static func getPendingConflicts(
        modelContext: ModelContext
    ) -> [SyncConflict] {
        let descriptor = FetchDescriptor<SyncConflict>(
            predicate: #Predicate { conflict in
                conflict.status == "pending"
            },
            sortBy: [SortDescriptor(\.detectedAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ Failed to fetch pending conflicts: \(error)")
            return []
        }
    }
    
    // MARK: - Statistics
    
    /// Get sync statistics for dashboard/debug view
    static func getSyncStats(modelContext: ModelContext) -> SyncStatistics {
        let allLogs = (try? modelContext.fetch(FetchDescriptor<SyncAuditLog>())) ?? []
        let conflicts = (try? modelContext.fetch(FetchDescriptor<SyncConflict>())) ?? []
        
        let totalOperations = allLogs.count
        let failedOperations = allLogs.filter { $0.errorMessage != nil }.count
        let conflictOps = allLogs.filter { $0.conflictDetected }.count
        let pendingConflicts = conflicts.filter { $0.status == "pending" }.count
        
        let avgDuration = allLogs.compactMap { $0.syncDurationMs }.isEmpty
            ? 0
            : allLogs.compactMap { $0.syncDurationMs }.reduce(0, +) / allLogs.compactMap { $0.syncDurationMs }.count
        
        let totalDataTransferred = allLogs.compactMap { $0.dataSize }.reduce(0, +)
        
        return SyncStatistics(
            totalOperations: totalOperations,
            failedOperations: failedOperations,
            conflictOpsCount: conflictOps,
            pendingConflicts: pendingConflicts,
            averageSyncDurationMs: avgDuration,
            totalDataTransferredBytes: totalDataTransferred,
            successRate: totalOperations > 0 ? Double(totalOperations - failedOperations) / Double(totalOperations) * 100 : 100
        )
    }
    
    struct SyncStatistics {
        let totalOperations: Int
        let failedOperations: Int
        let conflictOpsCount: Int
        let pendingConflicts: Int
        let averageSyncDurationMs: Int
        let totalDataTransferredBytes: Int
        let successRate: Double // 0-100
    }
    
    // MARK: - Cleanup
    
    /// Archive old audit logs (older than N days)
    static func cleanupOldLogs(
        olderThanDays: Int = 90,
        modelContext: ModelContext
    ) {
        let cutoffDate = Date().addingTimeInterval(-Double(olderThanDays * 86400))
        
        let descriptor = FetchDescriptor<SyncAuditLog>(
            predicate: #Predicate { log in
                log.timestamp < cutoffDate
            }
        )
        
        do {
            let oldLogs = try modelContext.fetch(descriptor)
            for log in oldLogs {
                modelContext.delete(log)
            }
            try modelContext.save()
            print("✅ Cleaned up \(oldLogs.count) old audit logs")
        } catch {
            print("❌ Failed to cleanup old logs: \(error)")
        }
    }
}
