import Foundation
import Contacts

final class ContactsTool: ChatTool, @unchecked Sendable {
    let name = "search_contacts"
    let description = "Search the user's contacts by name or relationship. Use this when the user mentions a person by name (e.g. 'John Smith') OR by relationship (e.g. 'mom', 'wife', 'dad', 'brother'). Always call this BEFORE make_phone_call or send_text_message if you only have a name, not a number."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "name": .object([
                "type": .string("string"),
                "description": .string("The name or relationship to search for (e.g. 'John', 'Mom', 'wife')")
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
            CNContactNicknameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactRelationsKey as CNKeyDescriptor,
        ]

        // First try searching by name
        var contacts = try contactStore.unifiedContacts(
            matching: CNContact.predicateForContacts(matchingName: name),
            keysToFetch: keysToFetch
        )

        // If no results, search all contacts for relationship matches (e.g. "mom", "wife")
        if contacts.isEmpty {
            let relationshipTerms: [String: [String]] = [
                "mother": [CNLabelContactRelationMother, CNLabelContactRelationParent],
                "mom": [CNLabelContactRelationMother, CNLabelContactRelationParent],
                "father": [CNLabelContactRelationFather, CNLabelContactRelationParent],
                "dad": [CNLabelContactRelationFather, CNLabelContactRelationParent],
                "wife": [CNLabelContactRelationSpouse, CNLabelContactRelationPartner],
                "husband": [CNLabelContactRelationSpouse, CNLabelContactRelationPartner],
                "spouse": [CNLabelContactRelationSpouse],
                "partner": [CNLabelContactRelationPartner],
                "brother": [CNLabelContactRelationBrother, CNLabelContactRelationSibling],
                "sister": [CNLabelContactRelationSister, CNLabelContactRelationSibling],
                "son": [CNLabelContactRelationSon, CNLabelContactRelationChild],
                "daughter": [CNLabelContactRelationDaughter, CNLabelContactRelationChild],
            ]

            let searchLower = name.lowercased()
            if let matchLabels = relationshipTerms[searchLower] {
                let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
                var relationshipMatches: [CNContact] = []

                try contactStore.enumerateContacts(with: fetchRequest) { contact, _ in
                    for relation in contact.contactRelations {
                        if matchLabels.contains(relation.label ?? "") {
                            relationshipMatches.append(contact)
                            return
                        }
                    }
                }
                contacts = relationshipMatches
            }

            // Also try nickname search if still empty
            if contacts.isEmpty {
                let fetchRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
                var nicknameMatches: [CNContact] = []
                let searchLower = name.lowercased()

                try contactStore.enumerateContacts(with: fetchRequest) { contact, _ in
                    if contact.nickname.lowercased().contains(searchLower) {
                        nicknameMatches.append(contact)
                    }
                }
                contacts = nicknameMatches
            }
        }

        if contacts.isEmpty {
            return "No contacts found matching '\(name)'. Try using their full name."
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
