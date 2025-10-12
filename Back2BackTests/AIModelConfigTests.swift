//
//  AIModelConfigTests.swift
//  Back2BackTests
//
//  Created for GitHub issue #14
//

import Testing
import Foundation
@testable import Back2Back

@Suite("AIModelConfig Tests")
struct AIModelConfigTests {
    
    @Test("Default configuration has expected values")
    func testDefaultConfiguration() {
        let config = AIModelConfig.default

        #expect(config.songSelectionModel == "automatic")
        #expect(config.songSelectionReasoningLevel == .low)
    }
    
    @Test("Configuration can be encoded and decoded")
    func testEncodingDecoding() throws {
        let original = AIModelConfig(
            songSelectionModel: "gpt-5-mini",
            songSelectionReasoningLevel: .medium
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AIModelConfig.self, from: data)
        
        #expect(decoded.songSelectionModel == original.songSelectionModel)
        #expect(decoded.songSelectionReasoningLevel == original.songSelectionReasoningLevel)
    }
    
    @Test("Configuration can be stored in UserDefaults")
    func testUserDefaultsPersistence() throws {
        // Use a unique key for testing
        let testKey = "aiModelConfig_test_\(UUID().uuidString)"
        
        let config = AIModelConfig(
            songSelectionModel: "gpt-5-nano",
            songSelectionReasoningLevel: .high
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        UserDefaults.standard.set(data, forKey: testKey)
        
        // Retrieve and decode
        guard let retrievedData = UserDefaults.standard.data(forKey: testKey) else {
            Issue.record("Failed to retrieve data from UserDefaults")
            return
        }
        
        let decoder = JSONDecoder()
        let retrievedConfig = try decoder.decode(AIModelConfig.self, from: retrievedData)
        
        #expect(retrievedConfig.songSelectionModel == config.songSelectionModel)
        #expect(retrievedConfig.songSelectionReasoningLevel == config.songSelectionReasoningLevel)
        
        // Cleanup
        UserDefaults.standard.removeObject(forKey: testKey)
    }
    
    @Test("All reasoning effort levels are supported")
    func testReasoningEffortLevels() {
        let levels: [ReasoningEffort] = [.minimal, .low, .medium, .high]
        
        for level in levels {
            let config = AIModelConfig(
                songSelectionModel: "gpt-5",
                songSelectionReasoningLevel: level
            )
            
            #expect(config.songSelectionReasoningLevel == level)
        }
    }
    
    @Test("Configuration equality works correctly")
    func testEquality() {
        let config1 = AIModelConfig(
            songSelectionModel: "gpt-5",
            songSelectionReasoningLevel: .low
        )
        
        let config2 = AIModelConfig(
            songSelectionModel: "gpt-5",
            songSelectionReasoningLevel: .low
        )
        
        let config3 = AIModelConfig(
            songSelectionModel: "gpt-5-mini",
            songSelectionReasoningLevel: .low
        )
        
        #expect(config1 == config2)
        #expect(config1 != config3)
    }
    
    @Test("All model options can be configured")
    func testModelOptions() {
        let models = ["gpt-5", "gpt-5-mini", "gpt-5-nano"]

        for model in models {
            let config = AIModelConfig(
                songSelectionModel: model,
                songSelectionReasoningLevel: .low
            )

            #expect(config.songSelectionModel == model)
        }
    }

    @Test("Automatic mode resolves to nano/low for first song")
    func testAutomaticModeFirstSong() {
        let config = AIModelConfig(
            songSelectionModel: "automatic",
            songSelectionReasoningLevel: .low
        )

        let resolved = config.resolveConfiguration(isFirstSong: true)

        #expect(resolved.songSelectionModel == "gpt-5-nano")
        #expect(resolved.songSelectionReasoningLevel == .low)
    }

    @Test("Automatic mode resolves to gpt-5/low for subsequent songs")
    func testAutomaticModeSubsequentSongs() {
        let config = AIModelConfig(
            songSelectionModel: "automatic",
            songSelectionReasoningLevel: .low
        )

        let resolved = config.resolveConfiguration(isFirstSong: false)

        #expect(resolved.songSelectionModel == "gpt-5")
        #expect(resolved.songSelectionReasoningLevel == .low)
    }

    @Test("Non-automatic mode returns unchanged configuration")
    func testNonAutomaticModeUnchanged() {
        let config = AIModelConfig(
            songSelectionModel: "gpt-5-mini",
            songSelectionReasoningLevel: .medium
        )

        let resolvedFirst = config.resolveConfiguration(isFirstSong: true)
        let resolvedLater = config.resolveConfiguration(isFirstSong: false)

        #expect(resolvedFirst == config)
        #expect(resolvedLater == config)
    }
}
