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
         reasoningEffort: ReasoningEffort? = nil,
         format: TextFormat? = nil) {
        self.model = model
        self.input = input
        self.text = (verbosity != nil || format != nil) ? TextConfig(verbosity: verbosity, format: format) : nil
        self.reasoning = reasoningEffort.map { ReasoningConfig(effort: $0) }
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

enum ReasoningEffort: String, Codable {
    case low
    case medium
    case high
}

struct ResponsesResponse: Codable {
    let id: String
    let object: String
    let createdAt: Double
    let model: String
    let output: [ResponseOutputItem]
    let status: String
    let usage: ResponseUsage?
    let metadata: [String: Any]?
    let reasoning: ResponseReasoning?
    let text: ResponseTextConfig?
    let temperature: Double?
    let topP: Double?
    let billing: ResponseBilling?

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case createdAt = "created_at"
        case model
        case output
        case status
        case usage
        case metadata
        case reasoning
        case text
        case temperature
        case topP = "top_p"
        case billing
    }

    // Custom decoding to handle metadata as [String: Any]
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        object = try container.decode(String.self, forKey: .object)
        createdAt = try container.decode(Double.self, forKey: .createdAt)
        model = try container.decode(String.self, forKey: .model)
        output = try container.decode([ResponseOutputItem].self, forKey: .output)
        status = try container.decode(String.self, forKey: .status)
        usage = try container.decodeIfPresent(ResponseUsage.self, forKey: .usage)
        // Skip metadata since it's a dictionary that we don't really need
        metadata = nil
        reasoning = try container.decodeIfPresent(ResponseReasoning.self, forKey: .reasoning)
        text = try container.decodeIfPresent(ResponseTextConfig.self, forKey: .text)
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature)
        topP = try container.decodeIfPresent(Double.self, forKey: .topP)
        billing = try container.decodeIfPresent(ResponseBilling.self, forKey: .billing)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(object, forKey: .object)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(model, forKey: .model)
        try container.encode(output, forKey: .output)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(usage, forKey: .usage)
        // Skip metadata for encoding
        try container.encodeIfPresent(reasoning, forKey: .reasoning)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(topP, forKey: .topP)
        try container.encodeIfPresent(billing, forKey: .billing)
    }

    // Computed property to get the text output
    var outputText: String {
        for item in output {
            switch item {
            case .message(let message):
                if let content = message.content {
                    for contentItem in content {
                        if contentItem.type == "output_text", let text = contentItem.text {
                            return text
                        }
                    }
                }
            case .reasoning:
                continue
            }
        }
        return ""
    }
}

// Enum to handle different types of output items
enum ResponseOutputItem: Codable {
    case reasoning(ResponseReasoningItem)
    case message(ResponseMessage)

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case summary
        case content
        case role
        case status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "reasoning":
            let id = try container.decode(String.self, forKey: .id)
            let summary = try container.decodeIfPresent([String].self, forKey: .summary) ?? []
            self = .reasoning(ResponseReasoningItem(id: id, type: type, summary: summary))
        case "message":
            let id = try container.decode(String.self, forKey: .id)
            let content = try container.decodeIfPresent([ResponseContent].self, forKey: .content)
            let role = try container.decode(String.self, forKey: .role)
            let status = try container.decodeIfPresent(String.self, forKey: .status)
            self = .message(ResponseMessage(id: id, type: type, content: content, role: role, status: status))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type,
                                                    in: container,
                                                    debugDescription: "Unknown output type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .reasoning(let item):
            try container.encode(item.type, forKey: .type)
            try container.encode(item.id, forKey: .id)
            try container.encode(item.summary, forKey: .summary)
        case .message(let message):
            try container.encode(message.type, forKey: .type)
            try container.encode(message.id, forKey: .id)
            try container.encodeIfPresent(message.content, forKey: .content)
            try container.encode(message.role, forKey: .role)
            try container.encodeIfPresent(message.status, forKey: .status)
        }
    }
}

struct ResponseReasoningItem: Codable {
    let id: String
    let type: String
    let summary: [String]
}

struct ResponseMessage: Codable {
    let id: String
    let type: String
    let content: [ResponseContent]?
    let role: String
    let status: String?
}

struct ResponseContent: Codable {
    let type: String
    let text: String?
    let annotations: [String]?
    let logprobs: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case annotations
        case logprobs
    }
}

struct ResponseReasoning: Codable {
    let effort: String?
    let summary: String?
}

struct ResponseTextConfig: Codable {
    let format: ResponseTextFormat?
    let verbosity: String?
}

struct TextFormat: Codable {
    let type: String
    let name: String?
    let strict: Bool?
    let schema: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case strict
        case schema
    }

    init(type: String = "json_schema", name: String? = nil, strict: Bool? = nil, schema: [String: Any]? = nil) {
        self.type = type
        self.name = name
        self.strict = strict
        self.schema = schema
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(strict, forKey: .strict)
        if let schema = schema {
            let jsonData = try JSONSerialization.data(withJSONObject: schema, options: [])
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                try container.encode(AnyEncodable(jsonObject), forKey: .schema)
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        strict = try container.decodeIfPresent(Bool.self, forKey: .strict)
        schema = nil // We don't need to decode schema for responses
    }
}

// Helper struct for encoding Any types
struct AnyEncodable: Encodable {
    private let value: Any

    init(_ value: Any) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let intValue = value as? Int {
            try container.encode(intValue)
        } else if let doubleValue = value as? Double {
            try container.encode(doubleValue)
        } else if let boolValue = value as? Bool {
            try container.encode(boolValue)
        } else if let stringValue = value as? String {
            try container.encode(stringValue)
        } else if let arrayValue = value as? [Any] {
            try container.encode(arrayValue.map { AnyEncodable($0) })
        } else if let dictValue = value as? [String: Any] {
            try container.encode(dictValue.mapValues { AnyEncodable($0) })
        } else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Unsupported type"
            ))
        }
    }
}

struct ResponseTextFormat: Codable {
    let type: String
}

struct ResponseBilling: Codable {
    let payer: String
}

struct ResponseUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let inputTokensDetails: InputTokensDetails?
    let outputTokensDetails: OutputTokensDetails?
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case inputTokensDetails = "input_tokens_details"
        case outputTokensDetails = "output_tokens_details"
        case totalTokens = "total_tokens"
    }
}

struct InputTokensDetails: Codable {
    let cachedTokens: Int

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
    }
}

struct OutputTokensDetails: Codable {
    let reasoningTokens: Int

    enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
    }
}

// Remove old ResponseMetadata since the actual API uses a generic dictionary

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