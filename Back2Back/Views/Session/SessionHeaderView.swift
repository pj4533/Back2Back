//
//  SessionHeaderView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//

import SwiftUI
import Observation

struct SessionHeaderView: View {
    @Bindable private var sessionService: SessionService
    @Bindable private var musicService: MusicService

    let onNowPlayingTapped: () -> Void

    init(
        sessionService: SessionService,
        musicService: MusicService,
        onNowPlayingTapped: @escaping () -> Void
    ) {
        self._sessionService = Bindable(wrappedValue: sessionService)
        self._musicService = Bindable(wrappedValue: musicService)
        self.onNowPlayingTapped = onNowPlayingTapped
    }

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
