import Foundation
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

        let lat = coordinates.coordinate.latitude
        let lon = coordinates.coordinate.longitude

        // Use Open-Meteo free API (no key needed)
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&temperature_unit=fahrenheit&wind_speed_unit=mph&timezone=auto&forecast_days=3"

        guard let url = URL(string: urlString) else {
            return "Error: Could not build weather URL."
        }

        let (data, _) = try await URLSession.shared.data(from: url)

        guard let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = result["current"] as? [String: Any] else {
            return "Error: Could not parse weather data."
        }

        let temp = current["temperature_2m"] as? Double ?? 0
        let feelsLike = current["apparent_temperature"] as? Double ?? 0
        let humidity = current["relative_humidity_2m"] as? Double ?? 0
        let windSpeed = current["wind_speed_10m"] as? Double ?? 0
        let windDir = current["wind_direction_10m"] as? Double ?? 0
        let weatherCode = current["weather_code"] as? Int ?? 0

        let condition = Self.weatherDescription(for: weatherCode)
        let windCompass = Self.compassDirection(for: windDir)

        var parts: [String] = [
            "Current weather:",
            "Temperature: \(String(format: "%.0f", temp))°F (feels like \(String(format: "%.0f", feelsLike))°F)",
            "Conditions: \(condition)",
            "Humidity: \(String(format: "%.0f", humidity))%",
            "Wind: \(String(format: "%.0f", windSpeed)) mph \(windCompass)",
        ]

        // Add daily forecast
        if let daily = result["daily"] as? [String: Any],
           let maxTemps = daily["temperature_2m_max"] as? [Double],
           let minTemps = daily["temperature_2m_min"] as? [Double],
           let codes = daily["weather_code"] as? [Int],
           let times = daily["time"] as? [String] {

            parts.append("\nForecast:")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE"

            for i in 0..<min(3, maxTemps.count) {
                let dayName: String
                if let date = formatter.date(from: times[i]) {
                    dayName = dayFormatter.string(from: date)
                } else {
                    dayName = times[i]
                }
                let cond = Self.weatherDescription(for: codes[i])
                parts.append("\(dayName): \(cond), High \(String(format: "%.0f", maxTemps[i]))°F / Low \(String(format: "%.0f", minTemps[i]))°F")
            }
        }

        return parts.joined(separator: "\n")
    }

    private static func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }

    private static func compassDirection(for degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }
}
