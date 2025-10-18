//
//  SessionHeaderView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//

import SwiftUI

struct SessionHeaderView: View {
    @Environment(\.services) private var services

    let onNowPlayingTapped: () -> Void

    var body: some View {
        guard let services = services else {
            return AnyView(EmptyView())
        }

        return AnyView(VStack(spacing: 8) {
            Text("Back2Back DJ Session")
                .font(.largeTitle)
                .fontWeight(.bold)

            Label(
                "Turn: \(services.sessionService.currentTurn.rawValue)",
                systemImage: services.sessionService.currentTurn == .user ? "person.fill" : "cpu"
            )
            .font(.headline)
            .foregroundStyle(services.sessionService.currentTurn == .user ? .blue : .purple)

            Text("AI Persona: \(services.sessionService.currentPersonaName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            .padding(.horizontal)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if services.musicService.currentlyPlaying != nil {
                    Button(action: onNowPlayingTapped) {
                        Image(systemName: "music.note")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
        })
    }
}
