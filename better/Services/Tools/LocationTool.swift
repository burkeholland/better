import Foundation
import CoreLocation

final class LocationTool: ChatTool, @unchecked Sendable {
    let name = "get_location"
    let description = "Get the user's current location including city, state/region, country, and coordinates. Use this when the user asks about their location, wants nearby recommendations, or needs location-aware context."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([:]),
        "required": .array([])
    ])

    func execute(arguments: String) async throws -> String {
        let location: CLLocation
        do {
            location = try await LocationFetcher.requestLocation()
        } catch let error as LocationFetcher.LocationError {
            return error.userMessage
        }

        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        if let placemark = placemarks.first {
            var parts: [String] = []
            if let name = placemark.name { parts.append("Location: \(name)") }
            if let city = placemark.locality { parts.append("City: \(city)") }
            if let state = placemark.administrativeArea { parts.append("State/Region: \(state)") }
            if let country = placemark.country { parts.append("Country: \(country)") }
            parts.append(String(format: "Coordinates: %.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude))
            return parts.joined(separator: "\n")
        }

        return String(format: "Coordinates: %.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }
}

/// Bridges CLLocationManager delegate callbacks to async/await.
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    enum LocationError: Error {
        case notAuthorized
        case failed(Error)
        case timeout

        var userMessage: String {
            switch self {
            case .notAuthorized:
                return "Location access is not authorized. Please enable location access in Settings to use this feature."
            case .failed(let error):
                return "Unable to determine current location: \(error.localizedDescription)"
            case .timeout:
                return "Unable to determine current location. Please try again."
            }
        }
    }

    private var continuation: CheckedContinuation<CLLocation, Error>?
    private let manager = CLLocationManager()

    @MainActor
    static func requestLocation() async throws -> CLLocation {
        let fetcher = LocationFetcher()
        return try await fetcher.fetch()
    }

    @MainActor
    private func fetch() async throws -> CLLocation {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
            // Wait for user to respond to permission dialog
            for _ in 0..<20 {
                try await Task.sleep(for: .milliseconds(500))
                let updated = manager.authorizationStatus
                if updated != .notDetermined { break }
            }
        }

        let currentStatus = manager.authorizationStatus
        guard currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways else {
            throw LocationError.notAuthorized
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: LocationError.failed(error))
        continuation = nil
    }
}
