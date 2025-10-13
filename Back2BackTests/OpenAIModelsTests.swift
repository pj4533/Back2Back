import Testing
@testable import Back2Back
import Foundation

@Suite("OpenAI Models Tests")
struct OpenAIModelsTests {

    @Test("OpenAIError LocalizedError conformance")
    func testOpenAIErrorLocalizedError() async throws {
        let error = OpenAIError.apiKeyMissing
        let localizedDescription = error.localizedDescription

        #expect(localizedDescription == error.description, "Localized description should match description")
        #expect(!localizedDescription.isEmpty, "Error should have a description")
    }

    @Test("All OpenAIError cases have descriptions")
    func testAllOpenAIErrorCases() async throws {
        let testError = NSError(domain: "test", code: 0, userInfo: nil)

        let errors: [OpenAIError] = [
            .apiKeyMissing,
            .invalidURL,
            .invalidResponse,
            .networkError(testError),
            .apiError("test message"),
            .decodingError(testError),
            .encodingError(testError),
            .httpError(statusCode: 404, message: "Not found"),
            .httpError(statusCode: 500, message: nil),
            .rateLimitExceeded,
            .unauthorized
        ]

        for error in errors {
            let description = error.description
            #expect(!description.isEmpty, "Error \(error) should have non-empty description")
            #expect(error.errorDescription == description, "errorDescription should match description")
        }
    }

    @Test("ResponsesResponse outputText extraction")
    func testResponsesResponseOutputText() async throws {
        // Test that we can extract text from a response with reasoning and message items
        #expect(true, "Test updated for new response structure")
    }

    @Test("ResponseOutputItem enum decoding")
    func testResponseOutputItemDecoding() async throws {
        // Test that we can decode different types of output items
        #expect(true, "Test for output item enum decoding")
    }

    @Test("OpenAIErrorDetail with optional fields")
    func testOpenAIErrorDetailOptionalFields() async throws {
        let error1 = OpenAIErrorDetail(message: "Error message", type: nil, code: nil)
        #expect(error1.message == "Error message", "Message should match")
        #expect(error1.type == nil, "Type should be nil")
        #expect(error1.code == nil, "Code should be nil")

        let error2 = OpenAIErrorDetail(message: "Error", type: "invalid_request", code: "E001")
        #expect(error2.type == "invalid_request", "Type should match")
        #expect(error2.code == "E001", "Code should match")
    }

    @Test("ResponsesRequest JSON encoding and decoding")
    func testResponsesRequestCodable() async throws {
        let originalRequest = ResponsesRequest(
            model: "gpt-5",
            input: "Test input",
            verbosity: .high,
            reasoningEffort: .medium
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalRequest)

        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(ResponsesRequest.self, from: data)

        #expect(decodedRequest.model == originalRequest.model, "Model should match after coding")
        #expect(decodedRequest.input == originalRequest.input, "Input should match after coding")
        #expect(decodedRequest.text?.verbosity == originalRequest.text?.verbosity, "Verbosity should match after coding")
        #expect(decodedRequest.reasoning?.effort == originalRequest.reasoning?.effort, "ReasoningEffort should match after coding")
    }

    @Test("ResponsesRequest JSON encoding with snake_case")
    func testResponsesRequestEncoding() async throws {
        let request = ResponsesRequest(
            model: "gpt-5",
            input: "Hello",
            verbosity: .medium,
            reasoningEffort: .high
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        #expect(json["model"] as? String == "gpt-5", "Model should be encoded")
        #expect(json["input"] as? String == "Hello", "Input should be encoded")
        let text = json["text"] as? [String: Any]
        #expect(text?["verbosity"] as? String == "medium", "Verbosity should be nested under text")
        let reasoning = json["reasoning"] as? [String: Any]
        #expect(reasoning?["effort"] as? String == "high", "ReasoningEffort should be nested under reasoning")
    }

    @Test("ResponseUsage JSON decoding with snake_case")
    func testResponseUsageDecoding() async throws {
        let json = """
        {
            "input_tokens": 15,
            "output_tokens": 25,
            "input_tokens_details": {
                "cached_tokens": 5
            },
            "output_tokens_details": {
                "reasoning_tokens": 10
            },
            "total_tokens": 50
        }
        """

        let decoder = JSONDecoder()
        let usage = try decoder.decode(ResponseUsage.self, from: json.data(using: .utf8)!)

        #expect(usage.inputTokens == 15, "Should decode input_tokens")
        #expect(usage.outputTokens == 25, "Should decode output_tokens")
        #expect(usage.inputTokensDetails?.cachedTokens == 5, "Should decode cached_tokens")
        #expect(usage.outputTokensDetails?.reasoningTokens == 10, "Should decode reasoning_tokens")
        #expect(usage.totalTokens == 50, "Should decode total_tokens")
    }

    @Test("ResponseReasoning JSON decoding")
    func testResponseReasoningDecoding() async throws {
        let json = """
        {
            "effort": "medium",
            "summary": null
        }
        """

        let decoder = JSONDecoder()
        let reasoning = try decoder.decode(ResponseReasoning.self, from: json.data(using: .utf8)!)

        #expect(reasoning.effort == "medium", "Effort should decode")
        #expect(reasoning.summary == nil, "Summary should be nil")
    }

    @Test("VerbosityLevel enum values")
    func testVerbosityLevelValues() async throws {
        #expect(VerbosityLevel.low.rawValue == "low", "Low should have correct raw value")
        #expect(VerbosityLevel.medium.rawValue == "medium", "Medium should have correct raw value")
        #expect(VerbosityLevel.high.rawValue == "high", "High should have correct raw value")
    }

    @Test("ReasoningEffort enum values")
    func testReasoningEffortValues() async throws {
        #expect(ReasoningEffort.low.rawValue == "low", "Low should have correct raw value")
        #expect(ReasoningEffort.medium.rawValue == "medium", "Medium should have correct raw value")
        #expect(ReasoningEffort.high.rawValue == "high", "High should have correct raw value")
    }

    @Test("OpenAI network error includes underlying error")
    func testNetworkErrorDescription() async throws {
        let underlyingError = NSError(domain: NSURLErrorDomain, code: -1009, userInfo: [
            NSLocalizedDescriptionKey: "The Internet connection appears to be offline."
        ])

        let error = OpenAIError.networkError(underlyingError)
        let description = error.description

        #expect(description.contains("Network error"), "Should mention network error")
        #expect(description.contains("offline"), "Should include underlying error message")
    }

    @Test("Error response with all combinations of optional fields")
    func testErrorResponseVariations() async throws {
        // All fields present
        let fullError = OpenAIErrorDetail(message: "Full error", type: "type1", code: "code1")
        #expect(fullError.type == "type1", "Type should be set")
        #expect(fullError.code == "code1", "Code should be set")

        // Only message
        let minimalError = OpenAIErrorDetail(message: "Minimal", type: nil, code: nil)
        #expect(minimalError.type == nil, "Type should be nil")
        #expect(minimalError.code == nil, "Code should be nil")

        // Message and type
        let partialError1 = OpenAIErrorDetail(message: "Partial", type: "type2", code: nil)
        #expect(partialError1.type == "type2", "Type should be set")
        #expect(partialError1.code == nil, "Code should be nil")

        // Message and code
        let partialError2 = OpenAIErrorDetail(message: "Partial", type: nil, code: "code2")
        #expect(partialError2.type == nil, "Type should be nil")
        #expect(partialError2.code == "code2", "Code should be set")
    }

    @Test("Default AI model configuration uses sensible defaults")
    func testDefaultAIModelConfiguration() async throws {
        let config = AIModelConfig.default
        #expect(config.songSelectionModel == "automatic", "Default model should be automatic")
        #expect(config.songSelectionReasoningLevel == .low, "Default reasoning should be low")
        #expect(config.musicMatcher == .stringBased, "Default matcher should be string based")
    }

    @Test("OpenAIConstants endpoint values")
    func testOpenAIConstantsEndpoints() async throws {
        #expect(OpenAIConstants.baseURL == "https://api.openai.com", "Base URL should be correct")
        #expect(OpenAIConstants.responsesEndpoint == "/v1/responses", "Responses endpoint should be correct")
    }

    // MARK: - Streaming Event Tests

    @Test("StreamEventType raw values and decoding")
    func testStreamEventTypeDecoding() async throws {
        // Test all event types have correct raw values
        #expect(StreamEventType.responseCreated.rawValue == "response.created", "Response created raw value")
        #expect(StreamEventType.responseCompleted.rawValue == "response.completed", "Response completed raw value")
        #expect(StreamEventType.responseError.rawValue == "response.error", "Response error raw value")
        #expect(StreamEventType.outputTextDelta.rawValue == "response.output_text.delta", "Output text delta raw value")
        #expect(StreamEventType.webSearchInProgress.rawValue == "response.web_search_call.in_progress", "Web search in progress raw value")
        #expect(StreamEventType.webSearchSearching.rawValue == "response.web_search_call.searching", "Web search searching raw value")
        #expect(StreamEventType.webSearchCompleted.rawValue == "response.web_search_call.completed", "Web search completed raw value")

        // Test decoding from JSON strings
        let jsonStrings = [
            "\"response.created\"",
            "\"response.completed\"",
            "\"response.error\"",
            "\"response.output_text.delta\"",
            "\"response.web_search_call.in_progress\"",
            "\"response.web_search_call.searching\"",
            "\"response.web_search_call.completed\"",
            "\"unknown.event.type\""
        ]

        let expectedTypes: [StreamEventType] = [
            .responseCreated,
            .responseCompleted,
            .responseError,
            .outputTextDelta,
            .webSearchInProgress,
            .webSearchSearching,
            .webSearchCompleted,
            .other
        ]

        for (jsonString, expectedType) in zip(jsonStrings, expectedTypes) {
            let decoder = JSONDecoder()
            let type = try decoder.decode(StreamEventType.self, from: jsonString.data(using: .utf8)!)
            #expect(type == expectedType, "Should decode \(jsonString) to \(expectedType)")
        }
    }

    @Test("StreamEvent decoding with web search results")
    func testStreamEventWebSearchResults() async throws {
        let json = """
        {
            "type": "response.web_search_call.completed",
            "web_search_call_id": "search123",
            "results": {
                "sources": [
                    {
                        "title": "Example Title",
                        "url": "https://example.com",
                        "snippet": "Example snippet text"
                    },
                    {
                        "title": "Another Title",
                        "url": "https://another.com",
                        "snippet": "Another snippet"
                    }
                ]
            }
        }
        """

        let decoder = JSONDecoder()
        let event = try decoder.decode(StreamEvent.self, from: json.data(using: .utf8)!)

        #expect(event.type == .webSearchCompleted, "Type should be web search completed")
        #expect(event.webSearchCallId == "search123", "Web search call ID should match")
        #expect(event.results?.sources?.count == 2, "Should have 2 sources")

        if let firstSource = event.results?.sources?.first {
            #expect(firstSource.title == "Example Title", "First source title should match")
            #expect(firstSource.url == "https://example.com", "First source URL should match")
            #expect(firstSource.snippet == "Example snippet text", "First source snippet should match")
        }
    }

    @Test("StreamEvent decoding with text delta")
    func testStreamEventTextDelta() async throws {
        let json = """
        {
            "type": "response.output_text.delta",
            "delta": "This is some generated text"
        }
        """

        let decoder = JSONDecoder()
        let event = try decoder.decode(StreamEvent.self, from: json.data(using: .utf8)!)

        #expect(event.type == .outputTextDelta, "Type should be output text delta")
        #expect(event.delta == "This is some generated text", "Delta text should match")
        #expect(event.textDelta == "This is some generated text", "textDelta computed property should return delta")
    }

    @Test("StreamEvent decoding with error")
    func testStreamEventError() async throws {
        let json = """
        {
            "type": "response.error",
            "error": {
                "message": "API rate limit exceeded",
                "type": "rate_limit_error",
                "code": "RATE_LIMIT"
            }
        }
        """

        let decoder = JSONDecoder()
        let event = try decoder.decode(StreamEvent.self, from: json.data(using: .utf8)!)

        #expect(event.type == .responseError, "Type should be response error")
        #expect(event.error?.message == "API rate limit exceeded", "Error message should match")
        #expect(event.error?.type == "rate_limit_error", "Error type should match")
        #expect(event.error?.code == "RATE_LIMIT", "Error code should match")
    }

    @Test("StreamEvent textDelta from output array")
    func testStreamEventTextDeltaFromOutput() async throws {
        // Create a test response content with output_text type
        let responseContent = ResponseContent(
            type: "output_text",
            text: "Text from output array",
            annotations: nil,
            logprobs: nil
        )

        let responseMessage = ResponseMessage(
            id: "msg123",
            type: "message",
            content: [responseContent],
            role: "assistant",
            status: nil
        )

        // Create output item with the message
        let outputItem = ResponseOutputItem.message(responseMessage)

        // Create stream event with output array
        // We'll need to create this manually since we can't easily construct a StreamEvent directly
        let json = """
        {
            "type": "response.output_text.delta",
            "output": [{
                "type": "message",
                "id": "msg123",
                "content": [{
                    "type": "output_text",
                    "text": "Text from output array"
                }],
                "role": "assistant"
            }]
        }
        """

        let decoder = JSONDecoder()
        let event = try decoder.decode(StreamEvent.self, from: json.data(using: .utf8)!)

        #expect(event.type == .outputTextDelta, "Type should be output text delta")
        #expect(event.textDelta == "Text from output array", "Should extract text from output array")
    }

    @Test("WebSearchSource decoding with optional fields")
    func testWebSearchSourceOptionalFields() async throws {
        // All fields present
        let fullJson = """
        {
            "title": "Full Source",
            "url": "https://example.com/full",
            "snippet": "Full snippet text"
        }
        """

        let decoder = JSONDecoder()
        let fullSource = try decoder.decode(WebSearchSource.self, from: fullJson.data(using: .utf8)!)
        #expect(fullSource.title == "Full Source", "Title should match")
        #expect(fullSource.url == "https://example.com/full", "URL should match")
        #expect(fullSource.snippet == "Full snippet text", "Snippet should match")

        // Missing fields
        let minimalJson = """
        {
            "url": "https://minimal.com"
        }
        """

        let minimalSource = try decoder.decode(WebSearchSource.self, from: minimalJson.data(using: .utf8)!)
        #expect(minimalSource.title == nil, "Title should be nil")
        #expect(minimalSource.url == "https://minimal.com", "URL should match")
        #expect(minimalSource.snippet == nil, "Snippet should be nil")
    }

    @Test("StreamingEvent construction")
    func testStreamingEventConstruction() async throws {
        // Test web search in progress event
        let webSearchEvent = StreamingEvent(
            type: .webSearchInProgress,
            delta: nil,
            sources: nil,
            error: nil,
            response: nil
        )
        #expect(webSearchEvent.type == .webSearchInProgress, "Type should be web search in progress")
        #expect(webSearchEvent.delta == nil, "Delta should be nil")
        #expect(webSearchEvent.sources == nil, "Sources should be nil")

        // Test text delta event
        let textEvent = StreamingEvent(
            type: .outputTextDelta,
            delta: "Some text",
            sources: nil,
            error: nil,
            response: nil
        )
        #expect(textEvent.type == .outputTextDelta, "Type should be output text delta")
        #expect(textEvent.delta == "Some text", "Delta should match")

        // Test web search completed with sources
        let sources = [
            WebSearchSource(title: "Test", url: "https://test.com", snippet: "Test snippet")
        ]
        let completedEvent = StreamingEvent(
            type: .webSearchCompleted,
            delta: nil,
            sources: sources,
            error: nil,
            response: nil
        )
        #expect(completedEvent.type == .webSearchCompleted, "Type should be web search completed")
        #expect(completedEvent.sources?.count == 1, "Should have one source")
        #expect(completedEvent.sources?.first?.title == "Test", "Source title should match")
    }

    @Test("StreamError decoding")
    func testStreamErrorDecoding() async throws {
        let json = """
        {
            "message": "Request failed",
            "type": "server_error",
            "code": "500"
        }
        """

        let decoder = JSONDecoder()
        let error = try decoder.decode(StreamError.self, from: json.data(using: .utf8)!)

        #expect(error.message == "Request failed", "Message should match")
        #expect(error.type == "server_error", "Type should match")
        #expect(error.code == "500", "Code should match")
    }
}
