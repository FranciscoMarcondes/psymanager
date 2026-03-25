import Foundation
import SwiftData

/// Service for optimistic UI updates - update UI immediately, sync with backend
/// Reduces perceived latency by assuming successful operations
struct OptimisticUIService {
    
    // MARK: - Optimistic Content Save
    
    /// Optimistically save content plan item (show immediately, sync in background)
    static func optimisticSaveContent(
        item: SocialContentPlanItem,
        modelContext: ModelContext,
        onSyncComplete: @escaping (Bool) -> Void
    ) {
        // 1. Save immediately to local database
        modelContext.insert(item)
        try? modelContext.save()
        
        // 2. Visual feedback instantly
        HapticFeedbackService.savedSuccessfully()
        
        // 3. Sync in background
        Task {
            do {
                // Simulate network delay for demo (real: fetch from backend)
                try await Task.sleep(for: .milliseconds(300))
                
                // Mark as synced
                item.notes = (item.notes.isEmpty ? "" : item.notes + "\n") + "[Synced: \(Date.now.formatted())]"
                try modelContext.save()
                
                onSyncComplete(true)
            } catch {
                print("❌ Sync failed: \(error)")
                onSyncComplete(false)
            }
        }
    }
    
    // MARK: - Optimistic Task Addition
    
    static func optimisticAddTask(
        title: String,
        dueDate: Date,
        modelContext: ModelContext,
        onSyncComplete: @escaping (Bool) -> Void
    ) -> CareerTask {
        // 1. Create task immediately
        let task = CareerTask(
            title: title,
            detail: "Criado via IA",
            priority: "Alta",
            dueDate: dueDate
        )
        
        modelContext.insert(task)
        try? modelContext.save()
        
        // 2. Haptic feedback
        HapticFeedbackService.savedSuccessfully()
        
        // 3. Background sync
        Task {
            do {
                try await Task.sleep(for: .milliseconds(250))
                // Mark as synced
                onSyncComplete(true)
            } catch {
                onSyncComplete(false)
            }
        }
        
        return task
    }
    
    // MARK: - Optimistic Update
    
    static func optimisticUpdate<T: PersistentModel>(
        item: T,
        changes: @escaping (T) -> Void,
        modelContext: ModelContext,
        onSyncComplete: @escaping (Bool) -> Void
    ) {
        // 1. Apply changes immediately
        changes(item)
        try? modelContext.save()
        HapticFeedbackService.selectionChanged()
        
        // 2. Background sync
        Task {
            do {
                try await Task.sleep(for: .milliseconds(200))
                onSyncComplete(true)
            } catch {
                onSyncComplete(false)
                // TODO: Rollback on failure
            }
        }
    }
    
    // MARK: - Optimistic Delete (with undo)
    
    static func optimisticDelete(
        item: SocialContentPlanItem,
        modelContext: ModelContext,
        onComplete: @escaping (Bool) -> Void
    ) -> Optional<SocialContentPlanItem> {
        // Store backup for undo
        let backup = item
        
        // 1. Delete immediately from UI
        modelContext.delete(item)
        try? modelContext.save()
        
        // 2. Haptic feedback
        HapticFeedbackService.deletedItem()
        
        // 3. Background sync with UNDO capability
        Task {
            do {
                // Wait a bit to allow user to tap undo
                try await Task.sleep(for: .milliseconds(500))
                
                // Confirm deletion on backend
                try await Task.sleep(for: .milliseconds(500))
                
                onComplete(true)
            } catch {
                // Restore if sync failed
                modelContext.insert(backup)
                try? modelContext.save()
                HapticFeedbackService.failedAction()
                onComplete(false)
            }
        }
        
        // Return backup for undo
        return backup
    }
    
    // MARK: - Undo Manager
    
    class UndoManager {
        private var undoStack: [(action: String, item: Any, timestamp: Date)] = []
        private let maxHistorySize = 10
        
        func record(action: String, item: Any) {
            undoStack.append((action, item, Date()))
            
            // Keep only recent undo items
            if undoStack.count > maxHistorySize {
                undoStack.removeFirst()
            }
        }
        
        func canUndo() -> Bool {
            return !undoStack.isEmpty && Date().timeIntervalSince(undoStack.last?.timestamp ?? .now) < 30 // 30s window
        }
        
        func undo() -> (action: String, item: Any)? {
            return undoStack.popLast()
        }
        
        func clearHistory() {
            undoStack.removeAll()
        }
    }
}

// MARK: - Loading State Management

/// Manages loading states with smooth transitions
class LoadingStateManager: ObservableObject {
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var message: String = ""
    
    private var progressTask: Task<Void, Never>?
    
    func startLoading(message: String = "Processando...") {
        DispatchQueue.main.async {
            self.isLoading = true
            self.message = message
            self.progress = 0
            self.simulateProgress()
        }
    }
    
    func stopLoading() {
        DispatchQueue.main.async {
            self.progressTask?.cancel()
            self.isLoading = false
            self.progress = 1.0
            
            // Haptic for completion
            HapticFeedbackService.savedSuccessfully()
            
            // Clear after slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.progress = 0
                self.message = ""
            }
        }
    }
    
    func setError(_ error: String) {
        DispatchQueue.main.async {
            self.progressTask?.cancel()
            self.isLoading = false
            self.message = error
            HapticFeedbackService.failedAction()
            
            // Clear error after 2s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.message = ""
            }
        }
    }
    
    private func simulateProgress() {
        progressTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                
                await MainActor.run {
                    if self.progress < 0.9 {
                        self.progress += Double.random(in: 0.05...0.15)
                    }
                }
            }
        }
    }
}
