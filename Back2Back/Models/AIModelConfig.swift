//
//  AIModelConfig.swift
//  Back2Back
//
//  Created for GitHub issue #14
//

import Foundation
import SwiftUI

/// Configuration for AI model behavior in song selection
/// Note: These settings only apply to song selection, not style guide generation
struct AIModelConfig: Codable, Equatable {
    /// Model to use for song selection (gpt-5, gpt-5-mini, gpt-5-nano)
    var songSelectionModel: String
    
    /// Reasoning effort level for song selection
    var songSelectionReasoningLevel: ReasoningEffort
    
    /// Default configuration
    static let `default` = AIModelConfig(
        songSelectionModel: "gpt-5",
        songSelectionReasoningLevel: .low
    )
    
    init(songSelectionModel: String = "gpt-5", songSelectionReasoningLevel: ReasoningEffort = .low) {
        self.songSelectionModel = songSelectionModel
        self.songSelectionReasoningLevel = songSelectionReasoningLevel
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
