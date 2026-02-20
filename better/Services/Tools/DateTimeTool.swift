import Foundation

struct DateTimeTool: ChatTool {
    let name = "get_current_datetime"
    let description = "Get the current date, time, timezone, and locale. Use this when the user asks about the current time, date, day of the week, or needs time-aware context."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([:]),
        "required": .array([])
    ])

    func execute(arguments: String) async throws -> String {
        let now = Date()
        let calendar = Calendar.current
        let timeZone = TimeZone.current

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        dateFormatter.timeZone = timeZone

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: now)
        let weekday = dateFormatter.weekdaySymbols[components.weekday! - 1]

        return """
        Date: \(dateFormatter.string(from: now))
        Day of week: \(weekday)
        Timezone: \(timeZone.identifier) (UTC\(timeZone.abbreviation() ?? ""))
        Locale: \(Locale.current.identifier)
        """
    }
}
