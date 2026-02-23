import Foundation

enum ClaudeAPIError: LocalizedError {
    case invalidAPIKey
    case rateLimited
    case networkError(String)
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            "Invalid API key. Please check your key in Settings > AI."
        case .rateLimited:
            "Rate limited. Please wait a moment and try again."
        case .networkError(let detail):
            "Network error: \(detail)"
        case .invalidResponse:
            "Could not parse API response."
        case .apiError(let detail):
            "API error: \(detail)"
        }
    }
}

@MainActor
@Observable
final class ClaudeAPIClient {
    static let shared = ClaudeAPIClient()

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func sendMessage(system: String, userMessage: String, model: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ClaudeAPIError.invalidAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": system,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClaudeAPIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw ClaudeAPIError.invalidAPIKey
        case 429:
            throw ClaudeAPIError.rateLimited
        default:
            if let errorBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorBody["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw ClaudeAPIError.apiError(message)
            }
            throw ClaudeAPIError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ClaudeAPIError.invalidResponse
        }

        return text
    }

    /// Quick test to verify the API key works
    func testConnection(apiKey: String, model: String) async throws -> Bool {
        let response = try await sendMessage(
            system: "Respond with exactly: OK",
            userMessage: "Test",
            model: model,
            apiKey: apiKey
        )
        return !response.isEmpty
    }
}
