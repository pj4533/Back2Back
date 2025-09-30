//
//  KeyboardToolbarGenerateButton.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from PersonaDetailView as part of Phase 1 refactoring (#20)
//

import SwiftUI

struct KeyboardToolbarGenerateButton: View {
    let hasStyleGuide: Bool
    let isGenerating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: hasStyleGuide ? "arrow.clockwise" : "sparkles.rectangle.stack.fill")
                Text(hasStyleGuide ? "Regenerate" : "Generate")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isGenerating)
        .buttonStyle(.plain) // Prevent default button styling
    }
}
