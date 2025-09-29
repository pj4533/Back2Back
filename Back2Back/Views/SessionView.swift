//
//  SessionView.swift
//  Back2Back
//
//  Created on 2025-09-27.
//

import SwiftUI
import MusicKit
import OSLog

struct SessionView: View {
    // For @Observable objects, access directly without property wrappers
    // SwiftUI automatically tracks property access and updates the view
    private let sessionService = SessionService.shared
    private let sessionViewModel = SessionViewModel.shared
    private let musicService = MusicService.shared

    @State private var showSongPicker = false
    @State private var showNowPlaying = false

    // Check if user has already selected a song in the queue
    private var hasUserSelectedSong: Bool {
        sessionService.songQueue.contains { $0.selectedBy == .user }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Back2Back DJ Session")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                HStack {
                    Label(
                        "Turn: \(sessionService.currentTurn.rawValue)",
                        systemImage: sessionService.currentTurn == .user ? "person.fill" : "cpu"
                    )
                    .font(.headline)
                    .foregroundStyle(sessionService.currentTurn == .user ? .blue : .purple)

                    if sessionService.isAIThinking {
                        Spacer()
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("AI selecting...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

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
                        Button(action: { showNowPlaying = true }) {
                            Image(systemName: "music.note")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }

            // Session history and queue
            if sessionService.sessionHistory.isEmpty && sessionService.songQueue.isEmpty {
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
                                SessionSongRow(sessionSong: sessionSong)
                                    // Use composite ID to force re-render on status change
                                    .id("\(sessionSong.id)-\(sessionSong.queueStatus.description)")
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }

                            // Show queue (upcoming songs)
                            ForEach(sessionService.songQueue) { sessionSong in
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
                        .animation(.spring(response: 0.3), value: sessionService.sessionHistory.count + sessionService.songQueue.count)
                    }
                    .onChange(of: sessionService.sessionHistory.count + sessionService.songQueue.count) { _, _ in
                        withAnimation {
                            // Scroll to last item (whether in history or queue)
                            if let lastQueued = sessionService.songQueue.last {
                                proxy.scrollTo(lastQueued.id, anchor: .bottom)
                            } else if let lastHistory = sessionService.sessionHistory.last {
                                proxy.scrollTo(lastHistory.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Bottom controls
            VStack(spacing: 12) {
                // Show both buttons only at the very start (no history and no queue)
                if sessionService.sessionHistory.isEmpty && sessionService.songQueue.isEmpty {
                    HStack(spacing: 12) {
                        // User goes first button
                        Button(action: {
                            B2BLog.ui.debug("User tapped select song button")
                            showSongPicker = true
                        }) {
                            Label(
                                "I'll Start",
                                systemImage: "person.fill"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        // AI goes first button
                        Button(action: {
                            B2BLog.ui.debug("User tapped AI start button")
                            Task {
                                await handleAIStartFirst()
                            }
                        }) {
                            Label(
                                "AI Starts",
                                systemImage: "cpu"
                            )
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                } else if sessionService.currentTurn == .user && !hasUserSelectedSong {
                    // After session has started, only show user selection button on their turn
                    Button(action: {
                        B2BLog.ui.debug("User tapped select song button")
                        showSongPicker = true
                    }) {
                        Label(
                            "Select Your Track",
                            systemImage: "plus.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
        }
        .sheet(isPresented: $showSongPicker) {
            NavigationStack {
                MusicSearchView(
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
            NowPlayingView()
        }
    }

    @MainActor
    private func handleUserSongSelection(_ song: Song) async {
        B2BLog.session.info("User selected song: \(song.title)")

        // Use SessionViewModel to handle the selection
        // This will automatically queue the AI's next song
        await sessionViewModel.handleUserSongSelection(song)

        // No need to manually trigger AI selection anymore -
        // it will happen automatically when the user's song ends
    }

    @MainActor
    private func handleAIStartFirst() async {
        B2BLog.session.info("User requested AI to start first")

        // Let the SessionViewModel handle AI starting first
        await sessionViewModel.handleAIStartFirst()
    }
}

struct SessionSongRow: View {
    let sessionSong: SessionSong
    // Add computed property to force view updates when queue status changes
    private var statusId: String {
        "\(sessionSong.id)-\(sessionSong.queueStatus.description)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Turn indicator
            Circle()
                .fill(sessionSong.selectedBy == .user ? Color.blue : Color.purple)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: sessionSong.selectedBy == .user ? "person.fill" : "cpu")
                        .font(.caption)
                        .foregroundColor(.white)
                )

            // Song details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(sessionSong.song.title)
                        .font(.headline)
                        .lineLimit(1)

                    // Queue status badge
                    // Add animation to status changes
                    Group {
                        if sessionSong.queueStatus == .upNext {
                            Text("Up Next")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        } else if sessionSong.queueStatus == .playing {
                            HStack(spacing: 3) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.caption2)
                                Text("Now Playing")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        } else if sessionSong.queueStatus == .queuedIfUserSkips {
                            Text("Queued (AI continues)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: sessionSong.queueStatus)
                }

                Text(sessionSong.song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let rationale = sessionSong.rationale {
                    Text(rationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Timestamp or queue indicator
            VStack(alignment: .trailing, spacing: 2) {
                if sessionSong.queueStatus == .played {
                    Text(formatTime(sessionSong.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else if sessionSong.queueStatus == .queuedIfUserSkips {
                    // Additional visual hint for conditional queue
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    sessionSong.queueStatus == .playing || sessionSong.queueStatus == .upNext
                        ? Color(UIColor.systemBackground)
                        : (sessionSong.queueStatus == .queuedIfUserSkips
                            ? Color(UIColor.secondarySystemGroupedBackground).opacity(0.6)
                            : Color(UIColor.secondarySystemGroupedBackground))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    sessionSong.queueStatus == .playing ? Color.blue.opacity(0.5) :
                    (sessionSong.queueStatus == .upNext ? Color.green.opacity(0.3) :
                    (sessionSong.queueStatus == .queuedIfUserSkips ? Color.orange.opacity(0.2) : Color.clear)),
                    lineWidth: sessionSong.queueStatus == .playing ? 2 : 1
                )
        )
        .opacity(sessionSong.queueStatus == .queuedIfUserSkips ? 0.85 : 1.0)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    SessionView()
}