//
//  SessionHistoryListView.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView.swift
//

import SwiftUI

struct SessionHistoryListView: View {
    let sessionHistory: [SessionSong]
    let songQueue: [SessionSong]
    let isAIThinking: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Show history (played songs)
                    ForEach(sessionHistory) { sessionSong in
                        SessionSongRow(sessionSong: sessionSong)
                            // Use composite ID to force re-render on status change
                            .id("\(sessionSong.id)-\(sessionSong.queueStatus.description)")
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Show AI loading cell if AI is thinking
                    if isAIThinking {
                        AILoadingCell()
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                    }

                    // Show queue (upcoming songs)
                    ForEach(songQueue) { sessionSong in
                        SessionSongRow(sessionSong: sessionSong)
                            // Use composite ID to force re-render on status change
                            .id("\(sessionSong.id)-\(sessionSong.queueStatus.description)")
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding()
                .animation(.spring(response: 0.3), value: sessionHistory.count + songQueue.count + (isAIThinking ? 1 : 0))
            }
            .onChange(of: sessionHistory.count + songQueue.count) { _, _ in
                withAnimation {
                    // Scroll to last item (whether in history or queue)
                    if let lastQueued = songQueue.last {
                        proxy.scrollTo(lastQueued.id, anchor: .bottom)
                    } else if let lastHistory = sessionHistory.last {
                        proxy.scrollTo(lastHistory.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
