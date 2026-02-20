import Foundation
import UIKit

struct TextMessageTool: ChatTool {
    let name = "send_text_message"
    let description = "Open the Messages app with a pre-filled recipient and message body. The user can review and send the message."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "phone_number": .object([
                "type": .string("string"),
                "description": .string("The phone number to send a message to")
            ]),
            "message": .object([
                "type": .string("string"),
                "description": .string("The message body to pre-fill")
            ])
        ]),
        "required": .array([.string("phone_number")])
    ])

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let phoneNumber = json["phone_number"] as? String else {
            return "Error: Please provide a phone number."
        }

        let message = json["message"] as? String ?? ""
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)

        var urlString = "sms:\(cleaned)"
        if !message.isEmpty, let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "&body=\(encoded)"
        }

        guard let url = URL(string: urlString) else {
            return "Error: Could not create message URL."
        }

        let canOpen = await MainActor.run {
            UIApplication.shared.canOpenURL(url)
        }
        guard canOpen else {
            return "Text messaging is not supported on this device."
        }

        await MainActor.run {
            UIApplication.shared.open(url)
        }

        return "Opening Messages to text \(phoneNumber)."
    }
}
