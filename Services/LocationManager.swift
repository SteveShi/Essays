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
        isFetching = true
        error = nil
        
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
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
                        let components = [
                            placemark.thoroughfare,
                            placemark.subThoroughfare,
                            placemark.locality,
                            placemark.administrativeArea,
                            placemark.postalCode,
                            placemark.country,
                        ].compactMap { $0 }.filter { !$0.isEmpty }

                        if !components.isEmpty {
                            addressString = components.joined(separator: ", ")
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
