import Foundation
import OSLog
import MusicKit

struct SongRecommendation: Codable {
    let artist: String
    let song: String
    let rationale: String
}

@MainActor
class SongSelectionService {
    private let personaSongCacheService: PersonaSongCacheService

    init(personaSongCacheService: PersonaSongCacheService) {
        self.personaSongCacheService = personaSongCacheService
    }

    func selectNextSong(
        persona: String,
        personaId: UUID,
        sessionHistory: [SessionSong],
        directionChange: DirectionChange? = nil,
        config: AIModelConfig = .default,
        client: OpenAIClient
    ) async throws -> SongRecommendation {
        B2BLog.ai.info("Requesting AI song selection with persona using model: \(config.songSelectionModel), reasoning: \(config.songSelectionReasoningLevel.rawValue)")

        if let direction = directionChange, let firstOption = direction.options.first {
            B2BLog.ai.info("Applying direction change: \(firstOption.directionPrompt)")
        }

        let prompt = buildDJPrompt(persona: persona, personaId: personaId, history: sessionHistory, directionChange: directionChange)

        let request = ResponsesRequest(
            model: config.songSelectionModel,
            input: prompt + "\n\nIMPORTANT: Respond ONLY with a valid JSON object in this exact format: {\"artist\": \"Artist Name\", \"song\": \"Song Title\", \"rationale\": \"Brief explanation (max 200 characters)\"}",
            verbosity: .high,
            reasoningEffort: config.songSelectionReasoningLevel
        )

        do {
            let response = try await client.performNetworkRequest(request)

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

    func simpleCompletion(prompt: String, model: String = "gpt-5", client: OpenAIClient) async throws -> String {
        let request = ResponsesRequest(
            model: model,
            input: prompt,
            verbosity: .medium,
            reasoningEffort: .medium
        )

        let response = try await client.performNetworkRequest(request)
        return response.outputText
    }

    /// Generates contextual direction change suggestions based on the current persona and session history
    ///
    /// This method uses GPT-5-mini to analyze the current DJ session and suggest multiple musical direction
    /// options that the user might want to explore. It returns 2 distinct direction options, each with a
    /// detailed direction prompt for the AI to use when selecting the next song, and a short button label for the UI.
    ///
    /// - Parameters:
    ///   - persona: The current DJ persona's style guide
    ///   - sessionHistory: The songs played so far in the session
    ///   - previousDirection: The previously generated directions (if any) to avoid repetition
    ///   - client: The OpenAI client to use for the request
    /// - Returns: A `DirectionChange` containing an array of 2 direction options
    /// - Throws: OpenAI API errors or JSON decoding errors
    func generateDirectionChange(
        persona: String,
        sessionHistory: [SessionSong],
        previousDirection: DirectionChange? = nil,
        client: OpenAIClient
    ) async throws -> DirectionChange {
        B2BLog.ai.info("Generating direction change suggestions (requesting 2 options)")

        if let previous = previousDirection, !previous.options.isEmpty {
            B2BLog.ai.debug("Previous directions: \(previous.options.map { $0.buttonLabel }.joined(separator: ", "))")
        }

        let prompt = buildDirectionChangePrompt(persona: persona, history: sessionHistory, previousDirection: previousDirection)

        // Use GPT-5-mini for fast, cost-effective direction generation
        let request = ResponsesRequest(
            model: "gpt-5-mini",
            input: prompt,
            verbosity: .medium,
            reasoningEffort: .low
        )

        do {
            let response = try await client.performNetworkRequest(request)

            guard let jsonData = response.outputText.data(using: .utf8) else {
                B2BLog.ai.error("Failed to convert direction change response to data")
                throw OpenAIError.decodingError(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not convert output to data"]))
            }

            let directionChange = try JSONDecoder().decode(DirectionChange.self, from: jsonData)

            B2BLog.ai.info("Generated \(directionChange.options.count) direction change options: \(directionChange.options.map { $0.buttonLabel }.joined(separator: ", "))")
            B2BLog.ai.debug("Direction prompts: \(directionChange.options.map { $0.directionPrompt }.joined(separator: " | "))")

            return directionChange
        } catch {
            B2BLog.ai.error("Failed to generate direction change: \(error)")
            throw error
        }
    }

    // MARK: - Private Helpers

    private func buildDJPrompt(persona: String, personaId: UUID, history: [SessionSong], directionChange: DirectionChange? = nil) -> String {
        var historyText = ""
        if !history.isEmpty {
            historyText = """

            Session history (in order played):
            \(formatSessionHistory(history))

            """
        }

        // Get recent songs from cache (24-hour exclusion list)
        let recentSongs = personaSongCacheService.getRecentSongs(for: personaId)
        var recentSongsText = ""
        if !recentSongs.isEmpty {
            recentSongsText = """

            Songs you've recently selected (within last 24 hours) - do NOT choose these:
            \(formatRecentSongs(recentSongs))

            """

            B2BLog.ai.info("Added \(recentSongs.count) recent songs to exclusion list for persona")
        }

        // Add direction change section if provided
        var directionText = ""
        if let direction = directionChange, let firstOption = direction.options.first {
            directionText = """


            NEW DIRECTION FOR THIS SELECTION:
            \(firstOption.directionPrompt)

            """
        }

        return """
        \(persona)
        \(historyText)\(recentSongsText)\(directionText)
        Select the next song that:
        1. Complements the musical journey so far
        2. Reflects your DJ persona's taste
        3. Doesn't repeat any previous songs
        4. Avoids recently selected songs from your past sessions
        5. AVOID playing the same artist back-to-back whenever possible
        6. IMPORTANT: Avoid selecting songs that are explicitly mentioned in your style guide. Those songs should only be played occasionally, after many other selections. The goal is to SURPRISE with songs that fit the persona but aren't directly mentioned - songs that are similar in spirit but not the obvious choices the user already knows about.

        You MUST respond with ONLY a valid JSON object (no markdown, no extra text) in this exact format:
        {"artist": "Artist Name", "song": "Song Title", "rationale": "Brief explanation of your choice"}

        The rationale must be under 200 characters.
        """
    }

    private func buildDirectionChangePrompt(persona: String, history: [SessionSong], previousDirection: DirectionChange? = nil) -> String {
        var historyText = ""
        if !history.isEmpty {
            historyText = """

            Session history (in order played):
            \(formatSessionHistory(history))

            """
        }

        var previousDirectionText = ""
        if let previous = previousDirection, !previous.options.isEmpty {
            let previousLabels = previous.options.map { "\"\($0.buttonLabel)\"" }.joined(separator: ", ")
            let previousPrompts = previous.options.map { "- \($0.directionPrompt)" }.joined(separator: "\n")
            previousDirectionText = """


            PREVIOUS DIRECTION SUGGESTIONS (DO NOT REPEAT THESE):
            Button Labels: \(previousLabels)
            Direction Prompts:
            \(previousPrompts)

            You MUST suggest options that are COMPLETELY DIFFERENT from these previous suggestions. Explore different aspects of the persona's musical universe.

            """
        }

        return """
        You are helping a DJ persona suggest musical direction changes for their set.

        Current DJ persona:
        \(persona)
        \(historyText)\(previousDirectionText)

        IMPORTANT: Analyze the session history to identify dominant patterns (geographic regions, eras, tempos, genres, moods, production styles, etc.). Then suggest 2 DISTINCT directions that are DRAMATICALLY DIFFERENT from these patterns AND from each other, while still fitting within the persona's overall style guide.

        For example:
        - If many songs are from New Orleans → DON'T suggest "Southern soul" or "Gulf Coast blues" → DO suggest "West Coast psychedelic" or "British acid jazz" or "Chicago house"
        - If many songs are from the 1970s → DON'T suggest "Late 70s disco" → DO suggest "1960s garage rock" or "1990s trip-hop" or "2010s indie"
        - If many songs are uptempo → DON'T suggest "More energetic" → DO suggest "Downtempo grooves" or "Ambient soundscapes"
        - If many songs are from similar artists → DON'T suggest related artists → DO suggest completely different subgenres within the persona's taste

        The goal is to create CONTRAST and SURPRISE while staying true to the persona's broader aesthetic. Think of it as exploring different corners of the persona's musical universe that haven't been visited yet in this session.

        The 2 options you provide should be DISTINCT from each other - they should represent meaningfully different musical directions, not slight variations on the same theme.

        You MUST respond with ONLY a valid JSON object (no markdown, no extra text) in this exact format:
        {
          "options": [
            {
              "directionPrompt": "A detailed description of the first musical direction change (1-2 sentences)",
              "buttonLabel": "A short label for the UI menu (2-4 words max)"
            },
            {
              "directionPrompt": "A detailed description of the second musical direction change (1-2 sentences)",
              "buttonLabel": "A short label for the UI menu (2-4 words max)"
            }
          ]
        }

        Keep the buttonLabels concise and user-friendly. Examples: "West Coast vibes", "60s garage rock", "Downtempo shift", "British invasion", "Modern production"
        """
    }

    private func formatSessionHistory(_ history: [SessionSong]) -> String {
        history.enumerated().map { index, sessionSong in
            "\(index + 1). '\(sessionSong.song.title)' by \(sessionSong.song.artistName) [\(sessionSong.selectedBy.rawValue)]"
        }.joined(separator: "\n")
    }

    private func formatRecentSongs(_ recentSongs: [CachedSong]) -> String {
        recentSongs.enumerated().map { index, cachedSong in
            "\(index + 1). '\(cachedSong.songTitle)' by \(cachedSong.artist)"
        }.joined(separator: "\n")
    }
}
