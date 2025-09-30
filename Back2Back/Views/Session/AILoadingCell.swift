//
//  AILoadingCell.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//  Fixed Timer leak by using TimelineView instead of Timer.scheduledTimer
//

import SwiftUI

struct AILoadingCell: View {
    @State private var isAnimating = false

    private let loadingStates = [
        ("brain.head.profile", "Analyzing the vibe..."),
        ("music.note.list", "Searching the catalog..."),
        ("sparkles", "Finding the perfect track...")
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2.0)) { context in
            let currentPhase = Int(context.date.timeIntervalSince1970 / 2.0) % loadingStates.count

            HStack(spacing: 12) {
                // Turn indicator - animated CPU icon
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.pink, Color.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundColor(.white)
                            .symbolEffect(.pulse, options: .repeating)
                    )

                // Loading content
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: loadingStates[currentPhase].0)
                            .font(.title3)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .symbolEffect(.bounce, options: .repeating)

                        Text(loadingStates[currentPhase].1)
                            .font(.headline)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    // Animated dots
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.purple.opacity(0.6))
                                .frame(width: 6, height: 6)
                                .scaleEffect(isAnimating && index % 3 == currentPhase % 3 ? 1.2 : 0.8)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                    value: isAnimating
                                )
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.1),
                                Color.pink.opacity(0.1),
                                Color.orange.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.purple.opacity(0.4), .pink.opacity(0.4), .orange.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .onAppear {
                isAnimating = true
            }
        }
    }
}
