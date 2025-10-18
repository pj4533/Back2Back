//
//  SessionHistoryListView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//  Refactored to use ViewModel only (Issue #56, 2025-10-18)
//

import SwiftUI

struct SessionHistoryListView: View {
    let viewModel: SessionHistoryViewModel
    let sessionViewModel: SessionViewModel
    let favoritesService: FavoritesService
    let personaService: PersonaService

    var body: some View {
        if viewModel.isEmpty {
            ContentUnavailableView(
                "No Songs Yet",
                systemImage: "music.note.list",
                description: Text("Start your DJ session by selecting the first track")
            )
            .frame(maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Show history (played songs)
                        ForEach(viewModel.sessionHistory) { sessionSong in
                            SessionSongRow(
                                sessionSong: sessionSong,
                                sessionViewModel: sessionViewModel,
                                favoritesService: favoritesService,
                                personaService: personaService
                            )
                                // Composite ID needed: SessionSong has mutable queueStatus with immutable UUID
                                // SwiftUI needs to know when status changes on same song
                                .id("\(sessionSong.id)-\(sessionSong.queueStatus.description)")
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }

                        // Show AI loading cell if AI is thinking
                        if viewModel.isAIThinking {
                            AILoadingCell()
                                .id("ai-loading")
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                        }

                        // Show queue (upcoming songs)
                        ForEach(viewModel.songQueue) { sessionSong in
                            SessionSongRow(
                                sessionSong: sessionSong,
                                sessionViewModel: sessionViewModel,
                                favoritesService: favoritesService,
                                personaService: personaService
                            )
                                // Composite ID needed: SessionSong has mutable queueStatus with immutable UUID
                                // SwiftUI needs to know when status changes on same song
                                .id("\(sessionSong.id)-\(sessionSong.queueStatus.description)")
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .padding()
                    .animation(.spring(response: 0.3), value: viewModel.totalCount)
                }
                .onChange(of: viewModel.totalCount) { _, _ in
                    withAnimation {
                        // Scroll to last item (whether AI loading, queue, or history)
                        if viewModel.isAIThinking {
                            proxy.scrollTo("ai-loading", anchor: .bottom)
                        } else if let lastQueued = viewModel.songQueue.last {
                            proxy.scrollTo(lastQueued.id, anchor: .bottom)
                        } else if let lastHistory = viewModel.sessionHistory.last {
                            proxy.scrollTo(lastHistory.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}
