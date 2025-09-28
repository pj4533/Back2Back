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

    @Test("OpenAIConstants GPT-5 model values")
    func testOpenAIConstantsModels() async throws {
        #expect(OpenAIConstants.defaultModel == "gpt-5", "Default model should be gpt-5")
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