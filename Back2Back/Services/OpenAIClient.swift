import Foundation
import Observation
import OSLog
import MusicKit

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
                // Log raw response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    B2BLog.ai.debug("Raw API response: \(jsonString)")
                } else {
                    B2BLog.ai.error("Unable to convert response data to string")
                }

                // Try to parse as JSON to see structure
                do {
                    if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                        B2BLog.ai.debug("Response keys: \(jsonObject.keys.sorted())")

                        // Log specific fields to understand structure
                        if let output = jsonObject["output"] {
                            B2BLog.ai.debug("Output type: \(type(of: output))")
                            if let outputArray = output as? [[String: Any]] {
                                B2BLog.ai.debug("Output is array with \(outputArray.count) items")
                                if let firstItem = outputArray.first {
                                    B2BLog.ai.debug("First output item keys: \(firstItem.keys.sorted())")
                                }
                            } else if let outputString = output as? String {
                                B2BLog.ai.debug("Output is string: \(outputString)")
                            }
                        }

                        if let outputText = jsonObject["output_text"] {
                            B2BLog.ai.debug("output_text type: \(type(of: outputText))")
                        }
                    }
                } catch {
                    B2BLog.ai.error("Failed to parse as JSON object: \(error)")
                }

                do {
                    let decoder = JSONDecoder()
                    let responsesResponse = try decoder.decode(ResponsesResponse.self, from: data)

                    if let usage = responsesResponse.usage {
                        let reasoningTokens = usage.outputTokensDetails?.reasoningTokens ?? 0
                        B2BLog.ai.debug("Tokens used - Input: \(usage.inputTokens), Output: \(usage.outputTokens), Reasoning: \(reasoningTokens), Total: \(usage.totalTokens)")
                    }

                    B2BLog.ai.info("Responses API call successful")
                    return responsesResponse
                } catch let decodingError as DecodingError {
                    // Detailed decoding error logging
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        B2BLog.ai.error("❌ Decoding failed - Missing key: '\(key.stringValue)'")
                        B2BLog.ai.error("Context: \(context.debugDescription)")
                        B2BLog.ai.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .valueNotFound(let type, let context):
                        B2BLog.ai.error("❌ Decoding failed - Missing value for type: \(type)")
                        B2BLog.ai.error("Context: \(context.debugDescription)")
                        B2BLog.ai.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .typeMismatch(let type, let context):
                        B2BLog.ai.error("❌ Decoding failed - Type mismatch. Expected: \(type)")
                        B2BLog.ai.error("Context: \(context.debugDescription)")
                        B2BLog.ai.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        B2BLog.ai.error("❌ Decoding failed - Data corrupted")
                        B2BLog.ai.error("Context: \(context.debugDescription)")
                        B2BLog.ai.error("Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        B2BLog.ai.error("❌ Unknown decoding error: \(decodingError.localizedDescription)")
                    }
                    throw OpenAIError.decodingError(decodingError)
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

    func simpleCompletion(prompt: String, model: String = "gpt-5") async throws -> String {
        let request = ResponsesRequest(
            model: model,
            input: prompt,
            verbosity: .medium,
            reasoningEffort: .medium
        )

        let response = try await responses(request: request)
        return response.outputText
    }

    func personaBasedRecommendation(persona: String, context: String) async throws -> String {
        let input = """
        You are a DJ assistant helping to select the next song in a back-to-back DJ session.
        Respond in the style of \(persona) and provide a song recommendation based on the following context:

        \(context)
        """

        let request = ResponsesRequest(
            model: "gpt-5",
            input: input,
            verbosity: .high,
            reasoningEffort: .high
        )

        B2BLog.ai.info("Requesting song recommendation from persona: \(persona)")

        let response = try await responses(request: request)

        B2BLog.ai.info("Received recommendation from \(persona)")
        return response.outputText
    }

    // MARK: - Song Selection

    func selectNextSong(persona: String, sessionHistory: [SessionSong]) async throws -> SongRecommendation {
        B2BLog.ai.info("Requesting AI song selection with persona")

        let prompt = buildDJPrompt(persona: persona, history: sessionHistory)

        let songSelectionSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "artist": [
                    "type": "string",
                    "description": "The artist name"
                ],
                "song": [
                    "type": "string",
                    "description": "The song title"
                ],
                "rationale": [
                    "type": "string",
                    "description": "Brief explanation of selection",
                    "maxLength": 200
                ]
            ],
            "required": ["artist", "song", "rationale"],
            "additionalProperties": false
        ]

        let format = TextFormat(
            type: "json_schema",
            name: "song_selection",
            strict: true,
            schema: songSelectionSchema
        )

        let request = ResponsesRequest(
            model: "gpt-5",
            input: prompt,
            verbosity: .high,
            reasoningEffort: .high,
            format: format
        )

        do {
            let response = try await responses(request: request)
            let jsonData = response.outputText.data(using: .utf8)!
            let recommendation = try JSONDecoder().decode(SongRecommendation.self, from: jsonData)

            B2BLog.ai.info("AI selected: \(recommendation.song) by \(recommendation.artist)")
            B2BLog.ai.debug("Rationale: \(recommendation.rationale)")

            return recommendation
        } catch {
            B2BLog.ai.error("Failed to get AI song selection: \(error)")
            throw error
        }
    }

    private func buildDJPrompt(persona: String, history: [SessionSong]) -> String {
        var historyText = ""
        if !history.isEmpty {
            historyText = """

            Session history (in order played):
            \(formatSessionHistory(history))

            """
        }

        return """
        \(persona)
        \(historyText)
        Select the next song that:
        1. Complements the musical journey so far
        2. Reflects your DJ persona's taste
        3. Doesn't repeat any previous songs

        Respond with a JSON object containing:
        - artist: The artist name
        - song: The song title
        - rationale: A brief explanation (max 200 characters) of why you chose this song
        """
    }

    private func formatSessionHistory(_ history: [SessionSong]) -> String {
        history.enumerated().map { index, sessionSong in
            "\(index + 1). '\(sessionSong.song.title)' by \(sessionSong.song.artistName) [\(sessionSong.selectedBy.rawValue)]"
        }.joined(separator: "\n")
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

// MARK: - Song Recommendation Model

struct SongRecommendation: Codable {
    let artist: String
    let song: String
    let rationale: String
}