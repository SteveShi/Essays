import Foundation

struct Tag: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    var count: Int
    
    init(name: String, count: Int = 0) {
        self.id = UUID()
        self.name = name
        self.count = count
    }
}
