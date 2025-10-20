//
//  OpenAIValidator.swift
//  Back2Back
//
//  Created for GitHub issue #96
//  Validates songs against personas using OpenAI GPT-5 with full style guide context
//

import Foundation
import MusicKit
import OSLog

/// Validates songs using OpenAI's GPT-5 API with configurable reasoning levels
///
/// **Advantages over Foundation Models**:
/// - Large context window: Can consume FULL style guides (2000+ words)
/// - Better accuracy: Especially for personas with detailed style guides but minimal descriptions
/// - Flexible reasoning: Configurable low/medium/high reasoning effort
///
/// **Trade-offs**:
/// - Slower: Network latency + API processing (1-3s vs 100-300ms)
/// - Costs money: API charges per validation
/// - Requires network: No offline capability
/// - Privacy: Data sent to OpenAI servers
@MainActor
final class OpenAIValidator: SongValidatorProtocol {
    private let openAIClient: OpenAIClient
    private let environmentService: EnvironmentService
    private let reasoningLevel: ReasoningEffort

    var displayName: String {
        "GPT-5 (\(reasoningLevel.rawValue.capitalized) Reasoning)"
    }

    var isAvailable: Bool {
        environmentService.getOpenAIKey() != nil
    }

    init(openAIClient: OpenAIClient, environmentService: EnvironmentService, reasoningLevel: ReasoningEffort) {
        self.openAIClient = openAIClient
        self.environmentService = environmentService
        self.reasoningLevel = reasoningLevel

        if isAvailable {
            B2BLog.ai.info("[OpenAI-\(self.reasoningLevel.rawValue)] ✅ OpenAI validator initialized")
        } else {
            B2BLog.ai.warning("[OpenAI-\(self.reasoningLevel.rawValue)] ⚠️ OpenAI API key not found - validator unavailable")
        }
    }

    /// Validates that a song matches the persona's style using OpenAI GPT-5
    /// - Parameters:
    ///   - song: The song to validate
    ///   - persona: The complete Persona object (uses both description AND full style guide)
    /// - Returns: ValidationResponse with isValid flag and reasoning, or nil if validation unavailable
    ///
    /// **Context Used**: Unlike Foundation Models, this validator can use the FULL style guide
    /// (2000+ words) thanks to GPT-5's large context window. This dramatically improves accuracy
    /// for personas with detailed style guides but minimal descriptions.
    ///
    /// **Fail-open behavior**: Returns nil if API unavailable, network errors, or parsing errors.
    func validate(song: some SongProtocol, persona: Persona) async -> ValidationResponse? {
        guard isAvailable else {
            B2BLog.ai.warning("[OpenAI-\(self.reasoningLevel.rawValue)] API key not available - accepting by default")
            return nil
        }

        // Build rich context from song metadata
        var contextParts: [String] = []

        // Song title and artist (always available)
        contextParts.append("Song: \"\(song.title)\" by \(song.artistName)")

        // Album title provides context
        if let albumTitle = song.albumTitle {
            contextParts.append("Album: \(albumTitle)")
        }

        // Editorial notes (most reliable for context) - only available on real Song objects
        if let realSong = song as? Song, let editorialNotes = realSong.editorialNotes {
            if let standard = editorialNotes.standard {
                contextParts.append("Song description: \(standard)")
            } else if let short = editorialNotes.short {
                contextParts.append("Song description: \(short)")
            }
        }

        let songContext = contextParts.joined(separator: "\n")

        // Build prompt with FULL persona context (description + style guide)
        let prompt = """
        You are a music validation assistant for a DJ persona-based music app.

        PERSONA DESCRIPTION:
        \(persona.description)

        FULL STYLE GUIDE:
        \(persona.styleGuide)

        SONG TO VALIDATE:
        \(songContext)

        Based on the COMPLETE persona information (description + style guide), determine if this song is appropriate for the persona to play. Consider genre, era, style, production quality, lyrical themes, and overall musical context. Be lenient - only reject if clearly mismatched.

        IMPORTANT: Respond ONLY with a valid JSON object in this exact format:
        {"isValid": true/false, "reasoning": "1-2 sentence explanation", "shortSummary": "Very brief reason (max 10 words)"}
        """

        // Create OpenAI request
        let request = ResponsesRequest(
            model: "gpt-5",
            input: prompt,
            verbosity: .high,
            reasoningEffort: reasoningLevel
        )

        do {
            B2BLog.ai.debug("[OpenAI-\(self.reasoningLevel.rawValue)] 🤖 Validating: '\(song.title)' by \(song.artistName)")

            let response = try await openAIClient.performNetworkRequest(request)

            guard let jsonData = response.outputText.data(using: .utf8) else {
                B2BLog.ai.error("[OpenAI-\(self.reasoningLevel.rawValue)] Could not convert response to data")
                return nil  // Fail open
            }

            let validation = try JSONDecoder().decode(ValidationResponse.self, from: jsonData)

            if validation.isValid {
                B2BLog.ai.info("[OpenAI-\(self.reasoningLevel.rawValue)] ✅ Validation PASS: '\(song.title)' - \(validation.reasoning)")
            } else {
                B2BLog.ai.warning("[OpenAI-\(self.reasoningLevel.rawValue)] 🚫 Validation FAIL: '\(song.title)' - \(validation.reasoning)")
            }

            return validation
        } catch {
            B2BLog.ai.error("[OpenAI-\(self.reasoningLevel.rawValue)] Validation failed with error: \(error.localizedDescription)")
            return nil  // Fail open on errors
        }
    }
}
