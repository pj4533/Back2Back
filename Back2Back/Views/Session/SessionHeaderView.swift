//
//  SessionHeaderView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView.swift
//

import SwiftUI

struct SessionHeaderView: View {
    let currentTurn: TurnType
    let personaName: String
    let showNowPlayingButton: Bool
    let onNowPlayingTapped: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Back2Back DJ Session")
                .font(.largeTitle)
                .fontWeight(.bold)

            Label(
                "Turn: \(currentTurn.rawValue)",
                systemImage: currentTurn == .user ? "person.fill" : "cpu"
            )
            .font(.headline)
            .foregroundStyle(currentTurn == .user ? .blue : .purple)

            Text("AI Persona: \(personaName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            .padding(.horizontal)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if showNowPlayingButton {
                    Button(action: onNowPlayingTapped) {
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
}
