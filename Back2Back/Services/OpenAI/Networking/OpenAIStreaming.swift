import Foundation
import OSLog

@MainActor
class OpenAIStreaming {
    init() {}

    func streamingResponses(
        request: ResponsesRequest,
        client: OpenAIClient,
        onEvent: @escaping (StreamingEvent) async -> Void
    ) async throws -> ResponsesResponse {
        guard let apiKey = client.apiKey, !apiKey.isEmpty else {
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
            let (bytes, response) = try await client.session.bytes(for: urlRequest)

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

    // MARK: - Stream Processing

    private func processStreamEvents(
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

    // MARK: - Event Handlers

    private func handleOutputItem(
        streamEvent: StreamEvent,
        sources: inout [WebSearchSource],
        onEvent: @escaping (StreamingEvent) async -> Void
    ) async throws {
        guard let item = streamEvent.item else { return }

        let isAddedEvent = streamEvent.type == .responseOutputItemAdded

        switch item.type {
        case "reasoning":
            if isAddedEvent {
                B2BLog.ai.debug("🤔 Reasoning started")
            } else {
                B2BLog.ai.debug("✓ Reasoning completed")
            }
            let event = StreamingEvent(
                type: isAddedEvent ? .responseOutputItemAdded : .responseOutputItemDone,
                delta: nil,
                sources: nil,
                error: nil,
                response: nil,
                item: item
            )
            await onEvent(event)

        case "web_search_call":
            if isAddedEvent {
                B2BLog.ai.debug("🔎 Web search initiated")
                let event = StreamingEvent(
                    type: .webSearchInProgress,
                    delta: nil,
                    sources: nil,
                    error: nil,
                    response: nil
                )
                await onEvent(event)
            } else if let action = item.action, let eventSources = action.sources {
                sources = eventSources
                let sourceCount = sources.count
                B2BLog.ai.debug("✅ Web search completed with \(sourceCount) sources")
                let event = StreamingEvent(
                    type: .webSearchCompleted,
                    delta: nil,
                    sources: sources.isEmpty ? nil : sources,
                    error: nil,
                    response: nil
                )
                await onEvent(event)
            }

        case "message":
            if isAddedEvent {
                B2BLog.ai.debug("💬 Message generation started")
            } else {
                B2BLog.ai.debug("✓ Message generation completed")
            }
            if isAddedEvent {
                let event = StreamingEvent(
                    type: .responseOutputItemAdded,
                    delta: nil,
                    sources: nil,
                    error: nil,
                    response: nil,
                    item: item
                )
                await onEvent(event)
            }

        default:
            B2BLog.ai.trace("Output item \(isAddedEvent ? "added" : "done"): \(item.type)")
        }
    }

    private func handleWebSearchEvents(
        streamEvent: StreamEvent,
        sources: inout [WebSearchSource],
        onEvent: @escaping (StreamingEvent) async -> Void
    ) async throws {
        let eventType: StreamEventType
        switch streamEvent.type {
        case .webSearchInProgress:
            eventType = .webSearchInProgress
        case .webSearchSearching:
            eventType = .webSearchSearching
        case .webSearchCompleted:
            eventType = .webSearchCompleted
        default:
            return
        }

        if eventType == .webSearchCompleted,
           let eventSources = streamEvent.results?.sources {
            sources = eventSources
            let sourceCount = sources.count
            B2BLog.ai.debug("✅ Web search completed with \(sourceCount) sources")
        } else {
            B2BLog.ai.debug("🔎 Web search \(eventType == .webSearchSearching ? "actively searching" : "in progress")")
        }

        let event = StreamingEvent(
            type: eventType,
            delta: nil,
            sources: eventType == .webSearchCompleted && !sources.isEmpty ? sources : nil,
            error: nil,
            response: nil
        )
        await onEvent(event)
    }

    private func handleResponseLifecycleEvents(
        streamEvent: StreamEvent,
        request: ResponsesRequest,
        sources: [WebSearchSource],
        finalResponse: inout ResponsesResponse?,
        onEvent: @escaping (StreamingEvent) async -> Void
    ) async throws {
        switch streamEvent.type {
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

        case .responseCompleted, .responseDone:
            B2BLog.ai.debug("Response completed event")
            if streamEvent.output != nil {
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

        default:
            break
        }
    }

    private func buildFinalResponse(
        finalResponse: ResponsesResponse?,
        accumulatedText: String,
        sources: [WebSearchSource],
        request: ResponsesRequest
    ) throws -> ResponsesResponse {
        if let finalResponse = finalResponse {
            B2BLog.ai.info("Streaming responses API call successful - using finalResponse")
            B2BLog.ai.info("📊 FinalResponse outputText before fix: \(finalResponse.outputText.isEmpty ? "[EMPTY]" : "[\(finalResponse.outputText.count) chars]")")
            B2BLog.ai.info("📊 FinalResponse output items: \(finalResponse.output.count)")

            if !accumulatedText.isEmpty && finalResponse.outputText.isEmpty {
                B2BLog.ai.info("🔧 Fixing empty outputText with accumulated text: \(accumulatedText.count) chars")
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
                let fixedResponse = ResponsesResponse(
                    id: finalResponse.id,
                    object: finalResponse.object,
                    createdAt: finalResponse.createdAt,
                    model: finalResponse.model,
                    output: finalResponse.output + [.message(message)],
                    status: finalResponse.status,
                    usage: finalResponse.usage,
                    metadata: finalResponse.metadata,
                    reasoning: finalResponse.reasoning,
                    text: finalResponse.text,
                    temperature: finalResponse.temperature,
                    topP: finalResponse.topP,
                    billing: finalResponse.billing,
                    webSearchCall: finalResponse.webSearchCall ?? WebSearchCall(action: sources.isEmpty ? nil : WebSearchAction(sources: sources))
                )
                B2BLog.ai.info("📊 Fixed response outputText: \(fixedResponse.outputText.isEmpty ? "[EMPTY]" : "[\(fixedResponse.outputText.count) chars]")")
                return fixedResponse
            }

            B2BLog.ai.info("📊 FinalResponse outputText: \(finalResponse.outputText.isEmpty ? "[EMPTY]" : "[\(finalResponse.outputText.count) chars]")")
            return finalResponse
        } else if !accumulatedText.isEmpty {
            B2BLog.ai.info("Constructing response from accumulated text: \(accumulatedText.count) chars")
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
            B2BLog.ai.info("📊 Constructed response outputText: \(constructedResponse.outputText.isEmpty ? "[EMPTY]" : "[\(constructedResponse.outputText.count) chars]")")
            return constructedResponse
        } else {
            B2BLog.ai.error("No response data received from streaming API")
            throw OpenAIError.invalidResponse
        }
    }
}
