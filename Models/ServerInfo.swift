import Foundation

struct ServerInfo: Codable {
    let version: String
    let mode: String
    let allowSignUp: Bool
    let disablePasswordLogin: Bool
    let dbType: String
}
