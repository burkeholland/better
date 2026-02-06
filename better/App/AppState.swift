import SwiftUI

@Observable
final class AppState {
    var showSettings: Bool = false
    var hasAPIKey: Bool = false
    var availableModels: [GeminiModel] = []
    var isLoadingModels: Bool = false

    init() {
        hasAPIKey = KeychainService.loadAPIKey() != nil
    }

    func checkAPIKey() {
        hasAPIKey = KeychainService.loadAPIKey() != nil
    }

    func loadModels() async {
        guard hasAPIKey else { return }
        isLoadingModels = true
        defer { isLoadingModels = false }

        let client = GeminiAPIClient()
        do {
            let models = try await client.listModels()
            // Filter to generateContent-capable models and sort by name
            availableModels = models
                .filter { model in
                    model.supportedGenerationMethods?.contains("generateContent") ?? false
                }
                .map { model in
                    GeminiModel(
                        id: model.name.replacingOccurrences(of: "models/", with: ""),
                        displayName: model.displayName ?? model.name,
                        description: model.description ?? ""
                    )
                }
                .sorted { $0.displayName < $1.displayName }
        } catch {
            // Fall back to defaults if API call fails
            availableModels = Constants.Models.all.map {
                GeminiModel(id: $0.id, displayName: $0.name, description: $0.description)
            }
        }
    }
}

struct GeminiModel: Identifiable, Hashable {
    let id: String
    let displayName: String
    let description: String
}
