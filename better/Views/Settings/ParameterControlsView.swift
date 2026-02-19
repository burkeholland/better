import SwiftUI

struct ParameterControlsView: View {
    @Binding var conversation: Conversation

    var body: some View {
        Form {
            Section("Model") {
                ModelPickerView(selectedModel: $conversation.modelName)
            }

            Section("Generation Parameters") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.2f", conversation.temperature))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $conversation.temperature, in: 0...2, step: 0.05)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Top P")
                        Spacer()
                        Text(String(format: "%.2f", conversation.topP))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $conversation.topP, in: 0...1, step: 0.05)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Top K")
                        Spacer()
                        Text("\(conversation.topK)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: .init(get: { Double(conversation.topK) }, set: { conversation.topK = Int($0) }), in: 1...100, step: 1)
                }

                VStack(alignment: .leading) {
                    HStack {
                        Text("Max Output Tokens")
                        Spacer()
                        Text("\(conversation.maxOutputTokens)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: .init(get: { Double(conversation.maxOutputTokens) }, set: { conversation.maxOutputTokens = Int($0) }), in: 256...65536, step: 256)
                }
            }

            Section("System Instruction") {
                TextEditor(text: Binding(
                    get: { conversation.systemInstruction ?? "" },
                    set: { conversation.systemInstruction = $0.isEmpty ? nil : $0 }
                ))
                .frame(minHeight: 100)
            }
        }
        .navigationTitle("Chat Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
