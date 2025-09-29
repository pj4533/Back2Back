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

// MARK: - Constants

struct OpenAIConstants {
    static let baseURL = "https://api.openai.com"
    static let responsesEndpoint = "/v1/responses"
}

// MARK: - Core Request/Response Models

struct ResponsesRequest: Codable {
    let model: String
    let input: String
    let text: TextConfig?
    let reasoning: ReasoningConfig?
    let tools: [[String: String]]?
    let include: [String]?

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case text
        case reasoning
        case tools
        case include
    }

    init(model: String = "gpt-5",
         input: String,
         verbosity: VerbosityLevel? = nil,
         reasoningEffort: ReasoningEffort? = nil,
         format: TextFormat? = nil,
         tools: [[String: String]]? = nil,
         include: [String]? = nil) {
        self.model = model
        self.input = input
        self.text = (verbosity != nil || format != nil) ? TextConfig(verbosity: verbosity, format: format) : nil
        self.reasoning = reasoningEffort.map { ReasoningConfig(effort: $0) }
        self.tools = tools
        self.include = include
    }
}

struct TextConfig: Codable {
    let verbosity: VerbosityLevel?
    let format: TextFormat?

    init(verbosity: VerbosityLevel? = nil, format: TextFormat? = nil) {
        self.verbosity = verbosity
        self.format = format
    }
}

struct ReasoningConfig: Codable {
    let effort: ReasoningEffort
}

enum VerbosityLevel: String, Codable {
    case low
    case medium
    case high
}

enum ReasoningEffort: String, Codable, CaseIterable {
    case minimal
    case low
    case medium
    case high
}

// MARK: - Error Response Models

struct OpenAIErrorResponse: Codable {
    let error: OpenAIErrorDetail
}

struct OpenAIErrorDetail: Codable {
    let message: String
    let type: String?
    let param: String?
    let code: String?
}

// MARK: - Helper Types for Encoding

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: Any) {
        self._encode = { encoder in
            if let array = value as? [Any] {
                var container = encoder.unkeyedContainer()
                for item in array {
                    try container.encode(AnyEncodable(item))
                }
            } else if let dictionary = value as? [String: Any] {
                var container = encoder.container(keyedBy: AnyCodingKey.self)
                for (key, value) in dictionary {
                    try container.encode(AnyEncodable(value), forKey: AnyCodingKey(stringValue: key)!)
                }
            } else if let value = value as? String {
                var container = encoder.singleValueContainer()
                try container.encode(value)
            } else if let value = value as? Int {
                var container = encoder.singleValueContainer()
                try container.encode(value)
            } else if let value = value as? Double {
                var container = encoder.singleValueContainer()
                try container.encode(value)
            } else if let value = value as? Bool {
                var container = encoder.singleValueContainer()
                try container.encode(value)
            } else if value is NSNull {
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}