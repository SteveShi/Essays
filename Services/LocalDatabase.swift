import Foundation
import SwiftData

@MainActor
final class LocalDatabase {
    static let shared = LocalDatabase()
    
    // Auto-Recovery Constants
    private static let kLastInitializationSuccessful = "LocalDatabase.LastInitializationSuccessful"
    private static let kInitializationAttempts = "LocalDatabase.InitializationAttempts"
    private static let kMaxInitializationAttempts = 2
    
    let container: ModelContainer
    let context: ModelContext
    
    private init() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let databaseURL = appSupportURL.appendingPathComponent("Essays")
        let storeURL = databaseURL.appendingPathComponent("Essays.store")
        
        // 1. Check for Crash Loop and perform Self-Healing if needed
        let attempts = UserDefaults.standard.string(forKey: LocalDatabase.kInitializationAttempts) != nil ?
            UserDefaults.standard.integer(forKey: LocalDatabase.kInitializationAttempts) : 0
        let lastSuccess = UserDefaults.standard.bool(forKey: LocalDatabase.kLastInitializationSuccessful)
        
        if attempts > LocalDatabase.kMaxInitializationAttempts || (!lastSuccess && attempts > 0) {
            print("🚨 Crash loop detected (attempts: \(attempts), lastSuccess: \(lastSuccess)). Performing database hard reset.")
            LocalDatabase.hardReset(databaseURL: databaseURL)
            UserDefaults.standard.set(0, forKey: LocalDatabase.kInitializationAttempts)
        }
        
        // Mark current attempt as NOT successful (yet)
        UserDefaults.standard.set(attempts + 1, forKey: LocalDatabase.kInitializationAttempts)
        UserDefaults.standard.set(false, forKey: LocalDatabase.kLastInitializationSuccessful)
        
        do {
            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: databaseURL.path) {
                try? FileManager.default.createDirectory(at: databaseURL, withIntermediateDirectories: true)
            }
            
            let config = ModelConfiguration(url: storeURL)
            
            do {
                container = try ModelContainer(for: Memo.self, Attachment.self, Relation.self, Location.self, OutboxTask.self, configurations: config)
            } catch {
                print("Failed to initialize ModelContainer, attempting to recreate store: \(error)")
                // If initialization fails (likely due to schema change), delete the store and try again
                LocalDatabase.hardReset(databaseURL: databaseURL)
                container = try ModelContainer(for: Memo.self, Attachment.self, Relation.self, Location.self, OutboxTask.self, configurations: config)
            }
            
            context = container.mainContext
            print("SwiftData initialized at: \(storeURL.path)")
            
            // 🚨 CRITICAL FIX: Clean up duplicate relations before any higher-level fetches
            // This is the primary recovery phase for data-level corruption.
            cleanDuplicateRelations()
            
            // 2. Mark initialization as successful 🎉
            UserDefaults.standard.set(0, forKey: LocalDatabase.kInitializationAttempts)
            UserDefaults.standard.set(true, forKey: LocalDatabase.kLastInitializationSuccessful)
            
        } catch {
            print("Final SwiftData initialization error: \(error)")
            // If it still fails, fallback to in-memory store
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(for: Memo.self, Attachment.self, Relation.self, Location.self, OutboxTask.self, configurations: config)
                context = container.mainContext
                print("Falling back to in-memory store")
                // Still mark as successful for in-memory so we don't reset infinitely
                UserDefaults.standard.set(true, forKey: LocalDatabase.kLastInitializationSuccessful)
            } catch {
                fatalError("Failed to initialize SwiftData completely: \(error)")
            }
        }
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
}
