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
            // Artwork (with AsyncImage for URL or placeholder)
            if let artworkURL = cachedSong.artworkURL {
                AsyncImage(url: artworkURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                // Fallback placeholder for songs without artwork
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)

                    Image(systemName: "music.note")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
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
                selectedAt: Date().addingTimeInterval(-30), // 30 seconds ago
                artworkURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/d5/3a/6f/d53a6f7e-6f3e-2b9a-3b0a-9e5f5e5f5e5f/source/300x300bb.jpg")
            )
        )
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "David Bowie",
                songTitle: "Heroes",
                selectedAt: Date().addingTimeInterval(-300), // 5 minutes ago
                artworkURL: nil // Test backward compatibility
            )
        )
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "Queen",
                songTitle: "Bohemian Rhapsody",
                selectedAt: Date().addingTimeInterval(-7200), // 2 hours ago
                artworkURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/d5/3a/6f/d53a6f7e-6f3e-2b9a-3b0a-9e5f5e5f5e5f/source/300x300bb.jpg")
            )
        )
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "Pink Floyd",
                songTitle: "Comfortably Numb",
                selectedAt: Date().addingTimeInterval(-172800), // 2 days ago
                artworkURL: nil
            )
        )
        CachedSongRow(
            cachedSong: CachedSong(
                artist: "Led Zeppelin",
                songTitle: "Stairway to Heaven",
                selectedAt: Date().addingTimeInterval(-864000), // 10 days ago
                artworkURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/d5/3a/6f/d53a6f7e-6f3e-2b9a-3b0a-9e5f5e5f5e5f/source/300x300bb.jpg")
            )
        )
    }
}
