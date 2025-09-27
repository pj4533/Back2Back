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

    @Test("ResponsesResponse with all fields")
    func testResponsesResponseComplete() async throws {
        let usage = ResponseUsage(
            inputTokens: 10,
            outputTokens: 20,
            reasoningTokens: 5,
            totalTokens: 35
        )

        let metadata = ResponseMetadata(
            reasoning: "Test reasoning",
            confidence: 0.95,
            processingTime: 1.5
        )

        let response = ResponsesResponse(
            id: "resp-123",
            object: "response",
            created: 1234567890,
            model: "gpt-5-mini",
            output: "Test output",
            usage: usage,
            metadata: metadata
        )

        #expect(response.id == "resp-123", "ID should match")
        #expect(response.object == "response", "Object type should match")
        #expect(response.created == 1234567890, "Created timestamp should match")
        #expect(response.model == "gpt-5-mini", "Model should match")
        #expect(response.output == "Test output", "Output should match")
        #expect(response.usage?.totalTokens == 35, "Usage should be set")
        #expect(response.metadata?.confidence == 0.95, "Metadata should be set")
    }

    @Test("ResponsesResponse without optional fields")
    func testResponsesResponseMinimal() async throws {
        let response = ResponsesResponse(
            id: "test-id",
            object: "response",
            created: 1234567890,
            model: "gpt-5",
            output: "Test",
            usage: nil,
            metadata: nil
        )

        #expect(response.usage == nil, "Usage should be nil")
        #expect(response.metadata == nil, "Metadata should be nil")
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
            model: "gpt-5-mini",
            input: "Test input",
            verbosity: .high,
            reasoningEffort: .medium,
            maxTokens: 100,
            temperature: 0.8,
            user: "test-user"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalRequest)

        let decoder = JSONDecoder()
        let decodedRequest = try decoder.decode(ResponsesRequest.self, from: data)

        #expect(decodedRequest.model == originalRequest.model, "Model should match after coding")
        #expect(decodedRequest.input == originalRequest.input, "Input should match after coding")
        #expect(decodedRequest.verbosity == originalRequest.verbosity, "Verbosity should match after coding")
        #expect(decodedRequest.reasoning?.effort == originalRequest.reasoning?.effort, "ReasoningEffort should match after coding")
        #expect(decodedRequest.maxTokens == originalRequest.maxTokens, "MaxTokens should match after coding")
        #expect(decodedRequest.temperature == originalRequest.temperature, "Temperature should match after coding")
        #expect(decodedRequest.user == originalRequest.user, "User should match after coding")
    }

    @Test("ResponsesRequest JSON encoding with snake_case")
    func testResponsesRequestEncoding() async throws {
        let request = ResponsesRequest(
            model: "gpt-5",
            input: "Hello",
            verbosity: .medium,
            reasoningEffort: .high,
            maxTokens: 100,
            temperature: 0.5,
            user: "user123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        #expect(json["model"] as? String == "gpt-5", "Model should be encoded")
        #expect(json["input"] as? String == "Hello", "Input should be encoded")
        #expect(json["verbosity"] as? String == "medium", "Verbosity should be encoded")
        #expect(json["reasoning_effort"] as? String == "high", "ReasoningEffort should use snake_case")
        #expect(json["temperature"] as? Double == 0.5, "Temperature should be encoded")
        #expect(json["max_tokens"] as? Int == 100, "MaxTokens should use snake_case")
        #expect(json["user"] as? String == "user123", "User should be encoded")
    }

    @Test("ResponseUsage JSON decoding with snake_case")
    func testResponseUsageDecoding() async throws {
        let json = """
        {
            "input_tokens": 15,
            "output_tokens": 25,
            "reasoning_tokens": 10,
            "total_tokens": 50
        }
        """

        let decoder = JSONDecoder()
        let usage = try decoder.decode(ResponseUsage.self, from: json.data(using: .utf8)!)

        #expect(usage.inputTokens == 15, "Should decode input_tokens")
        #expect(usage.outputTokens == 25, "Should decode output_tokens")
        #expect(usage.reasoningTokens == 10, "Should decode reasoning_tokens")
        #expect(usage.totalTokens == 50, "Should decode total_tokens")
    }

    @Test("ResponseMetadata JSON decoding with snake_case")
    func testResponseMetadataDecoding() async throws {
        let json = """
        {
            "reasoning": "Test reasoning process",
            "confidence": 0.87,
            "processing_time": 2.5
        }
        """

        let decoder = JSONDecoder()
        let metadata = try decoder.decode(ResponseMetadata.self, from: json.data(using: .utf8)!)

        #expect(metadata.reasoning == "Test reasoning process", "Reasoning should decode")
        #expect(metadata.confidence == 0.87, "Confidence should decode")
        #expect(metadata.processingTime == 2.5, "Should decode processing_time with snake_case")
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

    @Test("OpenAIConstants GPT-5 model values")
    func testOpenAIConstantsModels() async throws {
        #expect(OpenAIConstants.defaultModel == "gpt-5-mini", "Default model should be gpt-5-mini")
        #expect(OpenAIConstants.modelGPT5 == "gpt-5", "GPT-5 constant should be correct")
        #expect(OpenAIConstants.modelGPT5Mini == "gpt-5-mini", "GPT-5 Mini constant should be correct")
        #expect(OpenAIConstants.modelGPT5Nano == "gpt-5-nano", "GPT-5 Nano constant should be correct")
    }

    @Test("OpenAIConstants endpoint values")
    func testOpenAIConstantsEndpoints() async throws {
        #expect(OpenAIConstants.baseURL == "https://api.openai.com/v1", "Base URL should be correct")
        #expect(OpenAIConstants.responsesEndpoint == "/responses", "Responses endpoint should be correct")
        #expect(OpenAIConstants.defaultTemperature == 0.7, "Default temperature should be correct")
        #expect(OpenAIConstants.defaultMaxTokens == 1000, "Default max tokens should be correct")
    }
}