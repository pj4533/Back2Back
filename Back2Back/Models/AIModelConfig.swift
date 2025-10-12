//
//  AIModelConfig.swift
//  Back2Back
//
//  Created for GitHub issue #14
//

import Foundation
import SwiftUI
import OSLog

/// Configuration for AI model behavior in song selection
/// Note: These settings only apply to song selection, not style guide generation
struct AIModelConfig: Codable, Equatable {
    /// Model to use for song selection: "gpt-5", "gpt-5-mini", "gpt-5-nano", or "automatic"
    var songSelectionModel: String

    /// Reasoning effort level for song selection
    var songSelectionReasoningLevel: ReasoningEffort

    /// Default configuration now uses automatic mode
    static let `default` = AIModelConfig(
        songSelectionModel: "automatic",
        songSelectionReasoningLevel: .low
    )

    init(songSelectionModel: String = "automatic", songSelectionReasoningLevel: ReasoningEffort = .low) {
        self.songSelectionModel = songSelectionModel
        self.songSelectionReasoningLevel = songSelectionReasoningLevel
    }

    /// Determines the actual configuration to use when "automatic" is selected
    /// - Parameter isFirstSong: Whether this is the first song of the session
    /// - Returns: The resolved AIModelConfig with concrete model and reasoning level
    func resolveConfiguration(isFirstSong: Bool) -> AIModelConfig {
        guard songSelectionModel == "automatic" else {
            return self
        }

        // Automatic logic: fast for first song, thoughtful for subsequent songs
        if isFirstSong {
            B2BLog.ai.info("🚀 Automatic mode: Using gpt-5-nano with low reasoning for first song (fast start)")
            return AIModelConfig(songSelectionModel: "gpt-5-nano", songSelectionReasoningLevel: .low)
        } else {
            B2BLog.ai.info("🎵 Automatic mode: Using gpt-5 with low reasoning for subsequent songs (thoughtful selection)")
            return AIModelConfig(songSelectionModel: "gpt-5", songSelectionReasoningLevel: .low)
        }
    }
}

/// Property wrapper for persisting AIModelConfig in UserDefaults
@propertyWrapper
struct AIModelConfigStorage: DynamicProperty {
    @AppStorage private var configData: Data
    
    init(wrappedValue: AIModelConfig = .default, _ key: String = "aiModelConfig") {
        let data = (try? JSONEncoder().encode(wrappedValue)) ?? Data()
        self._configData = AppStorage(wrappedValue: data, key)
    }
    
    var wrappedValue: AIModelConfig {
        get {
            guard let decoded = try? JSONDecoder().decode(AIModelConfig.self, from: configData) else {
                return .default
            }
            return decoded
        }
        nonmutating set {
            configData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    var projectedValue: Binding<AIModelConfig> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
}
