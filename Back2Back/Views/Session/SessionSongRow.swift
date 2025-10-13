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
import Observation

struct SessionSongRow: View {
    let sessionSong: SessionSong
    @Bindable private var sessionViewModel: SessionViewModel
    @Bindable private var favoritesService: FavoritesService
    @Bindable private var personaService: PersonaService

    init(
        sessionSong: SessionSong,
        sessionViewModel: SessionViewModel,
        favoritesService: FavoritesService,
        personaService: PersonaService
    ) {
        self.sessionSong = sessionSong
        self._sessionViewModel = Bindable(wrappedValue: sessionViewModel)
        self._favoritesService = Bindable(wrappedValue: favoritesService)
        self._personaService = Bindable(wrappedValue: personaService)
    }

    // Add computed property to force view updates when queue status changes
    private var statusId: String {
        "\(sessionSong.id)-\(sessionSong.queueStatus.description)"
    }

    // Determine if this cell is tappable
    private var isTappable: Bool {
        sessionSong.queueStatus == .upNext || sessionSong.queueStatus == .queuedIfUserSkips
    }

    // Check if this song is favorited
    private var isFavorited: Bool {
        favoritesService.isFavorited(songId: sessionSong.song.id.rawValue)
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

            // Song details with improved layout
            VStack(alignment: .leading, spacing: 4) {
                // First row: Title + Status Badge
                HStack(alignment: .top, spacing: 8) {
                    Text(sessionSong.song.title)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Status badge - only takes minimal space needed
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
                    .fixedSize()
                    .animation(.easeInOut(duration: 0.3), value: sessionSong.queueStatus)
                }

                // Second row: Artist, metadata, and rationale with full width
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
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

                    // Favorite button - fixed 44x44 hit area
                    Button(action: {
                        B2BLog.ui.info("User tapped favorite button for: \(sessionSong.song.title)")
                        favoritesService.toggleFavorite(
                            sessionSong: sessionSong,
                            personaName: personaService.selectedPersona?.name ?? "Unknown",
                            personaId: personaService.selectedPersona?.id ?? UUID()
                        )
                    }) {
                        Image(systemName: isFavorited ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(isFavorited ? .red : .gray)
                            .frame(width: 44, height: 44) // Larger hit area
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain) // Prevent button from inheriting row's tap gesture
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
