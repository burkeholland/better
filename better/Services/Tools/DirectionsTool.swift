import Foundation
import MapKit

struct DirectionsTool: ChatTool {
    let name = "get_directions"
    let description = "Open Apple Maps with directions to a destination. Use this when the user asks for directions, how to get somewhere, or wants to navigate to a place."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "destination": .object([
                "type": .string("string"),
                "description": .string("The destination address or place name")
            ]),
            "mode": .object([
                "type": .string("string"),
                "description": .string("Travel mode: driving, walking, or transit"),
                "enum": .array([.string("driving"), .string("walking"), .string("transit")])
            ])
        ]),
        "required": .array([.string("destination")])
    ])

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let destination = json["destination"] as? String else {
            return "Error: Please provide a destination."
        }

        let mode = (json["mode"] as? String) ?? "driving"

        // Geocode the destination
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(destination)

        guard let placemark = placemarks.first, let location = placemark.location else {
            return "Could not find location for '\(destination)'. Try being more specific."
        }

        let mapItem = MKMapItem(placemark: MKPlacemark(placemark: placemark))
        mapItem.name = destination

        let launchOptions: [String: Any]
        switch mode {
        case "walking":
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        case "transit":
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit]
        default:
            launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        }

        await MainActor.run {
            mapItem.openInMaps(launchOptions: launchOptions)
        }

        let modeLabel = mode == "transit" ? "public transit" : mode
        return "Opening Apple Maps with \(modeLabel) directions to \(placemark.locality ?? destination)."
    }
}
