//
//  SessionView.swift
//  Back2Back
//
//  Created on 2025-09-27.
//  Refactored as part of Phase 1 architecture improvements (#20)
//

import SwiftUI
import MusicKit
import OSLog
import Observation

struct SessionView: View {
    @Bindable private var sessionViewModel: SessionViewModel
    @Bindable private var sessionService: SessionService
    @Bindable private var musicService: MusicService
    private let favoritesService: FavoritesService
    private let personaService: PersonaService
    private let statusMessageService: StatusMessageService
    private let makeMusicSearchViewModel: () -> MusicSearchViewModel
    private let makeNowPlayingViewModel: () -> NowPlayingViewModel

    @State private var showSongPicker = false
    @State private var showNowPlaying = false

    init(
        sessionViewModel: SessionViewModel,
        sessionService: SessionService,
        musicService: MusicService,
        favoritesService: FavoritesService,
        personaService: PersonaService,
        statusMessageService: StatusMessageService,
        makeMusicSearchViewModel: @escaping () -> MusicSearchViewModel,
        makeNowPlayingViewModel: @escaping () -> NowPlayingViewModel
    ) {
        self._sessionViewModel = Bindable(wrappedValue: sessionViewModel)
        self._sessionService = Bindable(wrappedValue: sessionService)
        self._musicService = Bindable(wrappedValue: musicService)
        self.favoritesService = favoritesService
        self.personaService = personaService
        self.statusMessageService = statusMessageService
        self.makeMusicSearchViewModel = makeMusicSearchViewModel
        self.makeNowPlayingViewModel = makeNowPlayingViewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            SessionHeaderView(
                sessionService: sessionService,
                musicService: musicService,
                onNowPlayingTapped: { showNowPlaying = true }
            )

            SessionHistoryListView(
                sessionService: sessionService,
                sessionViewModel: sessionViewModel,
                favoritesService: favoritesService,
                personaService: personaService,
                statusMessageService: statusMessageService
            )

            SessionActionButtons(
                sessionService: sessionService,
                sessionViewModel: sessionViewModel,
                onUserSelectTapped: { showSongPicker = true },
                onAIStartTapped: {
                    Task { await handleAIStartFirst() }
                },
                onDirectionOptionSelected: { option in
                    Task { await handleDirectionChange(option: option) }
                }
            )
        }
        .sheet(isPresented: $showSongPicker) {
            NavigationStack {
                MusicSearchView(
                    viewModel: makeMusicSearchViewModel(),
                    onSongSelected: { song in
                        Task {
                            await handleUserSongSelection(song)
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
            NowPlayingView(viewModel: makeNowPlayingViewModel())
        }
    }

    @MainActor
    private func handleUserSongSelection(_ song: Song) async {
        B2BLog.session.info("User selected song: \(song.title)")
        await sessionViewModel.handleUserSongSelection(song)
    }

    @MainActor
    private func handleAIStartFirst() async {
        B2BLog.session.info("User requested AI to start first")
        await sessionViewModel.handleAIStartFirst()
    }

    @MainActor
    private func handleDirectionChange(option: DirectionOption) async {
        B2BLog.session.info("User selected direction option: \(option.buttonLabel)")
        await sessionViewModel.handleDirectionChange(option: option)
    }
}

#Preview {
    let dependencies = AppDependencies()
    return SessionView(
        sessionViewModel: dependencies.sessionViewModel,
        sessionService: dependencies.sessionService,
        musicService: dependencies.musicService,
        favoritesService: dependencies.favoritesService,
        personaService: dependencies.personaService,
        statusMessageService: dependencies.statusMessageService,
        makeMusicSearchViewModel: { MusicSearchViewModel(musicService: dependencies.musicService) },
        makeNowPlayingViewModel: { NowPlayingViewModel(musicService: dependencies.musicService) }
    )
}
