import Foundation
import SwiftData
import Observation

@MainActor
@Observable
class SyncEngine {
    static let shared = SyncEngine()
    
    var isSyncing = false
    var lastSyncTime: Date?
    var pendingTasksCount: Int = 0
    var errorTasksCount: Int = 0
    
    private var syncTask: Task<Void, Never>?
    
    private init() {
        // Observe network changes to trigger sync
        NetworkMonitor.shared.onConnectedChange = { [weak self] isConnected in
            if isConnected {
                Task { @MainActor in
                    self?.triggerSync()
                }
            }
        }
    }
    
    /// Trigger an outbox sync process
    func triggerSync() {
        guard !isSyncing else { return }
        guard NetworkMonitor.shared.isConnected else { return }
        
        // Prevent concurrent syncs
        syncTask?.cancel()
        
        syncTask = Task {
            await performSync()
        }
    }
    
    /// Refreshes the outbox statistics for UI display
    func refreshStats() {
        do {
            let tasks = try LocalDatabase.shared.fetchOutboxTasks()
            self.pendingTasksCount = tasks.filter { $0.state == .pending || $0.state == .retry }.count
            self.errorTasksCount = tasks.filter { $0.state == .error }.count
        } catch {
            print("Failed to fetch outbox stats: \(error)")
        }
    }
    
    private func performSync() async {
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncTime = Date()
            refreshStats()
        }
        
        do {
            refreshStats()
            
            // 1. Process Outbox (Push local changes to server)
            try await processOutbox()
            
            // 2. Optional: Pull changes from server if outbox is clear
            if pendingTasksCount == 0 {
                // await pullLatestMemos()
            }
            
        } catch {
            print("Sync failed: \(error)")
        }
    }
    
    private func processOutbox() async throws {
        let tasks = try LocalDatabase.shared.fetchOutboxTasks()
        let runnableTasks = tasks.filter { $0.state == .pending || $0.state == .retry }
                               .sorted { $0.createdAt < $1.createdAt }
        
        guard !runnableTasks.isEmpty else { return }
        
        for task in runnableTasks {
            if Task.isCancelled { break }
            
            // Mark as running
            task.state = .running
            // We need to save the state immediately
            try? LocalDatabase.shared.context.save()
            
            do {
                try await executeTask(task)
                // Success: remove from outbox
                LocalDatabase.shared.deleteOutboxTask(task)
            } catch let error as MemosAPIError {
                handleTaskError(task, error: error)
            } catch {
                handleTaskError(task, error: error)
            }
        }
    }
    
    private func executeTask(_ task: OutboxTask) async throws {
        switch task.type {
        case .createMemo:
            if let payload = try? JSONDecoder().decode(CreateMemoPayload.self, from: task.payload) {
                var loc: Location? = nil
                if let lat = payload.locationLatitude, let lon = payload.locationLongitude {
                    loc = Location(placeholder: payload.locationPlaceholder ?? "", latitude: lat, longitude: lon)
                }
                let memo = try await MemosAPIClient.shared.createMemo(
                    content: payload.content,
                    visibility: payload.visibility.flatMap { MemoVisibility(rawValue: $0) },
                    tags: payload.tags,
                    pinned: payload.pinned,
                    attachmentNames: payload.attachmentNames,
                    location: loc
                )
                if let localMemoId = task.memoId {
                    LocalDatabase.shared.replaceLocalMemoId(oldId: localMemoId, newMemo: memo)
                }
            }
            
        case .updateMemo:
            if let memoId = task.memoId, let payload = try? JSONDecoder().decode(UpdateMemoPayload.self, from: task.payload) {
                var loc: Location? = nil
                if let lat = payload.locationLatitude, let lon = payload.locationLongitude {
                    loc = Location(placeholder: payload.locationPlaceholder ?? "", latitude: lat, longitude: lon)
                }
                _ = try await MemosAPIClient.shared.updateMemo(
                    memoName: memoId,
                    content: payload.content,
                    visibility: payload.visibility.flatMap { MemoVisibility(rawValue: $0) },
                    tags: payload.tags,
                    pinned: payload.pinned,
                    attachmentNames: payload.attachmentNames,
                    location: loc
                )
            }
            
        case .deleteMemo:
            if let memoId = task.memoId {
                try await MemosAPIClient.shared.deleteMemo(memoName: memoId)
            }
            
        case .archiveMemo:
            if let memoId = task.memoId {
                _ = try await MemosAPIClient.shared.archiveMemo(memoName: memoId)
            }
            
        case .unarchiveMemo:
            if let memoId = task.memoId {
                _ = try await MemosAPIClient.shared.unarchiveMemo(memoName: memoId)
            }
            
        case .togglePinMemo:
            if let memoId = task.memoId, let payload = try? JSONDecoder().decode(TogglePinPayload.self, from: task.payload) {
                _ = try await MemosAPIClient.shared.togglePinMemo(pinned: payload.pinned, memoName: memoId)
            }
            
        case .unknown:
            break
        }
    }
    
    private func handleTaskError(_ task: OutboxTask, error: Error) {
        task.attempts += 1
        task.lastError = error.localizedDescription
        
        // Simple retry logic
        if task.attempts < 5 {
            task.state = .retry
            task.retryAt = Date().addingTimeInterval(pow(2.0, Double(task.attempts)) * 60.0) // Exponential backoff
        } else {
            task.state = .error
        }
        
        try? LocalDatabase.shared.context.save()
    }
}
