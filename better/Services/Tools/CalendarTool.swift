import Foundation
import EventKit

final class CalendarTool: ChatTool, @unchecked Sendable {
    let name = "get_calendar_events"
    let description = "Get upcoming events from the user's calendar. Use this when the user asks about their schedule, meetings, or upcoming events."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "timeframe": .object([
                "type": .string("string"),
                "description": .string("Time range to search: today, tomorrow, this_week, or next_week"),
                "enum": .array([.string("today"), .string("tomorrow"), .string("this_week"), .string("next_week")])
            ])
        ]),
        "required": .array([])
    ])

    private let eventStore = EKEventStore()

    func execute(arguments: String) async throws -> String {
        let granted = try await eventStore.requestFullAccessToEvents()

        guard granted else {
            return "Calendar access is not authorized. Please enable calendar access in Settings."
        }

        let json = (try? JSONSerialization.jsonObject(with: Data(arguments.utf8))) as? [String: Any]
        let timeframe = (json?["timeframe"] as? String) ?? "today"

        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        let endDate: Date

        switch timeframe {
        case "tomorrow":
            startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        case "this_week":
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
        case "next_week":
            let nextWeekStart = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!
            startDate = nextWeekStart
            endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
        default: // today
            startDate = calendar.startOfDay(for: now)
            endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!
        }

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        if events.isEmpty {
            return "No events found for \(timeframe)."
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short

        var output = ["Events for \(timeframe) (\(events.count) found):\n"]
        for event in events {
            var line = "• \(event.title ?? "Untitled")"
            if event.isAllDay {
                line += " (All day)"
            } else {
                line += " — \(formatter.string(from: event.startDate)) to \(formatter.string(from: event.endDate))"
            }
            if let location = event.location, !location.isEmpty {
                line += "\n  📍 \(location)"
            }
            output.append(line)
        }

        return output.joined(separator: "\n")
    }
}
