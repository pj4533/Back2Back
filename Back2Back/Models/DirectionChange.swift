//
//  DirectionChange.swift
//  Back2Back
//
//  Created by Claude on 10/4/25.
//

import Foundation

/// Represents a musical direction change suggestion for the AI persona
///
/// This model contains both the detailed direction prompt that will be used
/// to guide the AI's song selection, and a user-facing button label that
/// summarizes the direction change in a few words.
struct DirectionChange: Codable, Equatable {
    /// The detailed direction prompt to append to the AI's song selection prompt
    /// Example: "Focus on tracks from the 1960s-70s era with analog warmth"
    let directionPrompt: String

    /// The short, user-facing label to display on the direction change button
    /// Example: "Older tracks"
    let buttonLabel: String
}
