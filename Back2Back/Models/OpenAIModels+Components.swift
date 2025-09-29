import Foundation

// MARK: - Responses Response

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
    let webSearchCall: WebSearchCall?

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
        case webSearchCall = "web_search_call"
    }

    // Custom initializer for creating from streaming events
    init(id: String, object: String, createdAt: Double, model: String, output: [ResponseOutputItem],
         status: String, usage: ResponseUsage? = nil, metadata: [String: Any]? = nil,
         reasoning: ResponseReasoning? = nil, text: ResponseTextConfig? = nil,
         temperature: Double? = nil, topP: Double? = nil, billing: ResponseBilling? = nil,
         webSearchCall: WebSearchCall? = nil) {
        self.id = id
        self.object = object
        self.createdAt = createdAt
        self.model = model
        self.output = output
        self.status = status
        self.usage = usage
        self.metadata = metadata
        self.reasoning = reasoning
        self.text = text
        self.temperature = temperature
        self.topP = topP
        self.billing = billing
        self.webSearchCall = webSearchCall
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
        webSearchCall = try container.decodeIfPresent(WebSearchCall.self, forKey: .webSearchCall)
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
        try container.encodeIfPresent(webSearchCall, forKey: .webSearchCall)
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
            case .reasoning, .webSearchCall:
                continue
            }
        }
        return ""
    }
}

// MARK: - Output Items

enum ResponseOutputItem: Codable {
    case reasoning(ResponseReasoningItem)
    case message(ResponseMessage)
    case webSearchCall(ResponseWebSearchCall)

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case summary
        case content
        case role
        case status
        case action
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
        case "web_search_call":
            let id = try container.decode(String.self, forKey: .id)
            let status = try container.decodeIfPresent(String.self, forKey: .status)
            let action = try container.decodeIfPresent(WebSearchAction.self, forKey: .action)
            self = .webSearchCall(ResponseWebSearchCall(id: id, type: type, status: status, action: action))
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
        case .webSearchCall(let webSearch):
            try container.encode(webSearch.type, forKey: .type)
            try container.encode(webSearch.id, forKey: .id)
            try container.encodeIfPresent(webSearch.status, forKey: .status)
            try container.encodeIfPresent(webSearch.action, forKey: .action)
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

struct ResponseWebSearchCall: Codable {
    let id: String
    let type: String
    let status: String?
    let action: WebSearchAction?
}

struct ResponseContent: Codable {
    let type: String
    let text: String?
    let annotations: [ResponseAnnotation]?
    let logprobs: [String]?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case annotations
        case logprobs
    }
}

struct ResponseAnnotation: Codable {
    let type: String
    let startIndex: Int?
    let endIndex: Int?
    let title: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case type
        case startIndex = "start_index"
        case endIndex = "end_index"
        case title
        case url
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

struct ResponseTextFormat: Codable {
    let type: String
    let name: String?
    let strict: Bool?
    // Schema is not decoded, only used for encoding

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case strict
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        strict = try container.decodeIfPresent(Bool.self, forKey: .strict)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(strict, forKey: .strict)
    }
}

struct ResponseBilling: Codable {
    let reasoning: Double?
    let webSearch: Double?

    enum CodingKeys: String, CodingKey {
        case reasoning
        case webSearch = "web_search"
    }
}

struct ResponseUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
    let inputTokensDetails: InputTokensDetails?
    let outputTokensDetails: OutputTokensDetails?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
        case inputTokensDetails = "input_tokens_details"
        case outputTokensDetails = "output_tokens_details"
    }
}

struct InputTokensDetails: Codable {
    let cachedTokens: Int?

    enum CodingKeys: String, CodingKey {
        case cachedTokens = "cached_tokens"
    }
}

struct OutputTokensDetails: Codable {
    let reasoningTokens: Int?

    enum CodingKeys: String, CodingKey {
        case reasoningTokens = "reasoning_tokens"
    }
}

// MARK: - Helper Types

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

    init(type: String, name: String? = nil, strict: Bool? = nil, schema: [String: Any]? = nil) {
        self.type = type
        self.name = name
        self.strict = strict
        self.schema = schema
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        strict = try container.decodeIfPresent(Bool.self, forKey: .strict)
        // Skip decoding the schema as [String: Any]
        schema = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(strict, forKey: .strict)
        // We'll handle schema encoding through AnyEncodable if needed
        if let schema = schema {
            try container.encode(AnyEncodable(schema), forKey: .schema)
        }
    }
}

// AnyEncodable moved to OpenAIModels+Core.swift