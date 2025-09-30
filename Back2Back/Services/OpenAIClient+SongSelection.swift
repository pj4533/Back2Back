import Foundation
import OSLog
import MusicKit

struct SongRecommendation: Codable {
    let artist: String
    let song: String
    let rationale: String
}

extension OpenAIClient {
    func selectNextSong(persona: String, personaId: UUID, sessionHistory: [SessionSong], config: AIModelConfig = .default) async throws -> SongRecommendation {
        B2BLog.ai.info("Requesting AI song selection with persona using model: \(config.songSelectionModel), reasoning: \(config.songSelectionReasoningLevel.rawValue)")

        let prompt = buildDJPrompt(persona: persona, personaId: personaId, history: sessionHistory)

        let request = ResponsesRequest(
            model: config.songSelectionModel,
            input: prompt + "\n\nIMPORTANT: Respond ONLY with a valid JSON object in this exact format: {\"artist\": \"Artist Name\", \"song\": \"Song Title\", \"rationale\": \"Brief explanation (max 200 characters)\"}",
            verbosity: .high,
            reasoningEffort: config.songSelectionReasoningLevel
        )

        do {
            let response = try await responses(request: request)

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

    private func buildDJPrompt(persona: String, personaId: UUID, history: [SessionSong]) -> String {
        var historyText = ""
        if !history.isEmpty {
            historyText = """

            Session history (in order played):
            \(formatSessionHistory(history))

            """
        }

        // Get recent songs from cache (24-hour exclusion list)
        let recentSongs = PersonaSongCacheService.shared.getRecentSongs(for: personaId)
        var recentSongsText = ""
        if !recentSongs.isEmpty {
            recentSongsText = """

            Songs you've recently selected (within last 24 hours) - do NOT choose these:
            \(formatRecentSongs(recentSongs))

            """

            B2BLog.ai.info("Added \(recentSongs.count) recent songs to exclusion list for persona")
        }

        return """
        \(persona)
        \(historyText)\(recentSongsText)
        Select the next song that:
        1. Complements the musical journey so far
        2. Reflects your DJ persona's taste
        3. Doesn't repeat any previous songs
        4. Avoids recently selected songs from your past sessions

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

    private func formatRecentSongs(_ recentSongs: [CachedSong]) -> String {
        recentSongs.enumerated().map { index, cachedSong in
            "\(index + 1). '\(cachedSong.songTitle)' by \(cachedSong.artist)"
        }.joined(separator: "\n")
    }

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
}
