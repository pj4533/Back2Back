import SwiftUI
import MusicKit

struct NowPlayingView: View {
    @State private var viewModel = NowPlayingViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            if let nowPlaying = viewModel.currentlyPlaying {
                expandedView(nowPlaying: nowPlaying)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    private func expandedView(nowPlaying: NowPlayingItem) -> some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)

            artworkView(for: nowPlaying.song, size: 250)
                .shadow(radius: 10)

            VStack(spacing: 8) {
                Text(nowPlaying.song.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(nowPlaying.song.artistName)
                    .font(.title3)
                    .foregroundColor(.secondary)

                if let albumTitle = nowPlaying.song.albumTitle {
                    Text(albumTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            progressBar(nowPlaying: nowPlaying)

            HStack(spacing: 40) {
                Button(action: viewModel.skipToPrevious) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }
                .disabled(!viewModel.canSkipToPrevious)

                Button(action: viewModel.togglePlayPause) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }

                Button(action: viewModel.skipToNext) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
                .disabled(!viewModel.canSkipToNext)
            }
            .foregroundColor(.primary)
            .padding()

            Spacer()
        }
        .padding(.vertical)
    }

    private func artworkView(for song: Song, size: CGFloat) -> some View {
        Group {
            if let artwork = song.artwork {
                AsyncImage(url: artwork.url(width: Int(size), height: Int(size))) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                .frame(width: size, height: size)
                .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: size, height: size)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.3))
                            .foregroundColor(.gray)
                    )
            }
        }
    }

    private func progressBar(nowPlaying: NowPlayingItem) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: progressWidth(for: nowPlaying, in: geometry.size.width), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)

            HStack {
                Text(formatTime(nowPlaying.playbackTime))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatTime(nowPlaying.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private func progressWidth(for nowPlaying: NowPlayingItem, in totalWidth: CGFloat) -> CGFloat {
        guard nowPlaying.duration > 0 else { return 0 }
        let progress = nowPlaying.playbackTime / nowPlaying.duration
        return totalWidth * min(max(progress, 0), 1)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}