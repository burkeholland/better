import SwiftUI

@Observable
final class AppState {
    var showSettings: Bool = false
    var hasAPIKey: Bool = false

    init() {
        hasAPIKey = KeychainService.loadAPIKey() != nil
    }

    func checkAPIKey() {
        hasAPIKey = KeychainService.loadAPIKey() != nil
    }

    // Models are now static in Constants.Models.allTextModels
    // No need to load dynamically from API
    func loadModels() async {
        // No-op - models are defined statically
    }
}
