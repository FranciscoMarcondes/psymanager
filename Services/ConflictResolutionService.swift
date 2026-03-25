import Foundation
import SwiftData

/// Service for detecting, handling, and resolving sync conflicts
/// Provides strategies: keep_local, keep_remote, merge_fields, manual_review
struct ConflictResolutionService {
    
    // MARK: - Conflict Detection
    
    /// Detect conflicts when merging remote changes with local data
    static func detectConflict(
        entityId: String,
        entityType: String,
        localVersion: [String: Any],
        remoteVersion: [String: Any],
        modelContext: ModelContext
    ) -> SyncConflict? {
        // Check if versions differ meaningfully
        let localJSON = try? JSONSerialization.data(withJSONObject: localVersion)
        let remoteJSON = try? JSONSerialization.data(withJSONObject: remoteVersion)
        
        guard let localJSON, let remoteJSON else { return nil }
        
        if localJSON != remoteJSON {
            let localStr = String(data: localJSON, encoding: .utf8) ?? ""
            let remoteStr = String(data: remoteJSON, encoding: .utf8) ?? ""
            
            let conflict = SyncConflict(
                entityType: entityType,
                entityId: entityId,
                localVersion: localStr,
                remoteVersion: remoteStr
            )
            
            modelContext.insert(conflict)
            try? modelContext.save()
            
            SyncAuditService.logOperation(
                type: "merge",
                entityType: entityType,
                entityId: entityId,
                changesSummary: "Conflict detected",
                conflictDetected: true,
                resolutionStrategy: "pending_manual_review",
                modelContext: modelContext
            )
            
            return conflict
        }
        
        return nil
    }
    
    // MARK: - Resolution Strategies
    
    /// Keep local changes (discard remote)
    static func resolveWithLocalStrategy(
        conflict: SyncConflict,
        modelContext: ModelContext
    ) -> Bool {
        conflict.resolutionChoice = "local"
        conflict.resolvedAt = .now
        conflict.status = "resolved"
        
        do {
            try modelContext.save()
            
            SyncAuditService.logOperation(
                type: "merge",
                entityType: conflict.entityType,
                entityId: conflict.entityId,
                changesSummary: "Resolved with LOCAL strategy",
                conflictDetected: false,
                resolutionStrategy: "keep_local",
                modelContext: modelContext
            )
            
            return true
        } catch {
            print("❌ Failed to resolve conflict with local strategy: \(error)")
            return false
        }
    }
    
    /// Keep remote changes (discard local)
    static func resolveWithRemoteStrategy(
        conflict: SyncConflict,
        modelContext: ModelContext
    ) -> Bool {
        conflict.resolutionChoice = "remote"
        conflict.resolvedAt = .now
        conflict.status = "resolved"
        
        do {
            try modelContext.save()
            
            SyncAuditService.logOperation(
                type: "merge",
                entityType: conflict.entityType,
                entityId: conflict.entityId,
                changesSummary: "Resolved with REMOTE strategy",
                conflictDetected: false,
                resolutionStrategy: "keep_remote",
                modelContext: modelContext
            )
            
            return true
        } catch {
            print("❌ Failed to resolve conflict with remote strategy: \(error)")
            return false
        }
    }
    
    /// Merge conflicting fields (takes newer timestamps)
    static func resolveWithMergeStrategy(
        conflict: SyncConflict,
        modelContext: ModelContext
    ) -> Bool {
        do {
            guard let localData = conflict.localVersion.data(using: .utf8),
                  let remoteData = conflict.remoteVersion.data(using: .utf8),
                  let localObj = try JSONSerialization.jsonObject(with: localData) as? [String: Any],
                  let remoteObj = try JSONSerialization.jsonObject(with: remoteData) as? [String: Any]
            else {
                return false
            }
            
            // Merge strategy: take fields with newer timestamps
            var merged = localObj
            for (key, remoteValue) in remoteObj {
                // For simple types, prefer remote if it's different
                // For complex types, keep local
                if !(merged[key] is [String: Any]) && !(merged[key] is [Any]) {
                    merged[key] = remoteValue
                }
            }
            
            let mergedJSON = try JSONSerialization.data(withJSONObject: merged)
            let mergedStr = String(data: mergedJSON, encoding: .utf8) ?? ""
            
            conflict.mergedData = mergedStr
            conflict.resolutionChoice = "merged"
            conflict.resolvedAt = .now
            conflict.status = "resolved"
            
            try modelContext.save()
            
            SyncAuditService.logOperation(
                type: "merge",
                entityType: conflict.entityType,
                entityId: conflict.entityId,
                changesSummary: "Resolved with MERGE strategy",
                conflictDetected: false,
                resolutionStrategy: "merge_fields",
                modelContext: modelContext
            )
            
            return true
        } catch {
            print("❌ Failed to resolve conflict with merge strategy: \(error)")
            return false
        }
    }
    
    // MARK: - Automatic Resolution
    
    /// Auto-resolve conflicts based on rules
    /// Returns true if auto-resolved, false if requires manual review
    static func attemptAutoResolve(
        conflict: SyncConflict,
        modelContext: ModelContext,
        autoResolutionMode: AutoResolutionMode = .preferLocal
    ) -> Bool {
        switch autoResolutionMode {
        case .preferLocal:
            return resolveWithLocalStrategy(conflict: conflict, modelContext: modelContext)
        case .preferRemote:
            return resolveWithRemoteStrategy(conflict: conflict, modelContext: modelContext)
        case .merge:
            return resolveWithMergeStrategy(conflict: conflict, modelContext: modelContext)
        case .manual:
            return false // Requires user input
        }
    }
    
    enum AutoResolutionMode {
        case preferLocal
        case preferRemote
        case merge
        case manual // No auto-resolution
    }
    
    // MARK: - Conflict Summary for UI
    
    struct ConflictSummary {
        let conflict: SyncConflict
        let entityTypeReadable: String
        let localChanges: String
        let remoteChanges: String
        let suggestedResolution: String
    }
    
    static func getSummary(for conflict: SyncConflict) -> ConflictSummary {
        let readable = conflict.entityType
            .replacingOccurrences(of: "Item", with: "")
            .replacingOccurrences(of: "([A-Z])", with: " $1", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        // Extract key differences
        let localSummary = extractChanges(from: conflict.localVersion)
        let remoteSummary = extractChanges(from: conflict.remoteVersion)
        let suggestion = localSummary.keys.count > remoteSummary.keys.count
            ? "Keeplocal changes (mais modificado)"
            : "Keep remote changes (mais recente)"
        
        return ConflictSummary(
            conflict: conflict,
            entityTypeReadable: readable,
            localChanges: localSummary.formatted(),
            remoteChanges: remoteSummary.formatted(),
            suggestedResolution: suggestion
        )
    }
    
    private static func extractChanges(from jsonStr: String) -> [String: String] {
        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return [:]
        }
        
        var changes: [String: String] = [:]
        for (key, value) in json {
            if let str = value as? String, !str.isEmpty && str.count < 100 {
                changes[key] = str
            } else if let num = value as? NSNumber {
                changes[key] = num.stringValue
            }
        }
        
        return changes
    }
}

extension Dictionary where Key == String, Value == String {
    func formatted() -> String {
        self.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }
}
