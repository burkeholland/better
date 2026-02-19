import SwiftUI

struct ModelPickerView: View {
    @Binding var selectedModel: String

    var body: some View {
        Picker("Model", selection: $selectedModel) {
            ForEach(Constants.Models.allTextModels, id: \.id) { model in
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(model.id)
            }
        }
        .pickerStyle(.navigationLink)
    }
}
