import Foundation

struct User: Codable, Identifiable, Sendable {
    let name: String          // Resource name, e.g. "users/alice" (previously "users/1")
    let role: UserRole
    let username: String
    let email: String?
    let displayName: String?
    let avatarUrl: String?
    let description: String?
    let state: String?
    let createTime: String?
    let updateTime: String?
    
    var id: String { name }
    
    var displayNameResolved: String {
        if let dn = displayName, !dn.isEmpty {
            return dn
        }
        return username
    }
}

enum UserRole: String, Codable {
    case roleUnspecified = "ROLE_UNSPECIFIED"
    case admin = "ADMIN"
    case user = "USER"
}
