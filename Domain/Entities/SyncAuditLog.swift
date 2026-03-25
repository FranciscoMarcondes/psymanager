import Foundation
import SwiftData

/// Audit log entry for every sync operation
/// Enables tracking, debugging, and rollback capabilities
@Model
final class SyncAuditLog {
    var id: String
    var operationType: String // "push", "pull", "merge", "delete", "create"
    var entityType: String // "SocialContentPlanItem", "Gig", "EventLead", etc.
    var entityId: String
    var deviceId: String
    var timestamp: Date
    var changesSummary: String // "{\"title\": \"old\" → \"new\"}"
    var conflictDetected: Bool
    var resolutionStrategy: String? // "keep_remote", "keep_local", "merge_fields", "manual_review"
    var statusCode: Int? // HTTP status if from API
    var errorMessage: String?
    var syncDurationMs: Int? // milliseconds
    var dataSize: Int? // bytes transferred
    
    init(
        operationType: String,
        entityType: String,
        entityId: String,
        deviceId: String = UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
        changesSummary: String = "",
        conflictDetected: Bool = false,
        resolutionStrategy: String? = nil,
        statusCode: Int? = nil,
        errorMessage: String? = nil,
        syncDurationMs: Int? = nil,
        dataSize: Int? = nil
    ) {
        self.id = UUID().uuidString
        self.operationType = operationType
        self.entityType = entityType
        self.entityId = entityId
        self.deviceId = deviceId
        self.timestamp = .now
        self.changesSummary = changesSummary
        self.conflictDetected = conflictDetected
        self.resolutionStrategy = resolutionStrategy
        self.statusCode = statusCode
        self.errorMessage = errorMessage
        self.syncDurationMs = syncDurationMs
        self.dataSize = dataSize
    }
}

/// Version history for content items to enable rollback
@Model
final class ContentItemVersion {
    var id: String
    var itemId: String // Reference to SocialContentPlanItem
    var versionNumber: Int
    var createdAt: Date
    var createdBy: String // "iOS", "Web", "API"
    var changeDescription: String
    
    // Snapshot of the item at this version
    var title: String
    var contentType: String
    var objective: String
    var status: String
    var pillar: String
    var hook: String
    var caption: String
    var cta: String
    var hashtags: String
    var notes: String
    var scheduledDate: Date
    
    init(
        itemId: String,
        versionNumber: Int,
        createdBy: String,
        changeDescription: String,
        title: String,
        contentType: String,
        objective: String,
        status: String,
        pillar: String,
        hook: String,
        caption: String,
        cta: String,
        hashtags: String,
        notes: String,
        scheduledDate: Date
    ) {
        self.id = UUID().uuidString
        self.itemId = itemId
        self.versionNumber = versionNumber
        self.createdAt = .now
        self.createdBy = createdBy
        self.changeDescription = changeDescription
        
        self.title = title
        self.contentType = contentType
        self.objective = objective
        self.status = status
        self.pillar = pillar
        self.hook = hook
        self.caption = caption
        self.cta = cta
        self.hashtags = hashtags
        self.notes = notes
        self.scheduledDate = scheduledDate
    }
}

/// Conflict record for manual resolution
@Model
final class SyncConflict {
    var id: String
    var entityType: String
    var entityId: String
    var detectedAt: Date
    var resolvedAt: Date?
    var localVersion: String // JSON snapshot
    var remoteVersion: String // JSON snapshot
    var resolutionChoice: String? // "local", "remote", "merged"
    var mergedData: String?
    var status: String // "pending", "resolved", "archived"
    
    init(
        entityType: String,
        entityId: String,
        localVersion: String,
        remoteVersion: String
    ) {
        self.id = UUID().uuidString
        self.entityType = entityType
        self.entityId = entityId
        self.detectedAt = .now
        self.resolvedAt = nil
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.resolutionChoice = nil
        self.mergedData = nil
        self.status = "pending"
    }
}
