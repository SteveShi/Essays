import Foundation
import SwiftData

@MainActor
final class LocalDatabase {
    static let shared = LocalDatabase()
    
    let container: ModelContainer
    let context: ModelContext
    
    private init() {
        do {
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let databaseURL = appSupportURL.appendingPathComponent("Essays")
            
            // Create directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: databaseURL.path) {
                try? FileManager.default.createDirectory(at: databaseURL, withIntermediateDirectories: true)
            }
            
            let storeURL = databaseURL.appendingPathComponent("Essays.store")
            let config = ModelConfiguration(url: storeURL)
            
            do {
                container = try ModelContainer(for: Memo.self, Attachment.self, Relation.self, Location.self, configurations: config)
            } catch {
                print("Failed to initialize ModelContainer, attempting to recreate store: \(error)")
                // If initialization fails (likely due to schema change), delete the store and try again
                try? FileManager.default.removeItem(at: storeURL)
                container = try ModelContainer(for: Memo.self, Attachment.self, Relation.self, Location.self, configurations: config)
            }
            
            context = container.mainContext
            print("SwiftData initialized at: \(storeURL.path)")
        } catch {
            print("Final SwiftData initialization error: \(error)")
            // If it still fails, we have a bigger problem, but we'll try to fallback to a temporary in-memory store
            do {
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                container = try ModelContainer(for: Memo.self, Attachment.self, Relation.self, Location.self, configurations: config)
                context = container.mainContext
                print("Falling back to in-memory store")
            } catch {
                fatalError("Failed to initialize SwiftData completely: \(error)")
            }
        }
    }
    
    func saveMemos(_ memos: [Memo]) {
        for memo in memos {
            context.insert(memo)
        }
        try? context.save()
    }
    
    func fetchAllMemos() -> [Memo] {
        let descriptor = FetchDescriptor<Memo>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func deleteMemo(_ memo: Memo) {
        context.delete(memo)
        try? context.save()
    }
}
