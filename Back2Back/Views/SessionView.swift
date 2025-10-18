//
//  SessionView.swift
//  Back2Back
//
//  Created on 2025-09-27.
//  Refactored as part of Phase 1 architecture improvements (#20)
//  Refactored to use ViewModel only (Issue #56, 2025-10-18)
//

import SwiftUI
import MusicKit
import OSLog

struct SessionView: View {
    let viewModel: SessionViewModel

    @Environment(\.services) private var services

    @State private var showSongPicker = false
    @State private var showNowPlaying = false

    var body: some View {
        guard let services = services else {
            return AnyView(Text("Loading..."))
        }

        return AnyView(VStack(spacing: 0) {
            SessionHeaderView(
                viewModel: services.sessionHeaderViewModel,
                onNowPlayingTapped: { showNowPlaying = true }
            )

            SessionHistoryListView(
                viewModel: services.sessionHistoryViewModel,
                sessionViewModel: viewModel,
                favoritesService: services.favoritesService,
                personaService: services.personaService
            )

            SessionActionButtons(
                viewModel: services.sessionActionButtonsViewModel,
                sessionViewModel: viewModel,
                onUserSelectTapped: { showSongPicker = true },
                onAIStartTapped: {
                    Task {
                        B2BLog.session.info("User requested AI to start first")
                        await viewModel.handleAIStartFirst()
                    }
                },
                onDirectionOptionSelected: { option in
                    Task {
                        B2BLog.session.info("User selected direction option: \(option.buttonLabel)")
                        await viewModel.handleDirectionChange(option: option)
                    }
                }
            )
        }
        .sheet(isPresented: $showSongPicker) {
            NavigationStack {
                MusicSearchView(
                    onSongSelected: { song in
                        Task {
                            B2BLog.session.info("User selected song: \(song.title)")
                            await viewModel.handleUserSongSelection(song)
                        }
                        showSongPicker = false
                    }
                )
                .navigationTitle("Select a Track")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showSongPicker = false
                        }
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
        })
    }
}

#Preview {
    let services = ServiceContainer()
    SessionView(viewModel: services.sessionViewModel)
        .withServices(services)
}