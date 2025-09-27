import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class OpenAIClient {
    static let shared = OpenAIClient()

    private let environmentService = EnvironmentService.shared
    private let session: URLSession
    private var apiKey: String?

    private static var isInitialized = false

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: configuration)

        // Prevent duplicate initialization logs
        if !Self.isInitialized {
            B2BLog.ai.debug("OpenAIClient initialized (singleton)")
            Self.isInitialized = true
        }
        loadAPIKey()
    }

    private func loadAPIKey() {
        apiKey = environmentService.getOpenAIKey()
        if apiKey != nil {
            B2BLog.ai.info("OpenAI API key loaded successfully")
        } else {
            B2BLog.ai.error("Failed to load OpenAI API key")
        }
    }

    // MARK: - Public Methods

    func responses(request: ResponsesRequest) async throws -> ResponsesResponse {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            B2BLog.ai.error("API key missing when attempting responses API call")
            throw OpenAIError.apiKeyMissing
        }

        let urlString = OpenAIConstants.baseURL + OpenAIConstants.responsesEndpoint
        guard let url = URL(string: urlString) else {
            B2BLog.ai.error("Invalid URL: \(urlString)")
            throw OpenAIError.invalidURL
        }

        B2BLog.network.debug("🌐 API: POST \(urlString)")
        B2BLog.ai.debug("Model: \(request.model), Input length: \(request.input.count) characters")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            B2BLog.ai.error("❌ Failed to encode request: \(error.localizedDescription)")
            throw OpenAIError.encodingError(error)
        }

        do {
            let startTime = Date()
            let (data, response) = try await session.data(for: urlRequest)
            let elapsedTime = Date().timeIntervalSince(startTime)

            B2BLog.network.debug("⏱️ OpenAI API Response Time: \(elapsedTime)")

            guard let httpResponse = response as? HTTPURLResponse else {
                B2BLog.ai.error("Invalid response type")
                throw OpenAIError.invalidResponse
            }

            B2BLog.ai.debug("HTTP Status Code: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                do {
                    let decoder = JSONDecoder()
                    let responsesResponse = try decoder.decode(ResponsesResponse.self, from: data)

                    if let usage = responsesResponse.usage {
                        B2BLog.ai.debug("Tokens used - Input: \(usage.inputTokens), Output: \(usage.outputTokens), Reasoning: \(usage.reasoningTokens), Total: \(usage.totalTokens)")
                    }

                    B2BLog.ai.info("Responses API call successful")
                    return responsesResponse
                } catch {
                    B2BLog.ai.error("❌ Failed to decode success response: \(error.localizedDescription)")
                    throw OpenAIError.decodingError(error)
                }

            case 401:
                B2BLog.ai.error("Unauthorized - Invalid API key")
                throw OpenAIError.unauthorized

            case 429:
                B2BLog.ai.warning("Rate limit exceeded")
                throw OpenAIError.rateLimitExceeded

            default:
                // Try to decode error message
                if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                    B2BLog.ai.error("API Error: \(errorResponse.error.message)")
                    throw OpenAIError.apiError(errorResponse.error.message)
                } else {
                    let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                    B2BLog.ai.error("HTTP Error \(httpResponse.statusCode): \(message)")
                    throw OpenAIError.httpError(statusCode: httpResponse.statusCode, message: message)
                }
            }
        } catch let error as OpenAIError {
            throw error
        } catch {
            B2BLog.ai.error("❌ Network error: \(error.localizedDescription)")
            throw OpenAIError.networkError(error)
        }
    }

    // MARK: - Convenience Methods

    func simpleCompletion(prompt: String, model: String = OpenAIConstants.defaultModel) async throws -> String {
        let request = ResponsesRequest(
            model: model,
            input: prompt,
            verbosity: .medium,
            reasoningEffort: .medium
        )

        let response = try await responses(request: request)
        return response.output
    }

    func personaBasedRecommendation(persona: String, context: String) async throws -> String {
        let input = """
        You are a DJ assistant helping to select the next song in a back-to-back DJ session.
        Respond in the style of \(persona) and provide a song recommendation based on the following context:

        \(context)
        """

        let request = ResponsesRequest(
            model: OpenAIConstants.defaultModel,
            input: input,
            verbosity: .high,
            reasoningEffort: .high
        )

        B2BLog.ai.info("Requesting song recommendation from persona: \(persona)")

        let response = try await responses(request: request)

        B2BLog.ai.info("Received recommendation from \(persona)")
        return response.output
    }

    // MARK: - Configuration

    var isConfigured: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }

    func reloadConfiguration() {
        B2BLog.ai.debug("Reloading OpenAI configuration")
        loadAPIKey()
    }
}