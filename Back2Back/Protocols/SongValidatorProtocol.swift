//
//  SongValidatorProtocol.swift
//  Back2Back
//
//  Created for GitHub issue #96
//  Protocol abstraction for song validation strategies
//

import Foundation
import MusicKit

/// Protocol for validating songs against persona musical preferences
///
/// Different implementations can use various strategies (on-device models, cloud APIs)
/// with different trade-offs (context window size, latency, privacy, cost).
///
/// **Fail-Open Philosophy**: Validators return `nil` when unavailable/erroring rather
/// than throwing errors. Validation failures should log but not block playback.
@MainActor
protocol SongValidatorProtocol {
    /// Validates that a song matches the persona's musical style
    /// - Parameters:
    ///   - song: The song to validate (can be MusicKit Song or test mock)
    ///   - persona: The complete Persona object (validators choose what data to use)
    /// - Returns: ValidationResponse if available, nil for fail-open behavior
    ///
    /// **Implementation Notes**:
    /// - Each validator decides what Persona data to use (description vs full style guide)
    /// - Return `nil` if validator unavailable (no API key, model not loaded, network error)
    /// - Return `nil` on errors (parsing, timeout, etc.) to fail open
    /// - Log all validation attempts and results for debugging
    func validate(song: some SongProtocol, persona: Persona) async -> ValidationResponse?

    /// Human-readable name for UI display
    /// Examples: "Foundation Models (Local)", "GPT-5 (High Reasoning)"
    var displayName: String { get }

    /// Whether this validator is currently available for use
    /// - Foundation Models: Checks `SystemLanguageModel.default.availability`
    /// - OpenAI: Checks for API key presence
    var isAvailable: Bool { get }
}
