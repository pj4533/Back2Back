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
        // Disable timeouts for AI generation - web search can take very long
        configuration.timeoutIntervalForRequest = 0  // No timeout
        configuration.timeoutIntervalForResource = 0  // No timeout
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

    // MARK: - Streaming Methods

    func streamingResponses(
        request: ResponsesRequest,
        onEvent: @escaping (StreamingEvent) async -> Void
    ) async throws -> ResponsesResponse {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            B2BLog.ai.error("API key missing when attempting streaming responses API call")
            throw OpenAIError.apiKeyMissing
        }

        let urlString = OpenAIConstants.baseURL + OpenAIConstants.responsesEndpoint
        guard let url = URL(string: urlString) else {
            B2BLog.ai.error("Invalid URL: \(urlString)")
            throw OpenAIError.invalidURL
        }

        B2BLog.network.debug("🌐 Streaming API: POST \(urlString)")
        B2BLog.ai.debug("Model: \(request.model), Input length: \(request.input.count) characters")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Note: Do NOT set Accept header for streaming - OpenAI handles this automatically

        // Create streaming request by adding stream parameter
        if let requestData = try? JSONEncoder().encode(request),
           var jsonObject = try? JSONSerialization.jsonObject(with: requestData, options: []) as? [String: Any] {
            jsonObject["stream"] = true
            let requestBody = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            urlRequest.httpBody = requestBody

            // Log the full request for debugging
            if let requestString = String(data: requestBody, encoding: .utf8) {
                B2BLog.ai.debug("Request body: \(requestString)")
            }
            // Log headers (but mask the API key)
            let maskedKey = apiKey.prefix(10) + "..." + apiKey.suffix(4)
            B2BLog.ai.debug("Authorization header: Bearer \(maskedKey)")
        } else {
            throw OpenAIError.encodingError(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create streaming request"]))
        }

        do {
            let startTime = Date()
            let (bytes, response) = try await session.bytes(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                B2BLog.ai.error("Invalid response type for streaming")
                throw OpenAIError.invalidResponse
            }

            B2BLog.ai.debug("Streaming HTTP Status Code: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                // Try to read error response body
                var errorMessage = "Streaming request failed"
                if httpResponse.statusCode == 400 {
                    // For 400 errors, try to read the error details
                    var errorBody = ""
                    do {
                        for try await line in bytes.lines {
                            errorBody += line + "\n"
                            // Limit reading to prevent hanging
                            if errorBody.count > 10000 {
                                break
                            }
                        }
                    } catch {
                        B2BLog.ai.warning("Failed to read error body: \(error)")
                    }

                    if !errorBody.isEmpty {
                        errorMessage = errorBody
                        B2BLog.ai.error("400 Error Response Body: \(errorBody)")

                        // Try to parse as JSON error
                        if let jsonData = errorBody.data(using: .utf8),
                           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                            B2BLog.ai.error("Parsed error JSON: \(jsonObject)")

                            if let error = jsonObject["error"] as? [String: Any],
                               let message = error["message"] as? String {
                                errorMessage = message
                            }
                        }
                    }
                }

                // Handle specific error cases
                if httpResponse.statusCode == 401 {
                    throw OpenAIError.unauthorized
                } else if httpResponse.statusCode == 429 {
                    throw OpenAIError.rateLimitExceeded
                } else {
                    throw OpenAIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
                }
            }

            var accumulatedText = ""
            var finalResponse: ResponsesResponse?
            var sources: [WebSearchSource] = []

            // Process the stream
            for try await line in bytes.lines {
                // Skip empty lines and non-data lines
                guard line.hasPrefix("data: ") else { continue }

                // Extract the JSON data after "data: "
                let jsonString = String(line.dropFirst(6))

                // Skip the [DONE] message
                if jsonString == "[DONE]" {
                    B2BLog.ai.debug("Stream completed")
                    break
                }

                // Parse the event
                guard let jsonData = jsonString.data(using: .utf8) else {
                    B2BLog.ai.warning("Failed to convert SSE line to data: \(jsonString)")
                    continue
                }

                do {
                    // First, let's check what type of event this is by parsing as generic JSON
                    if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                        let eventType = jsonObject["type"] as? String ?? "unknown"

                        // Log raw JSON for any event type we don't explicitly handle
                        let knownEventTypes = [
                            "response.created",
                            "response.completed",
                            "response.error",
                            "response.output_text.delta",
                            "response.web_search_call.in_progress",
                            "response.web_search_call.searching",
                            "response.web_search_call.completed"
                        ]

                        if !knownEventTypes.contains(eventType) {
                            // This is an unknown event type - log the complete raw JSON
                            B2BLog.ai.debug("Unknown stream event type: \(eventType)")
                            B2BLog.ai.debug("Full raw event JSON: \(jsonString)")
                            continue  // Skip processing this unknown event
                        }
                    }

                    // Now try to decode as a full ResponsesResponse (for response.completed events)
                    if let fullResponse = try? JSONDecoder().decode(ResponsesResponse.self, from: jsonData) {
                        finalResponse = fullResponse
                        B2BLog.ai.debug("Received full response in stream")

                        // Create a completed event
                        let event = StreamingEvent(
                            type: .responseCompleted,
                            delta: nil,
                            sources: sources.isEmpty ? nil : sources,
                            error: nil,
                            response: fullResponse
                        )
                        await onEvent(event)
                        continue
                    }

                    // Otherwise, try to decode as a stream event
                    let decoder = JSONDecoder()
                    let streamEvent = try decoder.decode(StreamEvent.self, from: jsonData)

                    // Process the event based on type
                    switch streamEvent.type {
                    case .webSearchInProgress:
                        B2BLog.ai.debug("🔎 Web search in progress")
                        let event = StreamingEvent(
                            type: .webSearchInProgress,
                            delta: nil,
                            sources: nil,
                            error: nil,
                            response: nil
                        )
                        await onEvent(event)

                    case .webSearchSearching:
                        B2BLog.ai.debug("🔎 Web search actively searching")
                        let event = StreamingEvent(
                            type: .webSearchSearching,
                            delta: nil,
                            sources: nil,
                            error: nil,
                            response: nil
                        )
                        await onEvent(event)

                    case .webSearchCompleted:
                        if let eventSources = streamEvent.results?.sources {
                            sources = eventSources
                            B2BLog.ai.debug("✅ Web search completed with \(sources.count) sources")
                        }
                        let event = StreamingEvent(
                            type: .webSearchCompleted,
                            delta: nil,
                            sources: sources.isEmpty ? nil : sources,
                            error: nil,
                            response: nil
                        )
                        await onEvent(event)

                    case .outputTextDelta:
                        if let textDelta = streamEvent.textDelta {
                            accumulatedText += textDelta
                            let event = StreamingEvent(
                                type: .outputTextDelta,
                                delta: textDelta,
                                sources: nil,
                                error: nil,
                                response: nil
                            )
                            await onEvent(event)
                        }

                    case .responseError:
                        B2BLog.ai.error("Stream error event received")
                        let event = StreamingEvent(
                            type: .responseError,
                            delta: nil,
                            sources: nil,
                            error: streamEvent.error,
                            response: nil
                        )
                        await onEvent(event)

                        if let error = streamEvent.error {
                            throw OpenAIError.apiError(error.message)
                        }

                    case .responseCreated:
                        B2BLog.ai.debug("Response created event")
                        let event = StreamingEvent(
                            type: .responseCreated,
                            delta: nil,
                            sources: nil,
                            error: nil,
                            response: nil
                        )
                        await onEvent(event)

                    case .responseCompleted:
                        B2BLog.ai.debug("Response completed event")
                        // Try to extract the full response from this event
                        if streamEvent.output != nil {
                            // Build a ResponsesResponse from the stream event data
                            let fullResponse = ResponsesResponse(
                                id: streamEvent.id ?? "resp_streaming",
                                object: streamEvent.object ?? "response",
                                createdAt: streamEvent.createdAt ?? Date().timeIntervalSince1970,
                                model: streamEvent.model ?? request.model,
                                output: streamEvent.output ?? [],
                                status: streamEvent.status ?? "completed",
                                usage: streamEvent.usage,
                                metadata: nil,
                                reasoning: nil,
                                text: nil,
                                temperature: nil,
                                topP: nil,
                                billing: nil,
                                webSearchCall: nil
                            )
                            finalResponse = fullResponse
                        }
                        let event = StreamingEvent(
                            type: .responseCompleted,
                            delta: nil,
                            sources: sources.isEmpty ? nil : sources,
                            error: nil,
                            response: finalResponse
                        )
                        await onEvent(event)

                    case .responseOutput, .responseReasoning, .responseContent:
                        // These are informational events, just log them
                        B2BLog.ai.debug("Stream event: \(streamEvent.type)")
                        // Also log the raw JSON to see what data they contain
                        B2BLog.ai.debug("Event raw JSON: \(jsonString)")

                    case .responseReasoningDelta, .responseContentDelta:
                        // These might contain additional text deltas
                        B2BLog.ai.debug("Stream delta event: \(streamEvent.type)")
                        B2BLog.ai.debug("Delta event raw JSON: \(jsonString)")
                        if let textDelta = streamEvent.textDelta {
                            accumulatedText += textDelta
                        }

                    default:
                        // This shouldn't happen now since we pre-filter unknown events
                        B2BLog.ai.debug("Unhandled stream event type: \(streamEvent.type)")
                        B2BLog.ai.debug("Unhandled event raw JSON: \(jsonString)")
                    }

                } catch {
                    B2BLog.ai.warning("Failed to decode stream event: \(error)")
                    B2BLog.ai.debug("Failed event raw JSON: \(jsonString)")
                }
            }

            let elapsedTime = Date().timeIntervalSince(startTime)
            B2BLog.network.debug("⏱️ Streaming API Response Time: \(elapsedTime)")

            // Return the final response or construct one from accumulated data
            if let finalResponse = finalResponse {
                B2BLog.ai.info("Streaming responses API call successful")
                return finalResponse
            } else if !accumulatedText.isEmpty {
                // Construct a response from the accumulated text
                B2BLog.ai.info("Constructing response from accumulated text")
                let outputContent = ResponseContent(
                    type: "output_text",
                    text: accumulatedText,
                    annotations: nil,
                    logprobs: nil
                )
                let message = ResponseMessage(
                    id: "msg_streaming",
                    type: "message",
                    content: [outputContent],
                    role: "assistant",
                    status: "completed"
                )
                let constructedResponse = ResponsesResponse(
                    id: "resp_streaming",
                    object: "response",
                    createdAt: Date().timeIntervalSince1970,
                    model: request.model,
                    output: [.message(message)],
                    status: "completed",
                    usage: nil,
                    metadata: nil,
                    reasoning: nil,
                    text: nil,
                    temperature: nil,
                    topP: nil,
                    billing: nil,
                    webSearchCall: WebSearchCall(action: sources.isEmpty ? nil : WebSearchAction(sources: sources))
                )
                return constructedResponse
            } else {
                // This should not happen in normal operation
                B2BLog.ai.error("No response data received from streaming API")
                throw OpenAIError.invalidResponse
            }

        } catch let error as OpenAIError {
            throw error
        } catch {
            B2BLog.ai.error("❌ Streaming network error: \(error.localizedDescription)")
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

    // MARK: - Persona Style Guide Generation

    func generatePersonaStyleGuide(
        name: String,
        description: String,
        onStatusUpdate: ((String) async -> Void)? = nil
    ) async throws -> PersonaGenerationResult {
        B2BLog.ai.info("Generating style guide for persona: \(name)")

        let prompt = """
        Generate a DJ persona style guide for making song selections based on this description:
        \(description)

        Research real information about this style/person/era using web search.

        This style guide will be used by an AI to select songs in a back-to-back DJ session.
        Format the guide to optimize song selection decisions.

        IMPORTANT: The persona description might be music-related OR completely unrelated to music:

        - For MUSIC-RELATED descriptions (genres, time periods, musicians, DJs):
          Create a style guide that DIRECTLY reflects those musical characteristics.
          Example: "1970s disco" → songs from that era and genre

        - For NON-MUSIC descriptions (scientists, historical figures, concepts, etc.):
          Create a style guide that captures the ESSENCE of the description through song choices.
          The songs should be INSPIRED BY the persona's characteristics, achievements, or themes.
          Example: "Albert Einstein" → songs with scientific themes, references to relativity,
          space, time, mathematics, or genius in titles/lyrics

        The style guide should enable intelligent, thematic song selections that embody the persona.

        Respond with a comprehensive style guide that includes:
        - Musical preferences and characteristics
        - Preferred genres, eras, and styles
        - Song selection criteria
        - Specific artists or tracks that exemplify this persona
        - How to maintain thematic coherence in selections
        """

        let request = ResponsesRequest(
            model: "gpt-5",
            input: prompt,
            verbosity: .high,
            reasoningEffort: .high,
            tools: [["type": "web_search"]],
            include: ["web_search_call.action.sources"]
        )

        do {
            var sources: [String] = []
            var accumulatedStyleGuide = ""

            // Use streaming API with real-time status updates
            let response = try await streamingResponses(request: request) { event in
                switch event.type {
                case .webSearchInProgress:
                    await onStatusUpdate?("🔎 Starting web search...")
                    B2BLog.ai.debug("Web search initiated")

                case .webSearchSearching:
                    await onStatusUpdate?("🔎 Searching the web...")
                    B2BLog.ai.debug("Web search in progress")

                case .webSearchCompleted:
                    if let eventSources = event.sources {
                        sources = eventSources.compactMap { $0.url }
                        let sourceCount = sources.count
                        await onStatusUpdate?("✅ Found \(sourceCount) source\(sourceCount == 1 ? "" : "s") — generating style guide...")
                        B2BLog.ai.debug("Web search completed with \(sourceCount) sources")
                    } else {
                        await onStatusUpdate?("✅ Web search completed — generating style guide...")
                        B2BLog.ai.debug("Web search completed without explicit sources")
                    }

                case .outputTextDelta:
                    if let delta = event.delta {
                        accumulatedStyleGuide += delta
                        // Show generation progress without flooding updates
                        if accumulatedStyleGuide.count % 100 == 0 {
                            let wordCount = accumulatedStyleGuide.split(separator: " ").count
                            await onStatusUpdate?("✍️ Generating style guide... (\(wordCount) words)")
                        }
                    }

                case .responseCompleted:
                    await onStatusUpdate?("✅ Style guide generation complete!")
                    B2BLog.ai.info("Streaming generation completed")

                case .responseError:
                    if let error = event.error {
                        await onStatusUpdate?("❌ Error: \(error.message)")
                        B2BLog.ai.error("Streaming error: \(error.message)")
                    }

                default:
                    break
                }
            }

            // Extract sources from the final response if not already captured
            if sources.isEmpty, let webSearchCalls = response.webSearchCall?.action?.sources {
                sources = webSearchCalls.compactMap { $0.url }
                B2BLog.ai.debug("Extracted \(sources.count) sources from final response")
            }

            let result = PersonaGenerationResult(
                name: name,
                styleGuide: response.outputText,
                sources: sources
            )

            B2BLog.ai.info("✅ Generated style guide for: \(name)")
            if !sources.isEmpty {
                B2BLog.ai.debug("Sources used: \(sources.joined(separator: ", "))")
            }

            return result
        } catch {
            B2BLog.ai.error("Failed to generate style guide: \(error)")
            await onStatusUpdate?("❌ Failed to generate style guide")
            throw error
        }
    }

    // MARK: - Song Selection

    func selectNextSong(persona: String, sessionHistory: [SessionSong]) async throws -> SongRecommendation {
        B2BLog.ai.info("Requesting AI song selection with persona")

        let prompt = buildDJPrompt(persona: persona, history: sessionHistory)

        // For the Responses API, we need to pass the verbosity but not the format
        // The format would need different API structure than we currently have
        // For now, let's use plain text output and parse it
        let request = ResponsesRequest(
            model: "gpt-5",
            input: prompt + "\n\nIMPORTANT: Respond ONLY with a valid JSON object in this exact format: {\"artist\": \"Artist Name\", \"song\": \"Song Title\", \"rationale\": \"Brief explanation (max 200 characters)\"}",
            verbosity: .high,
            reasoningEffort: .high
        )

        do {
            let response = try await responses(request: request)

            // The response should contain JSON in the outputText
            guard let jsonData = response.outputText.data(using: .utf8) else {
                throw OpenAIError.decodingError(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not convert output to data"]))
            }

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

        You MUST respond with ONLY a valid JSON object (no markdown, no extra text) in this exact format:
        {"artist": "Artist Name", "song": "Song Title", "rationale": "Brief explanation of your choice"}

        The rationale must be under 200 characters.
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