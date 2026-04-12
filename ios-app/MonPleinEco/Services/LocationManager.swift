import Foundation
import CoreLocation

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isLocating = false

    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    // Silently attempts geolocation at startup — never throws, returns nil if unavailable.
    func locateForStartup() async -> CLLocationCoordinate2D? {
        // Already denied or restricted: give up immediately
        if authorizationStatus == .denied || authorizationStatus == .restricted {
            return nil
        }

        // Not yet determined: request permission and wait for the user's decision
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
            let status = await withCheckedContinuation { cont in
                self.authContinuation = cont
            }
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                return nil
            }
        }

        return try? await locateOnce()
    }

    // Used by the "locate me" button — throws on failure.
    func locateOnce() async throws -> CLLocationCoordinate2D {
        isLocating = true
        defer { isLocating = false }

        return try await withCheckedThrowingContinuation { cont in
            self.locationContinuation = cont
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location.coordinate
        locationContinuation?.resume(returning: location.coordinate)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        // Resume the startup authorization wait if pending
        if let cont = authContinuation {
            authContinuation = nil
            cont.resume(returning: manager.authorizationStatus)
        }
    }
}
