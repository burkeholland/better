import Foundation
import WeatherKit
import CoreLocation

struct WeatherTool: ChatTool {
    let name = "get_weather"
    let description = "Get current weather conditions and forecast for a location. Defaults to the user's current location if no location is specified."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "location": .object([
                "type": .string("string"),
                "description": .string("Optional city name or address. If omitted, uses the user's current location.")
            ])
        ]),
        "required": .array([])
    ])

    func execute(arguments: String) async throws -> String {
        let json = (try? JSONSerialization.jsonObject(with: Data(arguments.utf8))) as? [String: Any]
        let locationQuery = json?["location"] as? String

        let coordinates: CLLocation
        if let locationQuery, !locationQuery.isEmpty {
            let geocoder = CLGeocoder()
            let placemarks = try await geocoder.geocodeAddressString(locationQuery)
            guard let loc = placemarks.first?.location else {
                return "Could not find location '\(locationQuery)'."
            }
            coordinates = loc
        } else {
            do {
                coordinates = try await LocationFetcher.requestLocation()
            } catch {
                return "Unable to determine current location. Try specifying a city name."
            }
        }

        let weatherService = WeatherService.shared
        let weather = try await weatherService.weather(for: coordinates)

        let current = weather.currentWeather
        let tempF = current.temperature.converted(to: .fahrenheit)
        let feelsLikeF = current.apparentTemperature.converted(to: .fahrenheit)

        var parts: [String] = [
            "Current weather:",
            "Temperature: \(String(format: "%.0f", tempF.value))°F (feels like \(String(format: "%.0f", feelsLikeF.value))°F)",
            "Conditions: \(current.condition.description)",
            "Humidity: \(String(format: "%.0f", current.humidity * 100))%",
            "Wind: \(String(format: "%.0f", current.wind.speed.converted(to: .milesPerHour).value)) mph \(current.wind.compassDirection.description)",
        ]

        // Add daily forecast
        let dailyForecast = weather.dailyForecast.prefix(3)
        if !dailyForecast.isEmpty {
            parts.append("\nForecast:")
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            for day in dailyForecast {
                let highF = day.highTemperature.converted(to: .fahrenheit)
                let lowF = day.lowTemperature.converted(to: .fahrenheit)
                parts.append("\(formatter.string(from: day.date)): \(day.condition.description), High \(String(format: "%.0f", highF.value))°F / Low \(String(format: "%.0f", lowF.value))°F")
            }
        }

        return parts.joined(separator: "\n")
    }
}
