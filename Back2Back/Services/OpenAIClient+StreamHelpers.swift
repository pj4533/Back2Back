import Foundation
import OSLog

extension OpenAIClient {
    func handleOutputItem(
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

    func handleWebSearchEvents(
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

    func handleResponseLifecycleEvents(
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

    func buildFinalResponse(
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