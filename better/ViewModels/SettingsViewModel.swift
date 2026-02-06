import SwiftUI

@Observable
final class SettingsViewModel {
    var apiKey: String = ""
    var hasAPIKey: Bool = false
    var showAPIKey: Bool = false
    var saveSuccessful: Bool = false

    init() {
        hasAPIKey = KeychainService.loadAPIKey() != nil
    }

    func saveAPIKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let success = KeychainService.saveAPIKey(trimmed)
        if success {
            hasAPIKey = true
            saveSuccessful = true
            apiKey = ""
            Haptics.success()
        } else {
            Haptics.error()
        }
    }

    func deleteAPIKey() {
        _ = KeychainService.deleteAPIKey()
        hasAPIKey = false
        Haptics.medium()
    }

    func loadAPIKey() {
        if let key = KeychainService.loadAPIKey() {
            apiKey = key
        }
    }
}
