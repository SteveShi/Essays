import Foundation

struct Location: Codable, Hashable, Sendable {
    let placeholder: String?
    let latitude: Double
    let longitude: Double
}
