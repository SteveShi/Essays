import Foundation
import SwiftData
import Observation
import OSLog

@MainActor
@Observable
class SyncEngine {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.steveshi.essays",
        category: "SyncEngine"
    )

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
        if AccountManager.shared.isLocalMode { return }
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
            let activeAccountID = AccountManager.shared.activeAccount.map {
                AppState.accountIdentifier(for: $0)
            } ?? "local"
            let scopedTasks = tasks.filter { taskBelongsToActiveAccount($0, activeAccountID: activeAccountID) }
            self.pendingTasksCount = scopedTasks.filter { $0.state == .pending || $0.state == .retry }.count
            self.errorTasksCount = scopedTasks.filter { $0.state == .error }.count
        } catch {
            Self.logger.error("Failed to fetch outbox stats: \(error.localizedDescription, privacy: .public)")
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
            if let account = AccountManager.shared.activeAccount, account.mode == .remote {
                MemosAPIClient.shared.configure(
                    serverURL: account.serverURL ?? "",
                    accessToken: account.accessToken ?? "",
                    apiVersion: account.apiVersion ?? .v027
                )
            }

            refreshStats()
            
            // 1. Process Outbox (Push local changes to server)
            try await processOutbox()
            
            // 2. Pull changes from server (even if outbox had tasks, we want the latest state)
            // This captures server-side archives, deletes, and new memos.
            await pullLatestMemos()
            
        } catch {
            Self.logger.error("Sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func processOutbox() async throws {
        let tasks = try LocalDatabase.shared.fetchOutboxTasks()
        let activeAccountID = AccountManager.shared.activeAccount.map {
            AppState.accountIdentifier(for: $0)
        } ?? "local"
        let now = Date()
        
        // Recover tasks that were left in `running` due to interruption/crash.
        for task in tasks where task.state == .running {
            task.state = .retry
            task.retryAt = now
        }
        try? LocalDatabase.shared.context.save()
        
        let runnableTasks = tasks
            .filter { task in
                guard taskBelongsToActiveAccount(task, activeAccountID: activeAccountID) else {
                    return false
                }
                switch task.state {
                case .pending:
                    return true
                case .retry:
                    guard let retryAt = task.retryAt else { return true }
                    return retryAt <= now
                case .running:
                    return true
                default:
                    return false
                }
            }
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
                // Success: mark as completed instead of deleting immediately
                task.state = .completed
                task.retryAt = nil
                task.lastError = nil
                try? LocalDatabase.shared.context.save()
            } catch let error as MemosAPIError {
                handleTaskError(task, error: error)
            } catch {
                handleTaskError(task, error: error)
            }
        }
    }

    private func taskBelongsToActiveAccount(_ task: OutboxTask, activeAccountID: String) -> Bool {
        if let payloadAccountID = extractAccountID(from: task) {
            return normalizedAccountID(payloadAccountID) == normalizedAccountID(activeAccountID)
        }

        if let memoId = task.memoId {
            if memoId.hasPrefix("local_") {
                return activeAccountID == "local"
            }
            let descriptor = FetchDescriptor<Memo>(predicate: #Predicate<Memo> { $0.name == memoId })
            if let memo = try? LocalDatabase.shared.context.fetch(descriptor).first,
               let memoAccountID = memo.accountID
            {
                return normalizedAccountID(memoAccountID) == normalizedAccountID(activeAccountID)
            }
        }

        // Fail closed: if we cannot prove task ownership, never sync it.
        return false
    }

    private func extractAccountID(from task: OutboxTask) -> String? {
        switch task.type {
        case .createMemo:
            return (try? JSONDecoder().decode(CreateMemoPayload.self, from: task.payload))?.accountID
        case .updateMemo:
            return (try? JSONDecoder().decode(UpdateMemoPayload.self, from: task.payload))?.accountID
        case .togglePinMemo:
            return (try? JSONDecoder().decode(TogglePinPayload.self, from: task.payload))?.accountID
        case .archiveMemo, .unarchiveMemo, .deleteMemo:
            return (try? JSONDecoder().decode(SimpleMemoPayload.self, from: task.payload))?.accountID
        case .unknown:
            return nil
        }
    }

    private func normalizedAccountID(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "local" { return "local" }
        return AppState.normalizedRemoteAccountID(from: trimmed)
    }
    
    private func executeTask(_ task: OutboxTask) async throws {
        switch task.type {
        case .createMemo:
            if let payload = try? JSONDecoder().decode(CreateMemoPayload.self, from: task.payload) {
                if let localMemoId = task.memoId, localMemoId.hasPrefix("local_") {
                    let localMemoDescriptor = FetchDescriptor<Memo>(predicate: #Predicate<Memo> { $0.name == localMemoId })
                    let localMemoExists = ((try? LocalDatabase.shared.context.fetch(localMemoDescriptor)) ?? []).isEmpty == false
                    if !localMemoExists {
                        return
                    }
                }
                
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
                if memoId.hasPrefix("local_") {
                    return
                }
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
    
    private func pullLatestMemos() async {
        do {
            // fetchMemos already does account-scoped snapshot sync into LocalDatabase.
            _ = try await MemosAPIClient.shared.fetchMemos()
            NotificationCenter.default.post(name: .syncCompleted, object: nil)
            
        } catch {
            Self.logger.error("Failed to pull memos: \(error.localizedDescription, privacy: .public)")
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

extension Notification.Name {
    static let syncCompleted = Notification.Name("syncCompleted")
    static let databaseContainerDidChange = Notification.Name("com.steveshi.essays.databaseContainerDidChange")
}
