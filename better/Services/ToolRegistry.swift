import Foundation
import os

private let logger = Logger(subsystem: "com.postrboard.better", category: "ToolRegistry")

/// Manages registered tools and executes them by name.
@MainActor
final class ToolRegistry {
    private var tools: [String: any ChatTool] = [:]

    var definitions: [ToolDefinition] {
        tools.values.map { ToolDefinition(tool: $0) }
    }

    var isEmpty: Bool { tools.isEmpty }

    func register(_ tool: any ChatTool) {
        tools[tool.name] = tool
    }

    func execute(name: String, arguments: String) async -> String {
        guard let tool = tools[name] else {
            logger.warning("Unknown tool called: \(name)")
            return "Error: Unknown tool '\(name)'"
        }

        do {
            logger.info("Executing tool: \(name)")
            let result = try await tool.execute(arguments: arguments)
            logger.info("Tool \(name) succeeded")
            return result
        } catch {
            logger.error("Tool \(name) failed: \(error.localizedDescription)")
            return "Error executing \(name): \(error.localizedDescription)"
        }
    }
}
