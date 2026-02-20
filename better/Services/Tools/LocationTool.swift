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

    private let locationManager = CLLocationManager()

    func execute(arguments: String) async throws -> String {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Wait briefly for the user to respond to the permission dialog
            try await Task.sleep(for: .seconds(2))
        }

        let updatedStatus = locationManager.authorizationStatus
        guard updatedStatus == .authorizedWhenInUse || updatedStatus == .authorizedAlways else {
            return "Location access is not authorized. Please enable location access in Settings to use this feature."
        }

        guard let location = locationManager.location else {
            return "Unable to determine current location. Please try again."
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
