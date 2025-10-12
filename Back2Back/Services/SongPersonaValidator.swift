//
//  SongPersonaValidator.swift
//  Back2Back
//
//  Created on 2025-10-12.
//  Validates matched songs against persona using Apple Foundation Models
//

import Foundation
import MusicKit
import FoundationModels
import OSLog

/// Response structure for persona-song validation
@Generable
struct ValidationResponse {
    /// true if song matches persona, false otherwise
    let isValid: Bool

    /// Brief reasoning for the decision (1-2 sentences)
    let reasoning: String

    /// Very short summary for UI display (max 10 words)
    let shortSummary: String
}

/// Validates that matched songs actually make sense for the selected Persona.
/// Acts as a quality gate between song matching and playback, catching cases where
/// string/LLM matching produces wrong-genre tracks.
///
/// Uses Apple's on-device Foundation Models for:
/// - Privacy-first: On-device processing, no external API calls
/// - Zero cost: No API charges
/// - Fast: Optimized for Apple Silicon (~100-300ms per validation)
/// - Offline capable: Works without internet
@MainActor
final class SongPersonaValidator {
    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession?

    init() {
        // Configure session with instructions if model is available
        if model.availability == .available {
            let instructions = """
            You are a music validation assistant. Given a song and a DJ persona description, \
            determine if the song is appropriate for that persona to play. Consider genre, \
            era, style, and musical context. Return true if the song matches the persona's style, \
            false if it's clearly wrong (e.g., country song for NYC punk DJ).
            """
            session = LanguageModelSession(instructions: instructions)
            B2BLog.ai.info("✅ SongPersonaValidator: SystemLanguageModel available")
        } else {
            B2BLog.ai.warning("⚠️ SongPersonaValidator: SystemLanguageModel not available - will accept all matches")
        }
    }

    /// Validates that a song matches the persona's style
    /// - Parameters:
    ///   - song: The song to validate
    ///   - personaDescription: Concise description of the persona (50-100 words max)
    /// - Returns: ValidationResponse with isValid flag and reasoning, or nil if validation unavailable
    ///
    /// **Fail-open behavior**: Returns nil if model unavailable or errors occur,
    /// to avoid blocking playback. Validation failures are logged for debugging.
    ///
    /// **Note**: Does NOT use Apple Music's genre/release date metadata as it's unreliable
    /// for rare/obscure tracks. Instead relies on editorial notes and artist context.
    func validate(song: Song, personaDescription: String) async -> ValidationResponse? {
        guard let session = session else {
            B2BLog.ai.warning("Foundation Model unavailable for validation - accepting by default")
            return nil  // Fail open - don't block playback if model unavailable
        }

        // Build context from available editorial content (not metadata like genre/year)
        var contextParts: [String] = []

        // Song title and artist (always available)
        contextParts.append("Song: \"\(song.title)\" by \(song.artistName)")

        // Album title provides context
        if let albumTitle = song.albumTitle {
            contextParts.append("Album: \(albumTitle)")
        }

        // Editorial notes (most reliable for context)
        if let editorialNotes = song.editorialNotes {
            if let standard = editorialNotes.standard {
                contextParts.append("Song description: \(standard)")
            } else if let short = editorialNotes.short {
                contextParts.append("Song description: \(short)")
            }
        }

        // Artist editorial notes (if available via with(.artists) - not guaranteed)
        // Note: This would require fetching with relationship, which we may not have
        // For now, we work with what's available on the Song object

        let songContext = contextParts.joined(separator: "\n")

        // Keep prompt concise for smaller context windows
        let prompt = """
        Persona: \(personaDescription)

        \(songContext)

        Based on the song title, artist name, and any available context, does this song seem appropriate for the persona to play? Consider musical style and thematic fit. Be lenient - only reject if clearly mismatched.

        In your response, provide:
        - isValid: true/false
        - reasoning: 1-2 sentence explanation
        - shortSummary: Very brief reason (max 10 words, e.g., "Wrong genre - pop vs rap")
        """

        do {
            B2BLog.ai.debug("🤖 Validating: '\(song.title)' by \(song.artistName) for persona: \(personaDescription)")
            let response = try await session.respond(to: prompt, generating: ValidationResponse.self)
            let validation = response.content

            if validation.isValid {
                B2BLog.ai.info("✅ Validation PASS: '\(song.title)' - \(validation.reasoning)")
            } else {
                B2BLog.ai.warning("🚫 Validation FAIL: '\(song.title)' - \(validation.reasoning)")
            }

            return validation
        } catch {
            B2BLog.ai.error("Validation failed with error: \(error.localizedDescription)")
            return nil  // Fail open on errors - don't block playback
        }
    }
}
