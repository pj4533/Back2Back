import Foundation
import OSLog

extension OpenAIClient {
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

        if let requestData = try? JSONEncoder().encode(request),
           var jsonObject = try? JSONSerialization.jsonObject(with: requestData, options: []) as? [String: Any] {
            jsonObject["stream"] = true
            let requestBody = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
            urlRequest.httpBody = requestBody

            if let requestString = String(data: requestBody, encoding: .utf8) {
                B2BLog.ai.debug("Request body: \(requestString)")
            }
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
                var errorMessage = "Streaming request failed"
                if httpResponse.statusCode == 400 {
                    var errorBody = ""
                    do {
                        for try await line in bytes.lines {
                            errorBody += line + "\n"
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

                if httpResponse.statusCode == 401 {
                    throw OpenAIError.unauthorized
                } else if httpResponse.statusCode == 429 {
                    throw OpenAIError.rateLimitExceeded
                } else {
                    throw OpenAIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
                }
            }

            let processedResponse = try await processStreamEvents(
                bytes: bytes,
                request: request,
                onEvent: onEvent
            )

            let elapsedTime = Date().timeIntervalSince(startTime)
            B2BLog.network.debug("⏱️ Streaming API Response Time: \(elapsedTime)")

            return processedResponse

        } catch let error as OpenAIError {
            throw error
        } catch {
            B2BLog.ai.error("❌ Streaming network error: \(error.localizedDescription)")
            throw OpenAIError.networkError(error)
        }
    }

    func processStreamEvents(
        bytes: URLSession.AsyncBytes,
        request: ResponsesRequest,
        onEvent: @escaping (StreamingEvent) async -> Void
    ) async throws -> ResponsesResponse {
        var accumulatedText = ""
        var finalResponse: ResponsesResponse?
        var sources: [WebSearchSource] = []

        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }

            let jsonString = String(line.dropFirst(6))

            if jsonString == "[DONE]" {
                B2BLog.ai.debug("Stream completed")
                break
            }

            guard let jsonData = jsonString.data(using: .utf8) else {
                B2BLog.ai.warning("Failed to convert SSE line to data: \(jsonString)")
                continue
            }

            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                    let eventType = jsonObject["type"] as? String ?? "unknown"

                    let knownEventTypes = [
                        "response.created", "response.in_progress", "response.completed",
                        "response.done", "response.error", "response.output_item.added",
                        "response.output_item.done", "response.content_part.added",
                        "response.content_part.done", "response.output_text.delta",
                        "response.output_text.annotation.added", "response.output_text.done",
                        "response.web_search_call.in_progress", "response.web_search_call.searching",
                        "response.web_search_call.completed"
                    ]

                    if !knownEventTypes.contains(eventType) {
                        B2BLog.ai.debug("Unknown stream event type: \(eventType)")
                        B2BLog.ai.debug("Full raw event JSON: \(jsonString)")
                    }
                }

                if let fullResponse = try? JSONDecoder().decode(ResponsesResponse.self, from: jsonData) {
                    finalResponse = fullResponse
                    B2BLog.ai.debug("Received full response in stream")

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

                let decoder = JSONDecoder()
                let streamEvent = try decoder.decode(StreamEvent.self, from: jsonData)

                switch streamEvent.type {
                case .responseInProgress:
                    B2BLog.ai.debug("Response in progress")
                    if let response = streamEvent.response {
                        finalResponse = ResponsesResponse(
                            id: response.id,
                            object: response.object,
                            createdAt: response.createdAt ?? Date().timeIntervalSince1970,
                            model: streamEvent.model ?? request.model,
                            output: response.output ?? [],
                            status: response.status,
                            usage: streamEvent.usage,
                            metadata: nil,
                            reasoning: nil,
                            text: nil,
                            temperature: nil,
                            topP: nil,
                            billing: nil,
                            webSearchCall: nil
                        )
                    }

                case .responseOutputItemAdded, .responseOutputItemDone:
                    try await handleOutputItem(
                        streamEvent: streamEvent,
                        sources: &sources,
                        onEvent: onEvent
                    )

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

                case .webSearchInProgress, .webSearchSearching, .webSearchCompleted:
                    try await handleWebSearchEvents(
                        streamEvent: streamEvent,
                        sources: &sources,
                        onEvent: onEvent
                    )

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

                case .responseCreated, .responseCompleted, .responseDone:
                    try await handleResponseLifecycleEvents(
                        streamEvent: streamEvent,
                        request: request,
                        sources: sources,
                        finalResponse: &finalResponse,
                        onEvent: onEvent
                    )

                case .responseContentPartAdded:
                    B2BLog.ai.trace("Content part added")

                case .responseOutputTextAnnotationAdded:
                    if let annotation = streamEvent.annotation {
                        B2BLog.ai.trace("Added annotation: \(annotation.type) - \(annotation.url ?? "")")
                    }

                case .responseOutputTextDone:
                    B2BLog.ai.debug("Text output completed")

                default:
                    B2BLog.ai.trace("Stream event type: \(streamEvent.type)")
                    if streamEvent.type == .other {
                        B2BLog.ai.debug("Unknown event raw JSON: \(jsonString)")
                    }
                }

            } catch {
                B2BLog.ai.warning("Failed to decode stream event: \(error)")
                B2BLog.ai.debug("Failed event raw JSON: \(jsonString)")
            }
        }

        return try buildFinalResponse(
            finalResponse: finalResponse,
            accumulatedText: accumulatedText,
            sources: sources,
            request: request
        )
    }
}