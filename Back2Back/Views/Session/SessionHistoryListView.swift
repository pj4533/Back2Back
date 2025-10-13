//
//  SessionHistoryListView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//

import SwiftUI
import Observation

struct SessionHistoryListView: View {
    @Bindable private var sessionService: SessionService
    private let sessionViewModel: SessionViewModel
    private let favoritesService: FavoritesService
    private let personaService: PersonaService
    private let statusMessageService: StatusMessageService

    init(
        sessionService: SessionService,
        sessionViewModel: SessionViewModel,
        favoritesService: FavoritesService,
        personaService: PersonaService,
        statusMessageService: StatusMessageService
    ) {
        self._sessionService = Bindable(wrappedValue: sessionService)
        self.sessionViewModel = sessionViewModel
        self.favoritesService = favoritesService
        self.personaService = personaService
        self.statusMessageService = statusMessageService
    }

    var body: some View {
        if sessionService.sessionHistory.isEmpty && sessionService.songQueue.isEmpty && !sessionService.isAIThinking {
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
                        ForEach(sessionService.sessionHistory) { sessionSong in
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
                        if sessionService.isAIThinking {
                            AILoadingCell(
                                sessionService: sessionService,
                                statusMessageService: statusMessageService,
                                personaService: personaService
                            )
                                .id("ai-loading")
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                        }

                        // Show queue (upcoming songs)
                        ForEach(sessionService.songQueue) { sessionSong in
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
                    .animation(.spring(response: 0.3), value: sessionService.sessionHistory.count + sessionService.songQueue.count + (sessionService.isAIThinking ? 1 : 0))
                }
                .onChange(of: sessionService.sessionHistory.count + sessionService.songQueue.count + (sessionService.isAIThinking ? 1 : 0)) { _, _ in
                    withAnimation {
                        // Scroll to last item (whether AI loading, queue, or history)
                        if sessionService.isAIThinking {
                            proxy.scrollTo("ai-loading", anchor: .bottom)
                        } else if let lastQueued = sessionService.songQueue.last {
                            proxy.scrollTo(lastQueued.id, anchor: .bottom)
                        } else if let lastHistory = sessionService.sessionHistory.last {
                            proxy.scrollTo(lastHistory.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}
