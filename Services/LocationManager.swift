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
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        location = nil // 重置之前的定位，确保能触发 onChange
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
        if let first = locations.first {
            Task {
                let lat = first.coordinate.latitude
                let lon = first.coordinate.longitude
                
                var addressString: String? = nil
                do {
                    let geocoder = CLGeocoder()
                    let placemarks = try await geocoder.reverseGeocodeLocation(first)
                    if let placemark = placemarks.first {
                        // 优先获取地标名称/道路名称
                        let name = placemark.name ?? placemark.thoroughfare
                        let locality = placemark.locality ?? placemark.administrativeArea
                        
                        if let name = name {
                            if let locality = locality, name != locality {
                                addressString = "\(name), \(locality)"
                            } else {
                                addressString = name
                            }
                        } else {
                            addressString = locality
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
