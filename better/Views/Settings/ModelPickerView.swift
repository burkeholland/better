import SwiftUI

struct ModelPickerView: View {
    @Binding var selectedModel: String
    @Environment(AppState.self) private var appState

    var body: some View {
        Picker("Model", selection: $selectedModel) {
            if appState.availableModels.isEmpty {
                // Fallback to hardcoded list
                ForEach(Constants.Models.all, id: \.id) { model in
                    Text(model.name)
                        .tag(model.id)
                }
            } else {
                ForEach(appState.availableModels) { model in
                    VStack(alignment: .leading) {
                        Text(model.displayName)
                    }
                    .tag(model.id)
                }
            }
        }
        .pickerStyle(.navigationLink)
        .task {
            if appState.availableModels.isEmpty {
                await appState.loadModels()
            }
        }
    }
}
