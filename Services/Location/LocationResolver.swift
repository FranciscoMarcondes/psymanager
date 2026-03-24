import Foundation
import CoreLocation

final class LocationResolver: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var city = ""
    @Published var state = ""
    @Published var statusMessage = ""

    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func requestCurrentLocation() {
        statusMessage = "Solicitando localização..."
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusMessage = "Não foi possível obter localização atual."
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            statusMessage = "Localização indisponível no momento."
            return
        }

        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            guard let place = placemarks?.first else {
                self.statusMessage = "Não foi possível resolver cidade/UF automaticamente."
                return
            }

            if let city = place.locality {
                self.city = city
            }

            if let state = place.administrativeArea {
                self.state = state
            }

            if !self.city.isEmpty && !self.state.isEmpty {
                self.statusMessage = "Localização obtida: \(self.city), \(self.state)."
            }
        }
    }
}
