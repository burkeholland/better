import Foundation
import Contacts

final class ContactsTool: ChatTool, @unchecked Sendable {
    let name = "search_contacts"
    let description = "Search the user's contacts by name. Use this when the user asks about a contact's phone number, email, or other details."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "name": .object([
                "type": .string("string"),
                "description": .string("The name to search for in contacts")
            ])
        ]),
        "required": .array([.string("name")])
    ])

    private let contactStore = CNContactStore()

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String else {
            return "Error: Please provide a name to search for."
        }

        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .notDetermined {
            let granted = try await contactStore.requestAccess(for: .contacts)
            guard granted else {
                return "Contacts access is not authorized. Please enable contacts access in Settings."
            }
        } else if status != .authorized {
            return "Contacts access is not authorized. Please enable contacts access in Settings."
        }

        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]

        let predicate = CNContact.predicateForContacts(matchingName: name)
        let contacts = try contactStore.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)

        if contacts.isEmpty {
            return "No contacts found matching '\(name)'."
        }

        var output: [String] = ["Found \(contacts.count) contact(s):\n"]
        for contact in contacts.prefix(5) {
            let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            output.append("👤 \(fullName)")

            for phone in contact.phoneNumbers {
                let label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: phone.label ?? "")
                output.append("  📞 \(label): \(phone.value.stringValue)")
            }

            for email in contact.emailAddresses {
                let label = CNLabeledValue<NSString>.localizedString(forLabel: email.label ?? "")
                output.append("  ✉️ \(label): \(email.value as String)")
            }
            output.append("")
        }

        if contacts.count > 5 {
            output.append("... and \(contacts.count - 5) more.")
        }

        return output.joined(separator: "\n")
    }
}
