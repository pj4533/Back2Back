//
//  AIModelConfig.swift
//  Back2Back
//
//  Created for GitHub issue #14
//

import Foundation
import SwiftUI
import OSLog

/// Music matching strategy type
enum MusicMatcherType: String, Codable, CaseIterable {
    case stringBased = "string_based"
    case llmBased = "llm_based"

    var displayName: String {
        switch self {
        case .stringBased: return "String-Based (Default)"
        case .llmBased: return "LLM-Based (Apple Intelligence)"
        }
    }

    var description: String {
        switch self {
        case .stringBased:
            return "Fast and reliable string matching with normalization"
        case .llmBased:
            return "AI-powered semantic matching (requires iOS 26+ and Apple Intelligence)"
        }
    }
}

/// Configuration for AI model behavior in song selection
/// Note: These settings only apply to song selection, not style guide generation
struct AIModelConfig: Codable, Equatable {
    /// Model to use for song selection: "gpt-5", "gpt-5-mini", or "gpt-5-nano"
    var songSelectionModel: String

    /// Reasoning effort level for song selection
    var songSelectionReasoningLevel: ReasoningEffort

    /// Music matching strategy (default: string-based)
    var musicMatcher: MusicMatcherType

    /// Number of songs to cache per persona (default: 50)
    var songCacheSize: Int

    /// Default configuration uses GPT-5 with low reasoning for all song selections
    static let `default` = AIModelConfig(
        songSelectionModel: "gpt-5",
        songSelectionReasoningLevel: .low,
        musicMatcher: .stringBased,
        songCacheSize: 50
    )

    init(songSelectionModel: String = "gpt-5", songSelectionReasoningLevel: ReasoningEffort = .low, musicMatcher: MusicMatcherType = .stringBased, songCacheSize: Int = 50) {
        self.songSelectionModel = songSelectionModel
        self.songSelectionReasoningLevel = songSelectionReasoningLevel
        self.musicMatcher = musicMatcher
        self.songCacheSize = songCacheSize
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
