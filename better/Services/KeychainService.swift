import Foundation
import Security

enum KeychainService {
    nonisolated static let defaultService = "com.postrboard.better"
    nonisolated static let defaultAccount = "openrouter-api-key"
    nonisolated static let legacyAccount = "gemini-api-key"

    nonisolated static func save(key: String, data: Data, service: String) -> Bool {
        _ = delete(key: key, service: service)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    nonisolated static func load(key: String, service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    nonisolated static func delete(key: String, service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    nonisolated static func saveAPIKey(_ key: String) -> Bool {
        guard let data = key.data(using: .utf8) else {
            return false
        }

        return save(key: defaultAccount, data: data, service: defaultService)
    }

    nonisolated static func loadAPIKey() -> String? {
        // Try current account name first
        if let data = load(key: defaultAccount, service: defaultService) {
            return String(data: data, encoding: .utf8)
        }

        // Migrate from legacy "gemini-api-key" account if present
        if let legacyData = load(key: legacyAccount, service: defaultService),
           let key = String(data: legacyData, encoding: .utf8) {
            let saved = save(key: defaultAccount, data: legacyData, service: defaultService)
            if saved {
                _ = delete(key: legacyAccount, service: defaultService)
            }
            return key
        }

        return nil
    }

    nonisolated static func deleteAPIKey() -> Bool {
        delete(key: defaultAccount, service: defaultService)
    }
}
