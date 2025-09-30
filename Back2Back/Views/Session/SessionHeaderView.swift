//
//  SessionHeaderView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//

import SwiftUI

struct SessionHeaderView: View {
    private let sessionService = SessionService.shared
    private let musicService = MusicService.shared

    let onNowPlayingTapped: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Back2Back DJ Session")
                .font(.largeTitle)
                .fontWeight(.bold)

            Label(
                "Turn: \(sessionService.currentTurn.rawValue)",
                systemImage: sessionService.currentTurn == .user ? "person.fill" : "cpu"
            )
            .font(.headline)
            .foregroundStyle(sessionService.currentTurn == .user ? .blue : .purple)

            Text("AI Persona: \(sessionService.currentPersonaName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            .padding(.horizontal)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if musicService.currentlyPlaying != nil {
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
