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

// MARK: - Responses API Models

struct ResponsesRequest: Codable {
    let model: String
    let input: String
    let text: TextConfig?
    let reasoning: ReasoningConfig?

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case text
        case reasoning
    }

    init(model: String = "gpt-5",
         input: String,
         verbosity: VerbosityLevel? = nil,
         reasoningEffort: ReasoningEffort? = nil) {
        self.model = model
        self.input = input
        self.text = verbosity.map { TextConfig(verbosity: $0) }
        self.reasoning = reasoningEffort.map { ReasoningConfig(effort: $0) }
    }
}

struct TextConfig: Codable {
    let verbosity: VerbosityLevel
}

struct ReasoningConfig: Codable {
    let effort: ReasoningEffort
}

enum VerbosityLevel: String, Codable {
    case low
    case medium
    case high
}

enum ReasoningEffort: String, Codable {
    case low
    case medium
    case high
}

struct ResponsesResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let output: String
    let usage: ResponseUsage?
    let metadata: ResponseMetadata?
}

struct ResponseUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let reasoningTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case reasoningTokens = "reasoning_tokens"
        case totalTokens = "total_tokens"
    }
}

struct ResponseMetadata: Codable {
    let reasoning: String?
    let confidence: Double?
    let processingTime: Double?

    enum CodingKeys: String, CodingKey {
        case reasoning
        case confidence
        case processingTime = "processing_time"
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
    static let responsesEndpoint = "/responses"
    static let defaultModel = "gpt-5"
    static let defaultTemperature = 0.7
    static let defaultMaxTokens = 1000

    // Model variants
    static let modelGPT5 = "gpt-5"
    static let modelGPT5Mini = "gpt-5-mini"
    static let modelGPT5Nano = "gpt-5-nano"
}