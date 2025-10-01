//
//  SessionSongRow.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView as part of Phase 1 refactoring (#20)
//

import SwiftUI
import MusicKit
import OSLog

struct SessionSongRow: View {
    let sessionSong: SessionSong
    private let sessionViewModel = SessionViewModel.shared

    // Add computed property to force view updates when queue status changes
    private var statusId: String {
        "\(sessionSong.id)-\(sessionSong.queueStatus.description)"
    }

    // Determine if this cell is tappable
    private var isTappable: Bool {
        sessionSong.queueStatus == .upNext || sessionSong.queueStatus == .queuedIfUserSkips
    }

    var body: some View {
        rowContent
            .contentShape(Rectangle()) // Make entire cell tappable
            .onTapGesture {
                if isTappable {
                    B2BLog.ui.info("User tapped queued song to skip ahead: \(sessionSong.song.title)")
                    Task {
                        await sessionViewModel.skipToQueuedSong(sessionSong)
                    }
                }
            }
    }

    private var rowContent: some View {
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

                if !songMetadata.isEmpty {
                    Text(songMetadata)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let rationale = sessionSong.rationale {
                    Text(rationale)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Queue indicator
            if sessionSong.queueStatus == .queuedIfUserSkips {
                // Additional visual hint for conditional queue
                Image(systemName: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
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

    private func formatReleaseYear() -> String? {
        guard let releaseDate = sessionSong.song.releaseDate else { return nil }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: releaseDate)
        return String(year)
    }

    private func formatDuration() -> String? {
        guard let duration = sessionSong.song.duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var songMetadata: String {
        var components: [String] = []

        if let year = formatReleaseYear() {
            components.append(year)
        }

        if let duration = formatDuration() {
            components.append(duration)
        }

        return components.joined(separator: " • ")
    }
}
