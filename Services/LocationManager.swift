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
    
    private var retryCount = 0
    private let maxRetries = 2

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest // 提高精度以更好地解析 POI
    }

    func requestLocation() {
        location = nil // 重置之前的定位
        isFetching = true
        error = nil
        retryCount = 0 // 开始新请求时重置重试计数
        
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
                await MainActor.run {
                    self.retryCount = 0 // 成功获取位置，重置重试计数
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
            // kCLErrorDomain 0 (locationUnknown) 是临时性错误，尝试重试
            if nsError.domain == kCLErrorDomain && nsError.code == 0 && self.retryCount < self.maxRetries {
                self.retryCount += 1
                print("Location unknown, retrying (\(self.retryCount)/\(self.maxRetries))...")
                // 延迟一秒后重试
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if self.isFetching { // 确保用户没取消
                    self.manager.requestLocation()
                }
                return
            }
            
            let description: String
            if nsError.domain == kCLErrorDomain && nsError.code == 0 {
                description = String(localized: "Unable to retrieve location. Please try again in a few seconds.", comment: "Location unknown after retries")
            } else {
                description = error.localizedDescription
            }
            
            print("Location manager failed: \(description)")
            self.error = description
            self.isFetching = false
        }
    }
}
