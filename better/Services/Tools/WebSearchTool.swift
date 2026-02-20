import Foundation

struct WebSearchTool: ChatTool {
    let name = "web_search"
    let description = "Search the internet for current information. Use this when the user asks about recent events, current data, or anything that requires up-to-date information beyond your training data."

    let parametersSchema: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object([
                "type": .string("string"),
                "description": .string("The search query")
            ])
        ]),
        "required": .array([.string("query")])
    ])

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = json["query"] as? String else {
            return "Error: Please provide a search query."
        }

        return try await performSearch(query: query)
    }

    private func performSearch(query: String) async throws -> String {
        guard let baseURL = URL(string: Constants.apiProxyBaseURL) else {
            return "Error: Invalid API URL configuration."
        }

        guard let url = URL(string: "search", relativeTo: baseURL) else {
            return "Error: Could not construct search URL."
        }

        // Get Firebase Auth token
        let token: String
        do {
            guard let user = FirebaseImport.currentUser else {
                return "Error: Not authenticated."
            }
            token = try await user.getIDToken()
        } catch {
            return "Error: Authentication failed."
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("search", forHTTPHeaderField: "X-OpenRouter-Path")

        let body: [String: Any] = ["query": query, "max_results": 5]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return "Web search is not available. The search service may not be configured."
        }

        guard let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = result["results"] as? [[String: Any]] else {
            return "No results found for '\(query)'."
        }

        var output: [String] = ["Search results for: \(query)\n"]
        for (i, item) in results.prefix(5).enumerated() {
            let title = item["title"] as? String ?? "Untitled"
            let content = item["content"] as? String ?? ""
            let url = item["url"] as? String ?? ""
            output.append("[\(i + 1)] \(title)")
            if !content.isEmpty {
                output.append(String(content.prefix(300)))
            }
            if !url.isEmpty {
                output.append("Source: \(url)")
            }
            output.append("")
        }

        return output.joined(separator: "\n")
    }
}

import FirebaseAuth

private enum FirebaseImport {
    static var currentUser: User? { Auth.auth().currentUser }
}
