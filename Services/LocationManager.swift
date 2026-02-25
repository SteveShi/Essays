import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    @Published var location: Location?
    @Published var isFetching = false
    @Published var error: String?

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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let first = locations.first {
            DispatchQueue.main.async {
                self.location = Location(
                    latitude: first.coordinate.latitude,
                    longitude: first.coordinate.longitude
                )
                self.isFetching = false
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.error = error.localizedDescription
            self.isFetching = false
        }
    }
}
