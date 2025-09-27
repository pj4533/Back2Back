import Testing
@testable import Back2Back
import Foundation

@Suite("OpenAI Models Tests")
struct OpenAIModelsTests {

    @Test("ChatMessage Equatable conformance")
    func testChatMessageEquatable() async throws {
        let message1 = ChatMessage(role: .user, content: "Hello")
        let message2 = ChatMessage(role: .user, content: "Hello")
        let message3 = ChatMessage(role: .user, content: "Hello", name: "User")
        let message4 = ChatMessage(role: .assistant, content: "Hello")
        let message5 = ChatMessage(role: .user, content: "World")

        #expect(message1 == message2, "Same messages should be equal")
        #expect(message1 != message3, "Messages with different names should not be equal")
        #expect(message1 != message4, "Messages with different roles should not be equal")
        #expect(message1 != message5, "Messages with different content should not be equal")
    }

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

    @Test("ChatCompletionResponse with all fields")
    func testChatCompletionResponseComplete() async throws {
        let message = ChatMessage(role: .assistant, content: "Test response")
        let choice = ChatChoice(index: 0, message: message, finishReason: "stop")
        let usage = Usage(promptTokens: 10, completionTokens: 20, totalTokens: 30)

        let response = ChatCompletionResponse(
            id: "chatcmpl-123",
            object: "chat.completion",
            created: 1234567890,
            model: "gpt-3.5-turbo",
            choices: [choice],
            usage: usage
        )

        #expect(response.id == "chatcmpl-123", "ID should match")
        #expect(response.object == "chat.completion", "Object type should match")
        #expect(response.created == 1234567890, "Created timestamp should match")
        #expect(response.model == "gpt-3.5-turbo", "Model should match")
        #expect(response.choices.count == 1, "Should have one choice")
        #expect(response.usage?.totalTokens == 30, "Usage should be set")
    }

    @Test("ChatCompletionResponse without usage")
    func testChatCompletionResponseWithoutUsage() async throws {
        let message = ChatMessage(role: .assistant, content: "Test")
        let choice = ChatChoice(index: 0, message: message, finishReason: nil)

        let response = ChatCompletionResponse(
            id: "test-id",
            object: "chat.completion",
            created: 1234567890,
            model: "gpt-4",
            choices: [choice],
            usage: nil
        )

        #expect(response.usage == nil, "Usage should be nil")
        #expect(response.choices[0].finishReason == nil, "Finish reason should be nil")
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

    @Test("ChatMessage JSON encoding and decoding")
    func testChatMessageCodable() async throws {
        let originalMessage = ChatMessage(role: .user, content: "Test content", name: "TestUser")

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalMessage)

        let decoder = JSONDecoder()
        let decodedMessage = try decoder.decode(ChatMessage.self, from: data)

        #expect(decodedMessage.role == originalMessage.role, "Role should match after coding")
        #expect(decodedMessage.content == originalMessage.content, "Content should match after coding")
        #expect(decodedMessage.name == originalMessage.name, "Name should match after coding")
    }

    @Test("ChatCompletionRequest JSON encoding with snake_case")
    func testChatCompletionRequestEncoding() async throws {
        let request = ChatCompletionRequest(
            model: "gpt-4",
            messages: [ChatMessage(role: .user, content: "Hello")],
            temperature: 0.5,
            maxTokens: 100,
            stream: true,
            user: "user123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]

        #expect(json["model"] as? String == "gpt-4", "Model should be encoded")
        #expect(json["temperature"] as? Double == 0.5, "Temperature should be encoded")
        #expect(json["max_tokens"] as? Int == 100, "MaxTokens should use snake_case")
        #expect(json["stream"] as? Bool == true, "Stream should be encoded")
        #expect(json["user"] as? String == "user123", "User should be encoded")
    }

    @Test("Usage JSON decoding with snake_case")
    func testUsageDecoding() async throws {
        let json = """
        {
            "prompt_tokens": 15,
            "completion_tokens": 25,
            "total_tokens": 40
        }
        """

        let decoder = JSONDecoder()
        let usage = try decoder.decode(Usage.self, from: json.data(using: .utf8)!)

        #expect(usage.promptTokens == 15, "Should decode prompt_tokens")
        #expect(usage.completionTokens == 25, "Should decode completion_tokens")
        #expect(usage.totalTokens == 40, "Should decode total_tokens")
    }

    @Test("ChatChoice JSON decoding with snake_case")
    func testChatChoiceDecoding() async throws {
        let json = """
        {
            "index": 1,
            "message": {
                "role": "assistant",
                "content": "Response text"
            },
            "finish_reason": "length"
        }
        """

        let decoder = JSONDecoder()
        let choice = try decoder.decode(ChatChoice.self, from: json.data(using: .utf8)!)

        #expect(choice.index == 1, "Index should decode")
        #expect(choice.message.role == .assistant, "Message role should decode")
        #expect(choice.message.content == "Response text", "Message content should decode")
        #expect(choice.finishReason == "length", "Should decode finish_reason with snake_case")
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
}