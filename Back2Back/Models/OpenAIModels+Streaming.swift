import Foundation

// MARK: - Streaming Event Types

enum StreamEventType: String, Codable, CustomStringConvertible {
    case responseCreated = "response.created"
    case responseInProgress = "response.in_progress"
    case responseCompleted = "response.completed"
    case responseError = "response.error"
    case responseOutputItemAdded = "response.output_item.added"
    case responseOutputItemDone = "response.output_item.done"
    case responseContentPartAdded = "response.content_part.added"
    case responseContentPartDone = "response.content_part.done"
    case outputTextDelta = "response.output_text.delta"
    case responseOutputTextAnnotationAdded = "response.output_text.annotation.added"
    case responseOutputTextDone = "response.output_text.done"
    case webSearchInProgress = "response.web_search_call.in_progress"
    case webSearchSearching = "response.web_search_call.searching"
    case webSearchCompleted = "response.web_search_call.completed"
    // Additional streaming events based on the API
    case responseOutput = "response.output"
    case responseReasoning = "response.reasoning"
    case responseContent = "response.content"
    case responseReasoningDelta = "response.reasoning.delta"
    case responseContentDelta = "response.content.delta"
    case responseDone = "response.done"
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        self = StreamEventType(rawValue: value) ?? .other
    }

    var description: String {
        switch self {
        case .other:
            return "other"
        default:
            return rawValue
        }
    }
}

// MARK: - Stream Event Models

struct StreamEventItem: Codable {
    let id: String
    let type: String
    let status: String?
    let summary: [String]?
    let action: StreamEventAction?
    let content: [ResponseContent]?
    let role: String?
}

struct StreamEventAction: Codable {
    let type: String
    let query: String?
    let sources: [WebSearchSource]?
}

struct StreamEventPart: Codable {
    let type: String
    let text: String?
    let annotations: [StreamEventAnnotation]?
    let logprobs: [String]?
}

struct StreamEventAnnotation: Codable {
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

struct StreamEventResponse: Codable {
    let id: String
    let object: String
    let createdAt: Double?
    let status: String
    let output: [ResponseOutputItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case object
        case createdAt = "created_at"
        case status
        case output
    }
}

struct StreamEvent: Codable {
    let type: StreamEventType
    let delta: String?
    let webSearchCallId: String?
    let results: WebSearchStreamResults?
    let error: StreamError?
    let output: [ResponseOutputItem]?
    let id: String?
    let object: String?
    let createdAt: Double?
    let model: String?
    let status: String?
    let usage: ResponseUsage?
    let sequenceNumber: Int?
    let outputIndex: Int?
    let contentIndex: Int?
    let annotationIndex: Int?
    let itemId: String?
    let item: StreamEventItem?
    let part: StreamEventPart?
    let annotation: StreamEventAnnotation?
    let response: StreamEventResponse?

    // Computed property to extract text delta from various fields
    var textDelta: String? {
        // First check the direct delta field
        if let delta = delta, !delta.isEmpty {
            return delta
        }

        // Then check if the part contains text
        if let partText = part?.text, !partText.isEmpty {
            return partText
        }

        return nil
    }

    enum CodingKeys: String, CodingKey {
        case type
        case delta
        case webSearchCallId = "web_search_call_id"
        case results
        case error
        case output
        case id
        case object
        case createdAt = "created_at"
        case model
        case status
        case usage
        case sequenceNumber = "sequence_number"
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case annotationIndex = "annotation_index"
        case itemId = "item_id"
        case item
        case part
        case annotation
        case response
    }
}

struct StreamError: Codable {
    let type: String
    let message: String
    let code: String?
    let param: String?
}

struct WebSearchStreamResults: Codable {
    let sources: [WebSearchSource]?
}

// MARK: - Streaming Event (High-level wrapper)

struct StreamingEvent {
    let type: StreamEventType
    let delta: String?
    let sources: [WebSearchSource]?
    let error: StreamError?
    let response: ResponsesResponse?
    let item: StreamEventItem?

    init(type: StreamEventType,
         delta: String? = nil,
         sources: [WebSearchSource]? = nil,
         error: StreamError? = nil,
         response: ResponsesResponse? = nil,
         item: StreamEventItem? = nil) {
        self.type = type
        self.delta = delta
        self.sources = sources
        self.error = error
        self.response = response
        self.item = item
    }
}

// MARK: - Web Search Models

struct WebSearchCall: Codable {
    let id: String?
    let type: String?
    let status: String?
    let action: WebSearchAction?

    init(action: WebSearchAction?) {
        self.id = nil
        self.type = nil
        self.status = nil
        self.action = action
    }
}

struct WebSearchAction: Codable {
    let type: String?
    let query: String?
    let sources: [WebSearchSource]?

    init(sources: [WebSearchSource]) {
        self.type = nil
        self.query = nil
        self.sources = sources
    }
}

struct WebSearchSource: Codable {
    let title: String?
    let url: String?
    let snippet: String?
}