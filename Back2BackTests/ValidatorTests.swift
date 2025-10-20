//
//  ValidatorTests.swift
//  Back2BackTests
//
//  Created for GitHub issue #96
//  Tests for validator protocol abstraction and implementations
//

import Foundation
import Testing
import FoundationModels
@testable import Back2Back

@MainActor
struct ValidatorTests {
    // MARK: - Protocol Conformance Tests

    @Test func foundationModelsValidatorConformsToProtocol() async throws {
        let validator = FoundationModelsValidator()
        #expect(validator is SongValidatorProtocol)
    }

    // Note: OpenAI validator tests require full OpenAIClient which is difficult to mock
    // Availability and configuration tests are sufficient for protocol conformance

    // MARK: - Display Name Tests

    @Test func foundationModelsValidatorHasCorrectDisplayName() async throws {
        let validator = FoundationModelsValidator()
        #expect(validator.displayName == "Foundation Models (Local)")
    }

    // OpenAI validator display names are tested via ValidatorType tests below

    // MARK: - Availability Tests

    @Test func foundationModelsValidatorAvailabilityMatchesSystemModel() async throws {
        let validator = FoundationModelsValidator()
        let systemModelAvailable = SystemLanguageModel.default.availability == .available
        #expect(validator.isAvailable == systemModelAvailable)
    }

    // OpenAI validator availability is tested indirectly through configuration UI

    // MARK: - MockSongValidator Tests

    @Test func mockValidatorReturnsConfiguredResult() async throws {
        let expectedResult = ValidationResponse(
            isValid: true,
            reasoning: "Test reasoning",
            shortSummary: "Test summary"
        )
        let validator = MockSongValidator(validationResult: expectedResult)

        let persona = TestFixtures.mockPersona
        let song = MockSong.minimal()

        let result = await validator.validate(song: song, persona: persona)

        #expect(result?.isValid == expectedResult.isValid)
        #expect(result?.reasoning == expectedResult.reasoning)
        #expect(result?.shortSummary == expectedResult.shortSummary)
    }

    @Test func mockValidatorTracksValidationCalls() async throws {
        let validator = MockSongValidator()
        let persona = TestFixtures.mockPersona
        let song = MockSong.minimal(title: "Test Track", artist: "Test Band")

        #expect(validator.validateCallCount == 0)

        _ = await validator.validate(song: song, persona: persona)

        #expect(validator.validateCallCount == 1)
        #expect(validator.lastValidatedSongTitle == "Test Track")
        #expect(validator.lastValidatedSongArtist == "Test Band")
        #expect(validator.lastValidatedPersona?.id == persona.id)
    }

    @Test func mockValidatorResetClearsState() async throws {
        let validator = MockSongValidator()
        let persona = TestFixtures.mockPersona
        let song = MockSong.minimal()

        _ = await validator.validate(song: song, persona: persona)
        #expect(validator.validateCallCount == 1)

        validator.reset()

        #expect(validator.validateCallCount == 0)
        #expect(validator.lastValidatedSongTitle == nil)
        #expect(validator.lastValidatedSongArtist == nil)
        #expect(validator.lastValidatedPersona == nil)
    }

    // MARK: - Fail-Open Behavior
    // Fail-open behavior is tested via integration tests with actual validators
}

// MARK: - ValidatorType Tests

struct ValidatorTypeTests {
    @Test func allValidatorTypesHaveDisplayNames() {
        for type in ValidatorType.allCases {
            #expect(!type.displayName.isEmpty)
        }
    }

    @Test func allValidatorTypesHaveDescriptions() {
        for type in ValidatorType.allCases {
            #expect(!type.description.isEmpty)
        }
    }

    @Test func foundationModelsDoesNotRequireNetwork() {
        #expect(ValidatorType.foundationModels.requiresNetwork == false)
    }

    @Test func openAIValidatorsRequireNetwork() {
        #expect(ValidatorType.openAILow.requiresNetwork == true)
        #expect(ValidatorType.openAIMedium.requiresNetwork == true)
        #expect(ValidatorType.openAIHigh.requiresNetwork == true)
    }

    @Test func foundationModelsHasNoReasoningEffort() {
        #expect(ValidatorType.foundationModels.reasoningEffort == nil)
    }

    @Test func openAIValidatorsHaveCorrectReasoningEffort() {
        #expect(ValidatorType.openAILow.reasoningEffort == .low)
        #expect(ValidatorType.openAIMedium.reasoningEffort == .medium)
        #expect(ValidatorType.openAIHigh.reasoningEffort == .high)
    }
}

// MARK: - AIModelConfig Validator Integration Tests

struct AIModelConfigValidatorTests {
    @Test func defaultConfigHasFoundationModelsValidator() {
        let config = AIModelConfig.default
        #expect(config.validatorType == .foundationModels)
    }

    @Test func configCanBeUpdatedWithDifferentValidators() {
        var config = AIModelConfig.default

        config.validatorType = .openAILow
        #expect(config.validatorType == .openAILow)

        config.validatorType = .openAIMedium
        #expect(config.validatorType == .openAIMedium)

        config.validatorType = .openAIHigh
        #expect(config.validatorType == .openAIHigh)

        config.validatorType = .foundationModels
        #expect(config.validatorType == .foundationModels)
    }

    @Test func configCanBeEncodedAndDecoded() throws {
        var config = AIModelConfig.default
        config.validatorType = .openAIMedium

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(AIModelConfig.self, from: data)

        #expect(decodedConfig.validatorType == .openAIMedium)
    }
}
