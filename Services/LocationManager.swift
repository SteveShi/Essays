import Foundation
import CoreLocation

import Observation

@MainActor
@Observable
class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    var location: Location?
    var isFetching = false
    var error: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest // 提高精度以更好地解析 POI
    }

    func requestLocation() {
        location = nil // 重置之前的定位
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
        
        manager.requestLocation()
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
    ) {
        if let first = locations.last { // 使用最新的定位点
            Task {
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
        let description = error.localizedDescription
        Task { @MainActor in
            print("Location manager failed: \(description)")
            self.error = description
            self.isFetching = false
        }
    }
}
