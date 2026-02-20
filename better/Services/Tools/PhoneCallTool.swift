import Foundation
import UIKit

struct PhoneCallTool: ChatTool {
    let name = "make_phone_call"
    let description = "Initiate a phone call to a given number. The user will see the Phone app with a confirmation before the call is placed."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "phone_number": .object([
                "type": .string("string"),
                "description": .string("The phone number to call")
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

        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        guard let url = URL(string: "tel:\(cleaned)") else {
            return "Error: Invalid phone number format."
        }

        let canOpen = await MainActor.run {
            UIApplication.shared.canOpenURL(url)
        }
        guard canOpen else {
            return "Phone calls are not supported on this device."
        }

        await MainActor.run {
            UIApplication.shared.open(url)
        }

        return "Opening Phone app to call \(phoneNumber)."
    }
}
