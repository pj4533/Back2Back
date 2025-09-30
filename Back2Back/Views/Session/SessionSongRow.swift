//
//  SessionSongRow.swift
//  Back2Back
//
//  Created on 2025-09-30.
//  Extracted from SessionView.swift
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
