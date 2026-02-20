import Foundation

// MARK: - JSON Value (for encoding tool parameter schemas)

/// A type-safe representation of JSON values that conforms to Encodable.
/// Used for encoding tool parameter schemas in API requests.
enum JSONValue: Sendable, Encodable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Tool Protocol

/// A tool that the AI model can invoke during a conversation.
/// Each tool defines its name, description, parameter schema, and execution logic.
@MainActor
protocol ChatTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parametersSchema: JSONValue { get }
    func execute(arguments: String) async throws -> String
}

// MARK: - Tool Call (received from model)

/// A completed tool call from the model, accumulated from streaming deltas.
struct ToolCall: Sendable {
    let id: String
    let functionName: String
    let arguments: String
}

// MARK: - Tool Definition (sent in request)

/// Tool definition sent in the API request's `tools` array.
struct ToolDefinition: Encodable, Sendable {
    let type: String
    let function: ToolFunctionDefinition

    init(tool: any ChatTool) {
        self.type = "function"
        self.function = ToolFunctionDefinition(
            name: tool.name,
            description: tool.description,
            parameters: tool.parametersSchema
        )
    }
}

struct ToolFunctionDefinition: Encodable, Sendable {
    let name: String
    let description: String
    let parameters: JSONValue
}
