import Testing
@testable import Back2Back
import Foundation

@Suite("OpenAIClient Tests")
@MainActor
struct OpenAIClientTests {

    @Test("OpenAIClient is a singleton")
    func testSingleton() async throws {
        let instance1 = OpenAIClient.shared
        let instance2 = OpenAIClient.shared

        #expect(instance1 === instance2, "OpenAIClient should return the same instance")
    }

    @Test("OpenAIClient throws apiKeyMissing when no API key is set")
    func testThrowsApiKeyMissingWhenNoKey() async throws {
        let client = OpenAIClient.shared

        // Only run this test if no API key is set
        if !client.isConfigured {
            let request = ChatCompletionRequest(
                model: "gpt-3.5-turbo",
                messages: [ChatMessage(role: .user, content: "Hello")]
            )

            await #expect(throws: OpenAIError.apiKeyMissing) {
                _ = try await client.chatCompletion(request: request)
            }
        }
    }

    @Test("ChatMessage initialization")
    func testChatMessageInitialization() async throws {
        let message = ChatMessage(role: .user, content: "Test content")

        #expect(message.role == .user, "Role should be user")
        #expect(message.content == "Test content", "Content should match")
        #expect(message.name == nil, "Name should be nil by default")
    }

    @Test("ChatMessage with name initialization")
    func testChatMessageWithName() async throws {
        let message = ChatMessage(role: .assistant, content: "Response", name: "TestBot")

        #expect(message.role == .assistant, "Role should be assistant")
        #expect(message.content == "Response", "Content should match")
        #expect(message.name == "TestBot", "Name should match")
    }

    @Test("ChatCompletionRequest initialization with defaults")
    func testChatCompletionRequestDefaults() async throws {
        let messages = [
            ChatMessage(role: .user, content: "Test")
        ]
        let request = ChatCompletionRequest(messages: messages)

        #expect(request.model == "gpt-3.5-turbo", "Should use default model")
        #expect(request.messages.count == 1, "Should have one message")
        #expect(request.temperature == nil, "Temperature should be nil by default")
        #expect(request.maxTokens == nil, "MaxTokens should be nil by default")
        #expect(request.stream == nil, "Stream should be nil by default")
        #expect(request.user == nil, "User should be nil by default")
    }

    @Test("ChatCompletionRequest initialization with custom values")
    func testChatCompletionRequestCustom() async throws {
        let messages = [
            ChatMessage(role: .system, content: "You are a helpful assistant"),
            ChatMessage(role: .user, content: "Hello")
        ]
        let request = ChatCompletionRequest(
            model: "gpt-4",
            messages: messages,
            temperature: 0.8,
            maxTokens: 500,
            stream: false,
            user: "test-user"
        )

        #expect(request.model == "gpt-4", "Model should match")
        #expect(request.messages.count == 2, "Should have two messages")
        #expect(request.temperature == 0.8, "Temperature should match")
        #expect(request.maxTokens == 500, "MaxTokens should match")
        #expect(request.stream == false, "Stream should be false")
        #expect(request.user == "test-user", "User should match")
    }

    @Test("ChatRole enum values")
    func testChatRoleValues() async throws {
        #expect(ChatRole.system.rawValue == "system", "System role should have correct raw value")
        #expect(ChatRole.user.rawValue == "user", "User role should have correct raw value")
        #expect(ChatRole.assistant.rawValue == "assistant", "Assistant role should have correct raw value")
        #expect(ChatRole.function.rawValue == "function", "Function role should have correct raw value")
    }

    @Test("OpenAIError descriptions")
    func testOpenAIErrorDescriptions() async throws {
        let apiKeyError = OpenAIError.apiKeyMissing
        #expect(apiKeyError.description.contains("API key"), "Should mention API key")

        let invalidURLError = OpenAIError.invalidURL
        #expect(invalidURLError.description.contains("URL"), "Should mention URL")

        let rateLimitError = OpenAIError.rateLimitExceeded
        #expect(rateLimitError.description.contains("rate limit"), "Should mention rate limit")

        let unauthorizedError = OpenAIError.unauthorized
        #expect(unauthorizedError.description.contains("Unauthorized"), "Should mention unauthorized")

        let httpError = OpenAIError.httpError(statusCode: 500, message: "Server error")
        #expect(httpError.description.contains("500"), "Should include status code")
        #expect(httpError.description.contains("Server error"), "Should include message")
    }

    @Test("OpenAIConstants values")
    func testOpenAIConstants() async throws {
        #expect(OpenAIConstants.baseURL == "https://api.openai.com/v1", "Base URL should be correct")
        #expect(OpenAIConstants.chatCompletionsEndpoint == "/chat/completions", "Chat endpoint should be correct")
        #expect(OpenAIConstants.defaultModel == "gpt-3.5-turbo", "Default model should be gpt-3.5-turbo")
        #expect(OpenAIConstants.defaultTemperature == 0.7, "Default temperature should be 0.7")
        #expect(OpenAIConstants.defaultMaxTokens == 1000, "Default max tokens should be 1000")
    }

    @Test("isConfigured property")
    func testIsConfiguredProperty() async throws {
        let client = OpenAIClient.shared
        let environmentService = EnvironmentService.shared

        let hasApiKey = environmentService.getOpenAIKey() != nil
        #expect(client.isConfigured == hasApiKey, "isConfigured should match whether API key exists")
    }

    @Test("simpleCompletion requires API key")
    func testSimpleCompletionRequiresApiKey() async throws {
        let client = OpenAIClient.shared

        if !client.isConfigured {
            await #expect(throws: OpenAIError.apiKeyMissing) {
                _ = try await client.simpleCompletion(prompt: "Hello")
            }
        }
    }

    @Test("personaBasedRecommendation requires API key")
    func testPersonaBasedRecommendationRequiresApiKey() async throws {
        let client = OpenAIClient.shared

        if !client.isConfigured {
            await #expect(throws: OpenAIError.apiKeyMissing) {
                _ = try await client.personaBasedRecommendation(
                    persona: "Mark Ronson",
                    context: "Previous song was funk music"
                )
            }
        }
    }

    @Test("Usage model properties")
    func testUsageModel() async throws {
        let usage = Usage(promptTokens: 10, completionTokens: 20, totalTokens: 30)

        #expect(usage.promptTokens == 10, "Prompt tokens should match")
        #expect(usage.completionTokens == 20, "Completion tokens should match")
        #expect(usage.totalTokens == 30, "Total tokens should match")
    }

    @Test("ChatChoice model properties")
    func testChatChoiceModel() async throws {
        let message = ChatMessage(role: .assistant, content: "Response")
        let choice = ChatChoice(index: 0, message: message, finishReason: "stop")

        #expect(choice.index == 0, "Index should be 0")
        #expect(choice.message.content == "Response", "Message content should match")
        #expect(choice.finishReason == "stop", "Finish reason should match")
    }

    @Test("OpenAIErrorResponse model")
    func testOpenAIErrorResponseModel() async throws {
        let errorDetail = OpenAIErrorDetail(
            message: "Invalid request",
            type: "invalid_request_error",
            code: "invalid_api_key"
        )
        let errorResponse = OpenAIErrorResponse(error: errorDetail)

        #expect(errorResponse.error.message == "Invalid request", "Error message should match")
        #expect(errorResponse.error.type == "invalid_request_error", "Error type should match")
        #expect(errorResponse.error.code == "invalid_api_key", "Error code should match")
    }

    @Test("Multiple message types in request")
    func testMultipleMessageTypes() async throws {
        let messages = [
            ChatMessage(role: .system, content: "You are helpful"),
            ChatMessage(role: .user, content: "Hello"),
            ChatMessage(role: .assistant, content: "Hi there"),
            ChatMessage(role: .user, content: "How are you?")
        ]
        let request = ChatCompletionRequest(messages: messages)

        #expect(request.messages.count == 4, "Should have 4 messages")
        #expect(request.messages[0].role == .system, "First should be system")
        #expect(request.messages[1].role == .user, "Second should be user")
        #expect(request.messages[2].role == .assistant, "Third should be assistant")
        #expect(request.messages[3].role == .user, "Fourth should be user")
    }

    @Test("reloadConfiguration method")
    func testReloadConfiguration() async throws {
        let client = OpenAIClient.shared
        let initialConfigured = client.isConfigured

        // This should not crash
        client.reloadConfiguration()

        // Configuration status should remain the same if environment hasn't changed
        #expect(client.isConfigured == initialConfigured, "Configuration status should be consistent")
    }
}