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
            
            container = try ModelContainer(for: Memo.self, Attachment.self, Relation.self, Location.self, configurations: config)
            context = container.mainContext
            print("SwiftData initialized at: \(storeURL.path)")
        } catch {
            fatalError("Failed to initialize SwiftData: \(error)")
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
