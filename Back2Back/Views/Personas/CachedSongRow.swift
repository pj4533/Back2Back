//
//  CachedSongRow.swift
//  Back2Back
//
//  Created on 2025-10-18.
//

import SwiftUI

struct CachedSongRow: View {
    let cachedSong: CachedSong

    var body: some View {
        HStack(spacing: 12) {
            // Placeholder artwork icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)

                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Song details
            VStack(alignment: .leading, spacing: 4) {
                Text(cachedSong.songTitle)
                    .font(.headline)
                    .lineLimit(1)

                Text(cachedSong.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Added: \(formatDate(cachedSong.selectedAt))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // Less than 60 seconds - show seconds
        if interval < 60 {
            let seconds = Int(interval)
            return seconds <= 1 ? "1 second ago" : "\(seconds) seconds ago"
        }

        // Less than 60 minutes - show minutes
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }

        // Less than 24 hours - show hours
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }

        // Less than 7 days - show days
        if interval < 604800 {
            let days = Int(interval / 86400)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }

        // 7 days or more - show actual date
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    List {
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "The Beatles",
                songTitle: "Come Together",
                selectedAt: Date().addingTimeInterval(-30) // 30 seconds ago
            )
        )
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "David Bowie",
                songTitle: "Heroes",
                selectedAt: Date().addingTimeInterval(-300) // 5 minutes ago
            )
        )
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "Queen",
                songTitle: "Bohemian Rhapsody",
                selectedAt: Date().addingTimeInterval(-7200) // 2 hours ago
            )
        )
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "Pink Floyd",
                songTitle: "Comfortably Numb",
                selectedAt: Date().addingTimeInterval(-172800) // 2 days ago
            )
        )
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "Led Zeppelin",
                songTitle: "Stairway to Heaven",
                selectedAt: Date().addingTimeInterval(-864000) // 10 days ago
            )
        )
    }
}
