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

    /// Brief reasoning for the decision
    let reasoning: String
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
    /// - Returns: true if song matches persona, false if clearly wrong
    ///
    /// **Fail-open behavior**: Returns true if model unavailable or errors occur,
    /// to avoid blocking playback. Validation failures are logged for debugging.
    func validate(song: Song, personaDescription: String) async -> Bool {
        guard let session = session else {
            B2BLog.ai.warning("Foundation Model unavailable for validation - accepting by default")
            return true  // Fail open - don't block playback if model unavailable
        }

        // Format release date (handle nil gracefully)
        let releaseYear: String
        if let date = song.releaseDate {
            releaseYear = date.formatted(.dateTime.year())
        } else {
            releaseYear = "unknown"
        }

        // Format genres (handle empty array)
        let genres = song.genreNames.isEmpty ? "unknown" : song.genreNames.joined(separator: ", ")

        // Keep prompt concise for smaller context windows (~150 tokens total)
        let prompt = """
        Persona: \(personaDescription)

        Song: "\(song.title)" by \(song.artistName)
        Genre: \(genres)
        Release: \(releaseYear)

        Does this song match the persona's style?
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

            return validation.isValid
        } catch {
            B2BLog.ai.error("Validation failed with error: \(error.localizedDescription)")
            return true  // Fail open on errors - don't block playback
        }
    }
}
