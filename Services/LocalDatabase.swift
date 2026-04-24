import Foundation
import SwiftData

@MainActor
final class LocalDatabase {
    static let shared = LocalDatabase()
    
    private static let storesRootDirectoryName = "Essays"
    
    private(set) var container: ModelContainer
    private(set) var context: ModelContext
    private(set) var activeStoreDirectory: URL
    private var isActivatingStore = false
    
    private init() {
        let initialDirectory = Self.defaultDirectoryForNoAccount()
        self.activeStoreDirectory = initialDirectory

        do {
            let loadedContainer = try Self.openContainer(storeDirectory: initialDirectory)
            self.container = loadedContainer
            self.context = loadedContainer.mainContext
            cleanDuplicateRelations()
        } catch {
            print("SwiftData init failed for \(initialDirectory.path): \(error)")
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                let fallbackContainer = try ModelContainer(
                    for: Memo.self,
                    Attachment.self,
                    Relation.self,
                    Location.self,
                    OutboxTask.self,
                    configurations: config
                )
                self.container = fallbackContainer
                self.context = fallbackContainer.mainContext
                print("Falling back to in-memory store")
            } catch {
                fatalError("Failed to initialize SwiftData completely: \(error)")
            }
        }
    }

    @discardableResult
    func activateStore(for account: Account?) -> Account? {
        if isActivatingStore {
            return account
        }
        var resolved = account

        if var account = resolved {
            let trimmed = account.dataDirectoryPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                if account.mode == .local, Self.legacyStoreFileExists() {
                    account.dataDirectoryPath = Self.legacyStoreDirectoryURL().path
                } else {
                    let defaultDirectory = Self.defaultDirectory(for: account)
                    account.dataDirectoryPath = defaultDirectory.path
                }
                AccountManager.shared.updateAccount(account)
                resolved = account
            } else if account.mode == .remote,
                      let migratedPath = Self.migratedRemoteStorePathIfNeeded(for: account, currentPath: trimmed)
            {
                account.dataDirectoryPath = migratedPath
                AccountManager.shared.updateAccount(account)
                resolved = account
            }
        }

        let targetDirectory = Self.storeDirectory(for: resolved)
        guard targetDirectory != activeStoreDirectory else {
            return resolved
        }

        do {
            isActivatingStore = true
            defer { isActivatingStore = false }
            let loadedContainer = try Self.openContainer(storeDirectory: targetDirectory)
            self.container = loadedContainer
            self.context = loadedContainer.mainContext
            self.activeStoreDirectory = targetDirectory
            cleanDuplicateRelations()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .databaseContainerDidChange, object: nil)
            }
            print("Switched SwiftData store: \(targetDirectory.path)")
        } catch {
            isActivatingStore = false
            print("Failed to switch SwiftData store: \(error)")
        }

        return resolved
    }

    private static func openContainer(storeDirectory: URL) throws -> ModelContainer {
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        let storeURL = storeDirectory.appendingPathComponent("Essays.store")
        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(
            for: Memo.self,
            Attachment.self,
            Relation.self,
            Location.self,
            OutboxTask.self,
            configurations: config
        )
    }

    private static func storeDirectory(for account: Account?) -> URL {
        if let account {
            let trimmed = account.dataDirectoryPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty {
                return URL(fileURLWithPath: trimmed, isDirectory: true)
            }
            return defaultDirectory(for: account)
        }
        return defaultDirectoryForNoAccount()
    }

    private static func defaultDirectory(for account: Account) -> URL {
        let root = storesRootDirectoryURL()
        if account.mode == .local {
            return root
                .appendingPathComponent("local", isDirectory: true)
                .appendingPathComponent(account.id.uuidString, isDirectory: true)
        }

        let folderName = remoteAccountFolderName(for: account)
        return root.appendingPathComponent(folderName, isDirectory: true)
    }

    private static func defaultDirectoryForNoAccount() -> URL {
        storesRootDirectoryURL()
            .appendingPathComponent("anonymous", isDirectory: true)
    }

    private static func storesRootDirectoryURL() -> URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupportURL.appendingPathComponent(storesRootDirectoryName, isDirectory: true)
    }

    private static func remoteAccountFolderName(for account: Account) -> String {
        let rawName = account.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitizedScalars = rawName.unicodeScalars.map { invalid.contains($0) ? "_" : Character($0) }
        let sanitized = String(sanitizedScalars)
            .replacingOccurrences(of: "\n", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: " ."))

        if !sanitized.isEmpty {
            return sanitized
        }
        return account.id.uuidString
    }

    private static func migratedRemoteStorePathIfNeeded(for account: Account, currentPath: String) -> String? {
        let legacyRemoteRoot = storesRootDirectoryURL()
            .appendingPathComponent("remote", isDirectory: true).path
        guard currentPath.hasPrefix(legacyRemoteRoot) else {
            return nil
        }

        let targetURL = defaultDirectory(for: account)
        let targetPath = targetURL.path
        guard currentPath != targetPath else {
            return nil
        }

        let currentURL = URL(fileURLWithPath: currentPath, isDirectory: true)
        do {
            if FileManager.default.fileExists(atPath: currentURL.path),
               !FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.createDirectory(
                    at: targetURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try FileManager.default.moveItem(at: currentURL, to: targetURL)
            }
            return targetPath
        } catch {
            print("Failed to migrate remote store path from \(currentPath) to \(targetPath): \(error)")
            return nil
        }
    }

    private static func legacyStoreDirectoryURL() -> URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupportURL.appendingPathComponent("Essays", isDirectory: true)
    }

    private static func legacyStoreFileExists() -> Bool {
        let legacyStore = legacyStoreDirectoryURL().appendingPathComponent("Essays.store")
        return FileManager.default.fileExists(atPath: legacyStore.path)
    }
    
    /// Deletes the Essays directory and all its contents (Essays.store, Essays.store-shm, etc.)
    static func hardReset(databaseURL: URL) {
        do {
            try FileManager.default.removeItem(at: databaseURL)
            print("Database hard reset successful.")
        } catch {
            print("Failed to perform database hard reset: \(error)")
        }
    }
    
    /// Scans for and removes duplicate Relation records that might violate unique constraints
    private func cleanDuplicateRelations() {
        print("Starting Relation cleanup...")
        do {
            let descriptor = FetchDescriptor<Relation>()
            let allRelations = try context.fetch(descriptor)
            
            var seenIDs = Set<String>()
            var duplicatesFound = 0
            
            for relation in allRelations {
                if seenIDs.contains(relation.relationID) {
                    // Explicitly remove from parent relationship to avoid zombie references in memory
                    if let parent = relation.parentMemo {
                        parent.relations.removeAll { $0 === relation }
                    }
                    context.delete(relation)
                    duplicatesFound += 1
                } else {
                    seenIDs.insert(relation.relationID)
                }
            }
            
            if duplicatesFound > 0 {
                print("Cleaned up \(duplicatesFound) duplicate relations")
                try context.save()
                // Force SwiftData to process the deletions and update the relationship graph
                context.processPendingChanges()
            }
        } catch {
            print("Cleanup error: \(error)")
            // If this fails due to unique constraint crash, we'll likely hit the crash loop handler next boot.
        }
    }
    
    /// Full snapshot sync from server.
    /// Deletes local memos that are no longer in incoming list.
    func syncMemosSnapshot(_ incomingMemos: [Memo]) -> [Memo] {
        return syncMemos(incomingMemos, removeMissingLocalMemos: true)
    }

    /// Account-scoped full snapshot sync from server.
    /// Only deletes memos belonging to the specific account.
    func syncMemosSnapshot(_ incomingMemos: [Memo], forAccountID accountID: String) -> [Memo] {
        let normalizedAccountID = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        let incomingNames = Set(incomingMemos.map { $0.name })
        let allLocalMemos = fetchAllMemos()

        for localMemo in allLocalMemos
            where localMemo.accountID == normalizedAccountID && !incomingNames.contains(localMemo.name)
        {
            context.delete(localMemo)
        }

        context.processPendingChanges()
        _ = syncMemos(incomingMemos, removeMissingLocalMemos: false)
        return fetchMemos(forAccountID: normalizedAccountID)
    }
    
    /// Incremental upsert.
    /// Only creates/updates incoming memos and never deletes other local data.
    func upsertMemos(_ incomingMemos: [Memo]) -> [Memo] {
        return syncMemos(incomingMemos, removeMissingLocalMemos: false)
    }
    
    /// Backward-compatible wrapper.
    /// Keep old callsites working while avoiding accidental behavior change.
    func saveMemos(_ incomingMemos: [Memo]) -> [Memo] {
        return syncMemosSnapshot(incomingMemos)
    }
    
    private func syncMemos(_ incomingMemos: [Memo], removeMissingLocalMemos: Bool) -> [Memo] {
        if removeMissingLocalMemos {
            let incomingNames = Set(incomingMemos.map { $0.name })
            let allLocalMemos = fetchAllMemos()
            
            for localMemo in allLocalMemos where !incomingNames.contains(localMemo.name) {
                context.delete(localMemo)
            }
            
            // Process deletes before rebuilding maps.
            context.processPendingChanges()
        }
        
        // Build maps from current state.
        let remainingMemos = fetchAllMemos()
        let allLocalAttachments = (try? context.fetch(FetchDescriptor<Attachment>())) ?? []
        let allLocalRelations = (try? context.fetch(FetchDescriptor<Relation>())) ?? []
        
        var localMemosByName = Dictionary(remainingMemos.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var localAttachmentsByName = Dictionary(allLocalAttachments.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        var localRelationsByID = Dictionary(allLocalRelations.map { ($0.relationID, $0) }, uniquingKeysWith: { first, _ in first })
        
        // 3. Upsert incoming memos
        for incomingMemo in incomingMemos {
            if let existing = localMemosByName[incomingMemo.name] {
                // Update existing
                transferData(to: existing, 
                            from: incomingMemo, 
                            attachments: incomingMemo.attachments, 
                            relations: incomingMemo.relations, 
                            location: incomingMemo.location, 
                            attachmentsMap: &localAttachmentsByName, 
                            relationsMap: &localRelationsByID)
            } else {
                // 🚨 CRITICAL: Use 'Naked Insertion' to prevent bulk insert of unmanaged trees.
                let unmanagedAttachments = incomingMemo.attachments
                let unmanagedRelations = incomingMemo.relations
                let unmanagedLocation = incomingMemo.location
                
                // Strip to make it naked before insertion
                incomingMemo.attachments = []
                incomingMemo.relations = []
                incomingMemo.location = nil
                
                context.insert(incomingMemo)
                localMemosByName[incomingMemo.name] = incomingMemo
                
                // Use a dedicated helper that takes the naked managed object and the unmanaged data
                transferData(to: incomingMemo, 
                            from: incomingMemo, // still source of simple properties
                            attachments: unmanagedAttachments, 
                            relations: unmanagedRelations, 
                            location: unmanagedLocation,
                            attachmentsMap: &localAttachmentsByName,
                            relationsMap: &localRelationsByID)
            }
        }
        
        // Finalize state
        context.processPendingChanges()
        try? context.save()
        
        // Return the final state from the database
        return fetchAllMemos()
    }
    
    /// Core logic to transfer data from a template (managed or unmanaged) to a target managed memo.
    /// This ensures we only use managed instances from our maps or create new ones from scratch.
    private func transferData(to target: Memo, 
                            from source: Memo,
                            attachments: [Attachment],
                            relations: [Relation],
                            location: Location?,
                            attachmentsMap: inout [String: Attachment],
                            relationsMap: inout [String: Relation]) {
        target.content = source.content
        target.updatedAt = source.updatedAt
        target.pinned = source.pinned
        target.visibility = source.visibility
        target.state = source.state
        target.tags = source.tags
        
        // Update Location (1-to-1)
        if let incomingLoc = location {
            if let targetLoc = target.location {
                targetLoc.latitude = incomingLoc.latitude
                targetLoc.longitude = incomingLoc.longitude
                targetLoc.placeholder = incomingLoc.placeholder
            } else {
                // Create a completely new managed Location instance
                let newLoc = Location(placeholder: incomingLoc.placeholder, 
                                     latitude: incomingLoc.latitude, 
                                     longitude: incomingLoc.longitude,
                                     parentMemo: target)
                target.location = newLoc
            }
        } else {
            target.location = nil
        }
        
        // Update Attachments (Global Upsert)
        var finalAttachments: [Attachment] = []
        for incomingAttr in attachments {
            if let existingAttr = attachmentsMap[incomingAttr.name] {
                // Reuse existing object
                existingAttr.filename = incomingAttr.filename
                existingAttr.type = incomingAttr.type
                existingAttr.size = incomingAttr.size
                existingAttr.content = incomingAttr.content
                existingAttr.externalLink = incomingAttr.externalLink
                existingAttr.parentMemo = target
                finalAttachments.append(existingAttr)
            } else {
                // Create a completely new managed Attachment instance
                let newAttr = Attachment(name: incomingAttr.name, 
                                       filename: incomingAttr.filename, 
                                       type: incomingAttr.type, 
                                       size: incomingAttr.size, 
                                       content: incomingAttr.content, 
                                       externalLink: incomingAttr.externalLink, 
                                       createTime: incomingAttr.createTime, 
                                       memoName: target.name,
                                       parentMemo: target)
                attachmentsMap[incomingAttr.name] = newAttr
                finalAttachments.append(newAttr)
            }
        }
        target.attachments = finalAttachments
        
        // Update Relations (Global Upsert)
        var finalRelations: [Relation] = []
        for incomingRel in relations {
            if let existingRel = relationsMap[incomingRel.relationID] {
                existingRel.memo = incomingRel.memo
                existingRel.relatedMemo = incomingRel.relatedMemo
                existingRel.type = incomingRel.type
                existingRel.parentMemo = target
                finalRelations.append(existingRel)
            } else {
                // Create a completely new managed Relation instance
                let newRel = Relation(memo: incomingRel.memo, 
                                    relatedMemo: incomingRel.relatedMemo, 
                                    type: incomingRel.type, 
                                    parentMemo: target)
                relationsMap[incomingRel.relationID] = newRel
                finalRelations.append(newRel)
            }
        }
        target.relations = finalRelations
    }
    
    func fetchAllMemos() -> [Memo] {
        let descriptor = FetchDescriptor<Memo>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchMemos(forAccountID accountID: String) -> [Memo] {
        let normalized = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        let allMemos = fetchAllMemos()

        if normalized == "local" {
            return allMemos.filter { memo in
                memo.name.hasPrefix("local_")
                    || memo.accountID?.trimmingCharacters(in: .whitespacesAndNewlines) == "local"
            }
        }

        return allMemos.filter { memo in
            guard let memoAccountID = memo.accountID?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !memoAccountID.isEmpty,
                  memoAccountID != "local"
            else {
                return false
            }

            return AppState.normalizedRemoteAccountID(from: memoAccountID)
                == AppState.normalizedRemoteAccountID(from: normalized)
        }
    }
    
    func deleteMemo(_ memo: Memo) {
        context.delete(memo)
        try? context.save()
    }
    
    // MARK: - Outbox Tasks
    
    @MainActor
    func fetchOutboxTasks() throws -> [OutboxTask] {
        let descriptor = FetchDescriptor<OutboxTask>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor)
    }
    
    @MainActor
    func deleteOutboxTask(_ task: OutboxTask) {
        context.delete(task)
        try? context.save()
    }
    
    @MainActor
    func replaceLocalMemoId(oldId: String, newMemo: Memo) {
        // Find by name (since numericID might be empty for pending)
        let descriptor = FetchDescriptor<Memo>(predicate: #Predicate { $0.name == oldId })
        if let existing = try? context.fetch(descriptor).first {
            existing.numericID = newMemo.numericID
            existing.name = newMemo.name
            existing.createdAt = newMemo.createdAt
            existing.updatedAt = newMemo.updatedAt
            if existing.accountID == nil || existing.accountID?.isEmpty == true {
                existing.accountID = AccountManager.shared.activeAccount.map {
                    AppState.accountIdentifier(for: $0)
                } ?? "local"
            }
            existing.isPendingSync = false
            for attachment in existing.attachments {
                attachment.memoName = newMemo.name
            }
            
            // Keep pending outbox tasks pointing to the new server ID.
            let taskDescriptor = FetchDescriptor<OutboxTask>(predicate: #Predicate<OutboxTask> { $0.memoId == oldId })
            if let relatedTasks = try? context.fetch(taskDescriptor) {
                for task in relatedTasks where task.state != .completed {
                    task.memoId = newMemo.name
                }
            }
            
            // Critical: Ensure the update is pushed to the persistent store immediately
            try? context.save()
            
            // Notify UI that an ID has changed
            NotificationCenter.default.post(name: Notification.Name("syncCompleted"), object: nil)
        }
    }
    
    @MainActor
    func deletePendingOutboxTasks(forMemoId memoId: String) {
        let descriptor = FetchDescriptor<OutboxTask>(predicate: #Predicate<OutboxTask> { $0.memoId == memoId })
        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks where task.state != .completed {
            context.delete(task)
        }
        try? context.save()
    }

    @MainActor
    func purgeLocalOutboxTasks() {
        let descriptor = FetchDescriptor<OutboxTask>()
        guard let tasks = try? context.fetch(descriptor) else { return }
        for task in tasks {
            if let memoId = task.memoId, memoId.hasPrefix("local_") {
                context.delete(task)
                continue
            }

            if task.type == .createMemo,
               let payload = try? JSONDecoder().decode(CreateMemoPayload.self, from: task.payload),
               payload.accountID == "local"
            {
                context.delete(task)
                continue
            }

            if task.type == .updateMemo,
               let payload = try? JSONDecoder().decode(UpdateMemoPayload.self, from: task.payload),
               payload.accountID == "local"
            {
                context.delete(task)
                continue
            }

            if task.type == .togglePinMemo,
               let payload = try? JSONDecoder().decode(TogglePinPayload.self, from: task.payload),
               payload.accountID == "local"
            {
                context.delete(task)
                continue
            }

            if let payload = try? JSONDecoder().decode(SimpleMemoPayload.self, from: task.payload),
               payload.accountID == "local"
            {
                context.delete(task)
                continue
            }

            // No account marker and no resolvable memo: treat as orphan task and drop.
            if task.memoId == nil {
                let createPayload = try? JSONDecoder().decode(CreateMemoPayload.self, from: task.payload)
                let updatePayload = try? JSONDecoder().decode(UpdateMemoPayload.self, from: task.payload)
                let togglePayload = try? JSONDecoder().decode(TogglePinPayload.self, from: task.payload)
                let simplePayload = try? JSONDecoder().decode(SimpleMemoPayload.self, from: task.payload)
                let hasAccountHint = createPayload?.accountID != nil
                    || updatePayload?.accountID != nil
                    || togglePayload?.accountID != nil
                    || simplePayload?.accountID != nil
                if !hasAccountHint {
                    context.delete(task)
                }
            }
        }
        try? context.save()
    }
}
