import Foundation
import CoreLocation
import SwiftUI

/// Opt-in location for SOLAR pahar mode. Offline guardrail (non-negotiable): CoreLocation is
/// whenInUse, requested only from an explicit user action, the fix is rounded to 2 decimals
/// (~1 km) before storing, nothing ever leaves the device, and the fixed clock remains the
/// default — solar is an explicit mode. Manual lat/lon entry works with location denied.
@MainActor @Observable
final class SolarLocation: NSObject, CLLocationManagerDelegate {
    static let storageKey = "sggs_solar_coords"   // "lat,lon" rounded to 2 dp

    var coords: (lat: Double, lon: Double)?
    var denied = false
    var requesting = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        coords = Self.stored()
    }

    static func stored() -> (lat: Double, lon: Double)? {
        guard let s = UserDefaults.standard.string(forKey: storageKey) else { return nil }
        let parts = s.split(separator: ",")
        guard parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]),
              abs(lat) <= 90, abs(lon) <= 180 else { return nil }
        return (lat, lon)
    }

    static func store(lat: Double, lon: Double) {
        let r = { (x: Double) in (x * 100).rounded() / 100 }   // 2 dp ≈ 1 km — enough for sunrise
        UserDefaults.standard.set("\(r(lat)),\(r(lon))", forKey: storageKey)
    }

    func setManually(lat: Double, lon: Double) {
        guard abs(lat) <= 90, abs(lon) <= 180 else { return }
        Self.store(lat: lat, lon: lon)
        coords = Self.stored()
    }

    /// Explicit user action only — never called automatically.
    func requestOnce() {
        requesting = true
        denied = false
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: denied = true; requesting = false
        default: manager.requestLocation()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.requesting else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .denied, .restricted: self.denied = true; self.requesting = false
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let c = locations.last?.coordinate
        Task { @MainActor in
            defer { self.requesting = false }
            guard let c else { return }
            Self.store(lat: c.latitude, lon: c.longitude)   // rounded; raw fix never persisted
            self.coords = Self.stored()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.requesting = false }
    }
}
