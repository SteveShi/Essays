import Foundation
import CoreLocation

import Observation

@MainActor
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let manager = CLLocationManager()
    
    var location: Location?
    var isFetching = false
    var error: String?
    var lastRequestID: UUID?
    private var timeoutTask: Task<Void, Never>?
    
    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation(id: UUID? = nil) {
        lastRequestID = id
        if isFetching {
            print("Already fetching, updated request ID.")
            return
        }
        
        isFetching = true
        error = nil
        
        let status = manager.authorizationStatus
        
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            error = String(localized: "Location access denied. Please enable it in System Settings.", comment: "Error message for denied location access")
            isFetching = false
            return
        default:
            break
        }
        
        // 确保是一个全新的开始
        manager.stopUpdatingLocation()
        manager.startUpdatingLocation()
        
        // 设置一个安全超时，防止一直转圈
        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(20))
            if !Task.isCancelled {
                await MainActor.run {
                    if self.isFetching {
                        print("Location request timed out.")
                        self.manager.stopUpdatingLocation()
                        self.isFetching = false
                        self.error = String(localized: "Location request timed out. Please try again.", comment: "Error message for location timeout")
                    }
                }
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        if let first = locations.last {
            manager.stopUpdatingLocation()
            
            Task {
                await MainActor.run {
                    self.timeoutTask?.cancel()
                    self.timeoutTask = nil
                }
                let lat = first.coordinate.latitude
                let lon = first.coordinate.longitude
                
                var addressString: String? = nil
                do {
                    let geocoder = CLGeocoder()
                    let placemarks = try await geocoder.reverseGeocodeLocation(first)
                    if let placemark = placemarks.first {
                        // 尝试整合地址信息
                        let poi = placemark.areasOfInterest?.first
                        let name = poi ?? placemark.name
                        let thoroughfare = placemark.thoroughfare
                        let subLocality = placemark.subLocality
                        let locality = placemark.locality
                        
                        var parts: [String] = []
                        
                        // 1. 优先地标名/POI
                        if let n = name { parts.append(n) }
                        
                        // 2. 如果地标名和街道名不同，加入街道
                        if let t = thoroughfare, t != name { parts.append(t) }
                        
                        // 3. 加入区域名
                        if let sl = subLocality, sl != name, sl != thoroughfare { parts.append(sl) }
                        
                        // 4. 加入城市名
                        if let l = locality, l != name { parts.append(l) }
                        
                        if !parts.isEmpty {
                            // 去重并合并
                            let uniqueParts = NSOrderedSet(array: parts).array as! [String]
                            addressString = uniqueParts.prefix(3).joined(separator: ", ")
                        }
                    }
                } catch {
                    print("Reverse geocoding failed: \(error.localizedDescription)")
                }

                await MainActor.run {
                    self.location = Location(
                        placeholder: addressString,
                        latitude: lat,
                        longitude: lon
                    )
                    self.isFetching = false
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        
        Task { @MainActor in
            if nsError.domain == kCLErrorDomain && nsError.code == 0 {
                // Location unknown - startUpdatingLocation will keep trying.
                print("Location unknown, still searching...")
                return
            }
            
            // 停止更新并报错
            self.timeoutTask?.cancel()
            self.timeoutTask = nil
            self.manager.stopUpdatingLocation()
            
            let description = error.localizedDescription
            print("Location manager failed: \(description)")
            self.error = description
            self.isFetching = false
        }
    }
    
    func clear() {
        timeoutTask?.cancel()
        timeoutTask = nil
        location = nil
        error = nil
        isFetching = false
        lastRequestID = nil
        manager.stopUpdatingLocation()
    }
}
