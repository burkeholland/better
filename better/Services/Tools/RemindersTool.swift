import Foundation
import EventKit

final class RemindersTool: ChatTool, @unchecked Sendable {
    let name = "create_reminder"
    let description = "Create a new reminder in the user's Reminders app. Use this when the user asks to be reminded about something."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "title": .object([
                "type": .string("string"),
                "description": .string("The reminder title/text")
            ]),
            "due_date": .object([
                "type": .string("string"),
                "description": .string("Optional due date in natural format like '2025-03-15' or 'tomorrow'. ISO 8601 format preferred.")
            ]),
            "notes": .object([
                "type": .string("string"),
                "description": .string("Optional additional notes for the reminder")
            ])
        ]),
        "required": .array([.string("title")])
    ])

    private let eventStore = EKEventStore()

    func execute(arguments: String) async throws -> String {
        let granted = try await eventStore.requestFullAccessToReminders()

        guard granted else {
            return "Reminders access is not authorized. Please enable reminders access in Settings."
        }

        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String else {
            return "Error: Please provide a reminder title."
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        if let notes = json["notes"] as? String {
            reminder.notes = notes
        }

        if let dueDateString = json["due_date"] as? String {
            if let date = parseDateString(dueDateString) {
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                reminder.dueDateComponents = components
            }
        }

        try eventStore.save(reminder, commit: true)

        var response = "✅ Reminder created: \"\(title)\""
        if let dueDate = reminder.dueDateComponents, let date = Calendar.current.date(from: dueDate) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            response += " (due \(formatter.string(from: date)))"
        }

        return response
    }

    private func parseDateString(_ string: String) -> Date? {
        // Try ISO 8601 first
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        if let date = isoFormatter.date(from: string) { return date }

        // Try common formats
        let formatter = DateFormatter()
        for format in ["yyyy-MM-dd", "MM/dd/yyyy", "yyyy-MM-dd'T'HH:mm:ss"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }

        // Try natural language
        let lower = string.lowercased()
        let calendar = Calendar.current
        let now = Date()
        if lower == "tomorrow" {
            return calendar.date(byAdding: .day, value: 1, to: now)
        } else if lower == "next week" {
            return calendar.date(byAdding: .day, value: 7, to: now)
        }

        return nil
    }
}
