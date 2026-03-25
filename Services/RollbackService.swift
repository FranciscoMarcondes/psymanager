import Foundation
import SwiftData

/// Service for rolling back changes within a time window
/// Enables "undo" functionality for recently modified items
struct RollbackService {
    
    private static let ROLLBACK_WINDOW_SECONDS: TimeInterval = 5 * 60 // 5 minutes
    
    // MARK: - Rollback Queries
    
    /// Check if an item can be rolled back
    static func canRollback(
        itemId: String,
        modelContext: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<ContentItemVersion>(
            predicate: #Predicate { version in
                version.itemId == itemId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let versions = try modelContext.fetch(descriptor)
            guard versions.count > 1 else { return false }
            
            // Check if latest version is within rollback window
            let latestVersion = versions[0]
            let timeSinceChange = Date().timeIntervalSince(latestVersion.createdAt)
            return timeSinceChange <= ROLLBACK_WINDOW_SECONDS
        } catch {
            print("❌ Failed to check rollback availability: \(error)")
            return false
        }
    }
    
    /// Get available rollback points (versions within rollback window)
    static func getRollbackPoints(
        for itemId: String,
        modelContext: ModelContext
    ) -> [ContentItemVersion] {
        let descriptor = FetchDescriptor<ContentItemVersion>(
            predicate: #Predicate { version in
                version.itemId == itemId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let versions = try modelContext.fetch(descriptor)
            let now = Date()
            
            // Return versions within rollback window, excluding the current one if there's a previous
            return versions.filter { version in
                now.timeIntervalSince(version.createdAt) <= ROLLBACK_WINDOW_SECONDS
            }
        } catch {
            print("❌ Failed to fetch rollback points: \(error)")
            return []
        }
    }
    
    /// Get version history (not limited by time window)
    static func getVersionHistory(
        for itemId: String,
        modelContext: ModelContext,
        limit: Int = 20
    ) -> [ContentItemVersion] {
        let descriptor = FetchDescriptor<ContentItemVersion>(
            predicate: #Predicate { version in
                version.itemId == itemId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let versions = try modelContext.fetch(descriptor)
            return Array(versions.prefix(limit))
        } catch {
            print("❌ Failed to fetch version history: \(error)")
            return []
        }
    }
    
    // MARK: - Rollback Execution
    
    /// Rollback to a previous version
    static func rollbackToVersion(
        itemId: String,
        toVersion targetVersion: ContentItemVersion,
        reason: String = "Manual rollback",
        modelContext: ModelContext
    ) -> Bool {
        // Find the current item by persistent identifier string
        let descriptor = FetchDescriptor<SocialContentPlanItem>()
        
        do {
            let items = try modelContext.fetch(descriptor)
            guard let currentItem = items.first(where: { String(describing: $0.persistentModelID) == itemId }) else {
                print("❌ Item not found for rollback: \(itemId)")
                return false
            }
            
            // Store changes as audit
            let changesSummary = """
            Rolled back from version \(getCurrentVersionNumber(itemId: itemId, modelContext: modelContext))
            - Title: \(currentItem.title) → \(targetVersion.title)
            - Status: \(currentItem.status) → \(targetVersion.status)
            - Content: \(currentItem.caption.prefix(50))... → \(targetVersion.caption.prefix(50))...
            Reason: \(reason)
            """
            
            // Apply rollback
            currentItem.title = targetVersion.title
            currentItem.contentType = targetVersion.contentType
            currentItem.objective = targetVersion.objective
            currentItem.status = targetVersion.status
            currentItem.pillar = targetVersion.pillar
            currentItem.hook = targetVersion.hook
            currentItem.caption = targetVersion.caption
            currentItem.cta = targetVersion.cta
            currentItem.hashtags = targetVersion.hashtags
            currentItem.notes = targetVersion.notes + "\n[Rolled back from v\(targetVersion.versionNumber)]"
            currentItem.scheduledDate = targetVersion.scheduledDate
            
            try modelContext.save()
            
            // Create new version for the rollback action
            let newVersion = ContentItemVersion(
                itemId: itemId,
                versionNumber: (getCurrentVersionNumber(itemId: itemId, modelContext: modelContext) ?? 0) + 1,
                createdBy: "iOS (Rollback)",
                changeDescription: "Rollback to v\(targetVersion.versionNumber): \(reason)",
                title: currentItem.title,
                contentType: currentItem.contentType,
                objective: currentItem.objective,
                status: currentItem.status,
                pillar: currentItem.pillar,
                hook: currentItem.hook,
                caption: currentItem.caption,
                cta: currentItem.cta,
                hashtags: currentItem.hashtags,
                notes: currentItem.notes,
                scheduledDate: currentItem.scheduledDate
            )
            
            modelContext.insert(newVersion)
            try modelContext.save()
            
            // Log the rollback
            SyncAuditService.logOperation(
                type: "rollback",
                entityType: "SocialContentPlanItem",
                entityId: itemId,
                changesSummary: changesSummary,
                resolutionStrategy: "manual_rollback",
                modelContext: modelContext
            )
            
            return true
        } catch {
            print("❌ Failed to rollback: \(error)")
            return false
        }
    }
    
    /// Quick rollback to previous version (undo)
    static func quickUndo(
        itemId: String,
        reason: String = "Undo",
        modelContext: ModelContext
    ) -> Bool {
        let versions = getRollbackPoints(for: itemId, modelContext: modelContext)
        
        // Find the previous version (one before current)
        guard versions.count > 1 else {
            print("❌ No previous version available for undo")
            return false
        }
        
        let previousVersion = versions[1]
        return rollbackToVersion(itemId: itemId, toVersion: previousVersion, reason: reason, modelContext: modelContext)
    }
    
    /// Rollback item to specific timestamp
    static func rollbackToTimestamp(
        itemId: String,
        timestamp: Date,
        reason: String = "Rollback to timestamp",
        modelContext: ModelContext
    ) -> Bool {
        let descriptor = FetchDescriptor<ContentItemVersion>(
            predicate: #Predicate { version in
                version.itemId == itemId && version.createdAt <= timestamp
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let versions = try modelContext.fetch(descriptor)
            guard let targetVersion = versions.first else {
                print("❌ No version available at that timestamp")
                return false
            }
            
            return rollbackToVersion(
                itemId: itemId,
                toVersion: targetVersion,
                reason: "\(reason) (\(targetVersion.changeDescription))",
                modelContext: modelContext
            )
        } catch {
            print("❌ Failed to find version at timestamp: \(error)")
            return false
        }
    }
    
    // MARK: - Helpers
    
    private static func getCurrentVersionNumber(
        itemId: String,
        modelContext: ModelContext
    ) -> Int? {
        let descriptor = FetchDescriptor<ContentItemVersion>(
            predicate: #Predicate { version in
                version.itemId == itemId
            },
            sortBy: [SortDescriptor(\.versionNumber, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor).first?.versionNumber
        } catch {
            return nil
        }
    }
    
    // MARK: - Rollback UI Model
    
    struct RollbackPoint {
        let version: ContentItemVersion
        let timeSinceChange: TimeInterval
        let isWithinWindow: Bool
        let displayTitle: String
        let displayTime: String
        
        init(version: ContentItemVersion) {
            self.version = version
            self.timeSinceChange = Date().timeIntervalSince(version.createdAt)
            self.isWithinWindow = timeSinceChange <= ROLLBACK_WINDOW_SECONDS
            
            self.displayTitle = "v\(version.versionNumber): \(version.changeDescription)"
            
            let formatter = RelativeDateTimeFormatter()
            self.displayTime = formatter.localizedString(for: version.createdAt, relativeTo: Date())
        }
    }
}
