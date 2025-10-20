//
//  ValidationModels.swift
//  Back2Back
//
//  Created for GitHub issue #96
//  Shared models for song validation across all validator implementations
//

import Foundation
import FoundationModels

/// Response structure for persona-song validation
///
/// Used by all validator implementations (Foundation Models, OpenAI, etc.)
/// to return validation results in a consistent format.
@Generable
public struct ValidationResponse: Codable {
    /// true if song matches persona, false otherwise
    public let isValid: Bool

    /// Brief reasoning for the decision (1-2 sentences)
    public let reasoning: String

    /// Very short summary for UI display (max 10 words)
    public let shortSummary: String

    public init(isValid: Bool, reasoning: String, shortSummary: String) {
        self.isValid = isValid
        self.reasoning = reasoning
        self.shortSummary = shortSummary
    }
}
