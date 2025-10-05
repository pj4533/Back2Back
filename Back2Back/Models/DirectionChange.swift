//
//  DirectionChange.swift
//  Back2Back
//
//  Created by Claude on 10/4/25.
//

import Foundation

/// Represents a single direction option for AI song selection
///
/// This model contains both the detailed direction prompt that will be used
/// to guide the AI's song selection, and a user-facing button label that
/// summarizes the direction change in a few words.
struct DirectionOption: Codable, Equatable, Identifiable {
    /// The detailed direction prompt to append to the AI's song selection prompt
    /// Example: "Focus on tracks from the 1960s-70s era with analog warmth"
    let directionPrompt: String

    /// The short, user-facing label to display in the menu
    /// Example: "Vintage vibes"
    let buttonLabel: String

    /// Unique identifier for the option (uses buttonLabel as ID)
    var id: String { buttonLabel }
}

/// Represents a collection of musical direction change suggestions for the AI persona
///
/// This model contains multiple direction options that are presented to the user
/// in a menu-based interaction pattern.
struct DirectionChange: Codable, Equatable {
    /// Array of direction options presented to the user
    let options: [DirectionOption]

    /// Convenience initializer for backward compatibility (single option)
    init(directionPrompt: String, buttonLabel: String) {
        self.options = [DirectionOption(directionPrompt: directionPrompt, buttonLabel: buttonLabel)]
    }

    /// Primary initializer with multiple options
    init(options: [DirectionOption]) {
        self.options = options
    }
}
