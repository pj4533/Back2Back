//
//  SessionHeaderView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//  Refactored to use ViewModel only (Issue #56, 2025-10-18)
//

import SwiftUI

struct SessionHeaderView: View {
    let viewModel: SessionHeaderViewModel
    let onNowPlayingTapped: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Back2Back DJ Session")
                .font(.largeTitle)
                .fontWeight(.bold)

            Label(
                "Turn: \(viewModel.currentTurn)",
                systemImage: viewModel.turnIcon
            )
            .font(.headline)
            .foregroundStyle(viewModel.turnColor == .user ? .blue : .purple)

            Text("AI Persona: \(viewModel.personaName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            .padding(.horizontal)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.hasNowPlaying {
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
