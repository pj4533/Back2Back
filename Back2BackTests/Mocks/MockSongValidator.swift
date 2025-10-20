//
//  MockSongValidator.swift
//  Back2BackTests
//
//  Created for GitHub issue #96
//  Mock validator for testing validator abstraction
//

import Foundation
import MusicKit
@testable import Back2Back

@MainActor
final class MockSongValidator: SongValidatorProtocol {
    var displayName: String
    var isAvailable: Bool
    var validationResult: ValidationResponse?
    var validateCallCount = 0
    var lastValidatedSongTitle: String?
    var lastValidatedSongArtist: String?
    var lastValidatedPersona: Persona?

    init(
        displayName: String = "Mock Validator",
        isAvailable: Bool = true,
        validationResult: ValidationResponse? = nil
    ) {
        self.displayName = displayName
        self.isAvailable = isAvailable
        self.validationResult = validationResult
    }

    func validate(song: some SongProtocol, persona: Persona) async -> ValidationResponse? {
        validateCallCount += 1
        lastValidatedSongTitle = song.title
        lastValidatedSongArtist = song.artistName
        lastValidatedPersona = persona
        return validationResult
    }

    // Helper to reset state between tests
    func reset() {
        validateCallCount = 0
        lastValidatedSongTitle = nil
        lastValidatedSongArtist = nil
        lastValidatedPersona = nil
    }
}
