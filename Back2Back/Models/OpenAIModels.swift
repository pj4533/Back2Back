import Foundation

// MARK: - Error Types

enum OpenAIError: LocalizedError, CustomStringConvertible, Equatable {
    case apiKeyMissing
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case decodingError(Error)
    case encodingError(Error)
    case httpError(statusCode: Int, message: String?)
    case rateLimitExceeded
    case unauthorized

    static func == (lhs: OpenAIError, rhs: OpenAIError) -> Bool {
        switch (lhs, rhs) {
        case (.apiKeyMissing, .apiKeyMissing),
             (.invalidURL, .invalidURL),
             (.invalidResponse, .invalidResponse),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.unauthorized, .unauthorized):
            return true
        case (.apiError(let lhsMessage), .apiError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.httpError(let lhsCode, let lhsMessage), .httpError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.networkError(let lhsError), .networkError(let rhsError)),
             (.decodingError(let lhsError), .decodingError(let rhsError)),
             (.encodingError(let lhsError), .encodingError(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        default:
            return false
        }
    }

    var errorDescription: String? {
        description
    }

    var description: String {
        switch self {
        case .apiKeyMissing:
            return "OpenAI API key is missing. Please configure it in your environment variables."
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message ?? "Unknown error")"
        case .rateLimitExceeded:
            return "OpenAI API rate limit exceeded. Please try again later."
        case .unauthorized:
            return "Unauthorized. Please check your API key."
        }
    }
}

// MARK: - Chat Models

struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool?
    let user: String?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
        case user
    }

    init(model: String = "gpt-3.5-turbo",
         messages: [ChatMessage],
         temperature: Double? = nil,
         maxTokens: Int? = nil,
         stream: Bool? = nil,
         user: String? = nil) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
        self.user = user
    }
}

struct ChatMessage: Codable, Equatable {
    let role: ChatRole
    let content: String
    let name: String?

    init(role: ChatRole, content: String, name: String? = nil) {
        self.role = role
        self.content = content
        self.name = name
    }
}

enum ChatRole: String, Codable {
    case system
    case user
    case assistant
    case function
}

struct ChatCompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [ChatChoice]
    let usage: Usage?
}

struct ChatChoice: Codable {
    let index: Int
    let message: ChatMessage
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Error Response

struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetail
}

struct OpenAIErrorDetail: Codable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - Constants

struct OpenAIConstants {
    static let baseURL = "https://api.openai.com/v1"
    static let chatCompletionsEndpoint = "/chat/completions"
    static let defaultModel = "gpt-3.5-turbo"
    static let defaultTemperature = 0.7
    static let defaultMaxTokens = 1000
}