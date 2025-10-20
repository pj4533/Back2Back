//
//  ValidationConfig.swift
//  Back2Back
//
//  Created for GitHub issue #96
//  Configuration types for song validator selection
//

import Foundation

/// Song validator implementation types
///
/// Each type represents a different validation strategy with unique trade-offs:
/// - Foundation Models: Fast, private, free, offline | Limited context window
/// - OpenAI: Better accuracy with full style guides | Slower, costs money, requires network
enum ValidatorType: String, Codable, CaseIterable {
    case foundationModels = "foundation_models"
    case openAILow = "openai_low"
    case openAIMedium = "openai_medium"
    case openAIHigh = "openai_high"

    /// User-facing display name
    var displayName: String {
        switch self {
        case .foundationModels:
            return "Foundation Models (Local)"
        case .openAILow:
            return "GPT-5 (Low Reasoning)"
        case .openAIMedium:
            return "GPT-5 (Medium Reasoning)"
        case .openAIHigh:
            return "GPT-5 (High Reasoning)"
        }
    }

    /// Description of trade-offs for this validator type
    var description: String {
        switch self {
        case .foundationModels:
            return "Fast, private, offline validation using on-device Apple Intelligence. Limited to persona description only."
        case .openAILow:
            return "Cloud-based validation with full style guide context. Low reasoning for faster results."
        case .openAIMedium:
            return "Cloud-based validation with full style guide context. Medium reasoning for balanced accuracy/speed."
        case .openAIHigh:
            return "Cloud-based validation with full style guide context. High reasoning for best accuracy."
        }
    }

    /// Reasoning effort level for OpenAI validators (nil for Foundation Models)
    var reasoningEffort: ReasoningEffort? {
        switch self {
        case .foundationModels:
            return nil
        case .openAILow:
            return .low
        case .openAIMedium:
            return .medium
        case .openAIHigh:
            return .high
        }
    }

    /// Whether this validator requires network connectivity
    var requiresNetwork: Bool {
        switch self {
        case .foundationModels:
            return false
        case .openAILow, .openAIMedium, .openAIHigh:
            return true
        }
    }
}
