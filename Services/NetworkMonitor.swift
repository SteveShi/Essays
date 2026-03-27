import Foundation
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    var isConnected: Bool = true
    var onConnectedChange: ((Bool) -> Void)?
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let status = path.status == .satisfied
            
            Task { @MainActor in
                if self?.isConnected != status {
                    self?.isConnected = status
                    self?.onConnectedChange?(status)
                }
            }
        }
        monitor.start(queue: queue)
    }
}
