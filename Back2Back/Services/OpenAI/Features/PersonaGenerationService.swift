import Foundation
import OSLog

@MainActor
final class PersonaGenerationService {
    private let streaming: OpenAIStreaming

    init(streaming: OpenAIStreaming) {
        self.streaming = streaming
    }

    func generatePersonaStyleGuide(
        name: String,
        description: String,
        onStatusUpdate: ((String) async -> Void)? = nil,
        client: OpenAIClient
    ) async throws -> PersonaGenerationResult {
        B2BLog.ai.info("Generating style guide for persona: \(name)")

        let prompt = """
        Generate a DJ persona style guide for making song selections based on this description:
        \(description)

        Research real information about this style/person/era using web search.

        This style guide will be used by an AI to select songs in a back-to-back DJ session.
        Format the guide to optimize song selection decisions.

        IMPORTANT FORMATTING REQUIREMENTS:
        - Focus on actionable information for song selection
        - Keep the total guide between 2000-5000 characters for optimal use
        - Write in clear, direct prose without excessive detail
        - Prioritize practical guidance over encyclopedic information

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
        - Song selection criteria and decision-making approach
        - How to maintain thematic coherence in selections
        - Key mood and energy considerations for song flow

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
            var webSearchCount = 0
            var currentWordCount = 0
            var annotationsAdded = 0
            var reasoningStartTime = Date()
            var totalSourcesFound = 0

            let response = try await streaming.streamingResponses(request: request, client: client) { event in
                await self.handlePersonaGenerationEvent(
                    event: event,
                    sources: &sources,
                    accumulatedStyleGuide: &accumulatedStyleGuide,
                    webSearchCount: &webSearchCount,
                    currentWordCount: &currentWordCount,
                    annotationsAdded: &annotationsAdded,
                    reasoningStartTime: &reasoningStartTime,
                    totalSourcesFound: &totalSourcesFound,
                    onStatusUpdate: onStatusUpdate
                )
            }

            if sources.isEmpty, let webSearchCalls = response.webSearchCall?.action?.sources {
                sources = webSearchCalls.compactMap { $0.url }
                B2BLog.ai.debug("Extracted \(sources.count) sources from final response")
            }

            let cleanedStyleGuide = stripCitations(from: response.outputText)

            let result = PersonaGenerationResult(
                name: name,
                styleGuide: cleanedStyleGuide,
                sources: sources
            )

            B2BLog.ai.info("📝 Original style guide length: \(response.outputText.count) chars")
            B2BLog.ai.info("🧹 Cleaned style guide length: \(cleanedStyleGuide.count) chars")
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

    // MARK: - Event Handling

    private func handlePersonaGenerationEvent(
        event: StreamingEvent,
        sources: inout [String],
        accumulatedStyleGuide: inout String,
        webSearchCount: inout Int,
        currentWordCount: inout Int,
        annotationsAdded: inout Int,
        reasoningStartTime: inout Date,
        totalSourcesFound: inout Int,
        onStatusUpdate: ((String) async -> Void)?
    ) async {
        switch event.type {
        case .responseCreated:
            await onStatusUpdate?("Initializing...")
            B2BLog.ai.debug("Response created")

        case .responseInProgress:
            await onStatusUpdate?("Processing request...")
            B2BLog.ai.debug("Response in progress")

        case .responseOutputItemAdded:
            if let item = event.item {
                switch item.type {
                case "reasoning":
                    reasoningStartTime = Date()
                    let totalFound = totalSourcesFound
                    let searchCount = webSearchCount
                    if totalFound > 0 {
                        await onStatusUpdate?("Analyzing \(totalFound) source\(totalFound == 1 ? "" : "s")...")
                    } else if searchCount > 0 {
                        await onStatusUpdate?("Processing search results...")
                    } else {
                        await onStatusUpdate?("Thinking...")
                    }
                    B2BLog.ai.debug("Reasoning started")
                case "web_search_call":
                    webSearchCount += 1
                    let searchNum = webSearchCount
                    if searchNum == 1 {
                        await onStatusUpdate?("Starting web search...")
                    } else {
                        await onStatusUpdate?("Search #\(searchNum): Looking for more details...")
                    }
                    B2BLog.ai.debug("Web search \(searchNum) initiated")
                case "message":
                    await onStatusUpdate?("Generating style guide...")
                    B2BLog.ai.debug("Message generation started")
                default:
                    B2BLog.ai.trace("Unknown item type: \(item.type)")
                }
            }

        case .responseOutputItemDone:
            if let item = event.item {
                switch item.type {
                case "reasoning":
                    let reasoningDuration = Date().timeIntervalSince(reasoningStartTime)
                    B2BLog.ai.debug("Reasoning completed in \(String(format: "%.1f", reasoningDuration))s")
                    let totalFound = totalSourcesFound
                    if totalFound > 0 {
                        await onStatusUpdate?("Analysis of \(totalFound) source\(totalFound == 1 ? "" : "s") complete")
                    } else {
                        await onStatusUpdate?("Analysis complete")
                    }
                case "web_search_call":
                    if let action = item.action, let eventSources = action.sources {
                        sources.append(contentsOf: eventSources.compactMap { $0.url })
                        let sourceCount = eventSources.count
                        totalSourcesFound += sourceCount
                        let totalFound = totalSourcesFound
                        let searchNum = webSearchCount
                        if sourceCount > 0 {
                            if searchNum == 1 {
                                await onStatusUpdate?("Found \(sourceCount) relevant source\(sourceCount == 1 ? "" : "s")")
                            } else {
                                await onStatusUpdate?("Search #\(searchNum) found \(sourceCount) more source\(sourceCount == 1 ? "" : "s") (\(totalFound) total)")
                            }
                        } else {
                            await onStatusUpdate?("Search #\(searchNum) complete (no new sources)")
                        }
                        B2BLog.ai.debug("Web search \(searchNum) completed with \(sourceCount) sources")
                    }
                default:
                    break
                }
            }

        case .webSearchInProgress:
            let searchNum = webSearchCount
            if searchNum > 1 {
                await onStatusUpdate?("Search #\(searchNum) in progress...")
            } else {
                await onStatusUpdate?("Searching the web...")
            }
            B2BLog.ai.debug("Web search in progress")

        case .webSearchSearching:
            let searchNum = webSearchCount
            if searchNum > 1 {
                await onStatusUpdate?("Search #\(searchNum): Querying sources...")
            } else {
                await onStatusUpdate?("Searching for relevant information...")
            }
            B2BLog.ai.debug("Web search actively searching")

        case .webSearchCompleted:
            if let eventSources = event.sources {
                let sourceCount = eventSources.count
                totalSourcesFound += sourceCount
                let totalFound = totalSourcesFound
                let searchNum = webSearchCount
                if searchNum > 1 {
                    await onStatusUpdate?("Search #\(searchNum) complete (\(sourceCount) new, \(totalFound) total sources)")
                } else {
                    await onStatusUpdate?("Search complete (\(sourceCount) source\(sourceCount == 1 ? "" : "s"))")
                }
                B2BLog.ai.debug("Web search completed with \(sourceCount) sources")
            }

        case .responseContentPartAdded:
            await onStatusUpdate?("Composing response...")
            B2BLog.ai.trace("Content part added")

        case .outputTextDelta:
            if let delta = event.delta {
                accumulatedStyleGuide += delta
                let newWordCount = accumulatedStyleGuide.split(separator: " ").count
                if newWordCount - currentWordCount >= 50 || (newWordCount % 100 == 0 && newWordCount != currentWordCount) {
                    currentWordCount = newWordCount
                    let wordCount = currentWordCount
                    let progress = wordCount < 500 ? "Writing" :
                                 wordCount < 1000 ? "Expanding" :
                                 wordCount < 1500 ? "Detailing" : "Finalizing"
                    await onStatusUpdate?("\(progress) style guide (\(wordCount) words)...")
                }
            }

        case .responseOutputTextAnnotationAdded:
            annotationsAdded += 1
            let annotCount = annotationsAdded
            if annotCount == 1 {
                await onStatusUpdate?("Adding source citations...")
            } else if annotCount % 10 == 0 {
                await onStatusUpdate?("Adding citations (\(annotCount) references)...")
            }

        case .responseOutputTextDone:
            let annotCount = annotationsAdded
            if annotCount > 0 {
                await onStatusUpdate?("Finalizing with \(annotCount) citations...")
            } else {
                await onStatusUpdate?("Finalizing style guide...")
            }

        case .responseCompleted, .responseDone:
            let totalSources = sources.count
            let wordCount = currentWordCount
            if totalSources > 0 {
                await onStatusUpdate?("Complete! (\(totalSources) sources, \(wordCount) words)")
            } else {
                await onStatusUpdate?("Complete! (\(wordCount) words)")
            }
            B2BLog.ai.info("Streaming generation completed")

        case .responseError:
            if let error = event.error {
                await onStatusUpdate?("Error: \(error.message)")
                B2BLog.ai.error("Streaming error: \(error.message)")
            }

        default:
            break
        }
    }

    // MARK: - Citation Stripping

    private func stripCitations(from text: String) -> String {
        var cleanedText = text

        cleanedText = cleanedText.replacingOccurrences(
            of: #"\[\d+\]"#,
            with: "",
            options: .regularExpression
        )

        cleanedText = cleanedText.replacingOccurrences(
            of: #"\^\d+\^"#,
            with: "",
            options: .regularExpression
        )

        cleanedText = cleanedText.replacingOccurrences(
            of: #"\[\[\d+\]\]"#,
            with: "",
            options: .regularExpression
        )

        cleanedText = cleanedText.replacingOccurrences(
            of: #"[¹²³⁴⁵⁶⁷⁸⁹⁰]+"#,
            with: "",
            options: .regularExpression
        )

        cleanedText = cleanedText.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )

        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleanedText
    }
}
