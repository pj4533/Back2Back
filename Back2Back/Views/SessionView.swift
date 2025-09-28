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
    @State private var sessionService = SessionService.shared
    @State private var musicService = MusicService.shared
    @State private var sessionViewModel = SessionViewModel.shared
    @State private var showSongPicker = false

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
                .padding(.horizontal)
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))

            // Session history
            if sessionService.sessionHistory.isEmpty {
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
                            ForEach(sessionService.sessionHistory) { sessionSong in
                                SessionSongRow(sessionSong: sessionSong)
                                    .id(sessionSong.id)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                        .padding()
                        .animation(.spring(response: 0.3), value: sessionService.sessionHistory.count)
                    }
                    .onChange(of: sessionService.sessionHistory.count) { _, _ in
                        withAnimation {
                            if let lastSong = sessionService.sessionHistory.last {
                                proxy.scrollTo(lastSong.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Bottom controls
            VStack(spacing: 12) {
                // User song selection button
                Button(action: {
                    B2BLog.ui.debug("User tapped select song button")
                    showSongPicker = true
                }) {
                    Label(
                        sessionService.currentTurn == .user ? "Select Your Track" : "Skip AI Turn",
                        systemImage: "plus.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        sessionService.currentTurn == .user ? Color.blue : Color.orange
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(sessionService.isAIThinking)
                .opacity(sessionService.isAIThinking ? 0.5 : 1.0)

                // Clear session button (if there's history)
                if !sessionService.sessionHistory.isEmpty {
                    Button(action: {
                        B2BLog.ui.debug("User tapped reset session")
                        withAnimation {
                            sessionService.resetSession()
                        }
                    }) {
                        Label("Reset Session", systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
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
    }

    @MainActor
    private func handleUserSongSelection(_ song: Song) async {
        B2BLog.session.info("User selected song: \(song.title)")

        // Use SessionViewModel to handle the selection
        await sessionViewModel.handleUserSongSelection(song)

        // After user selection, AI should select next if OpenAI is configured
        if sessionService.currentTurn == .ai && OpenAIClient.shared.isConfigured {
            // Give a small delay for UX
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await sessionViewModel.triggerAISelection()
        }
    }
}

struct SessionSongRow: View {
    let sessionSong: SessionSong

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
                Text(sessionSong.song.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(sessionSong.song.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let rationale = sessionSong.rationale {
                    Text(rationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Timestamp
            Text(formatTime(sessionSong.timestamp))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
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