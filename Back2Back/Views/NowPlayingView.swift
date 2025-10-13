import SwiftUI
import MusicKit
import Observation

struct NowPlayingView: View {
    @Bindable private var viewModel: NowPlayingViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: NowPlayingViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
    }

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

            HStack(spacing: 30) {
                // -15s button
                Button(action: viewModel.skipBackward) {
                    Image(systemName: "gobackward.15")
                        .font(.title3)
                }
                .disabled(!viewModel.canSkipToPrevious)

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

                // +15s button
                Button(action: viewModel.skipForward) {
                    Image(systemName: "goforward.15")
                        .font(.title3)
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

    // MARK: - Animation-Based Progress Bar
    // Uses TimelineView for smooth, GPU-accelerated updates
    // This approach is recommended by Apple engineers instead of polling
    // See: https://forums.developer.apple.com/forums/thread/687487
    private func progressBar(nowPlaying: NowPlayingItem) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                // 60fps updates for buttery-smooth progress bar animation
                // Only updates when playing (paused parameter stops animation when not playing)
                TimelineView(.animation(minimumInterval: 1.0/60.0, paused: !viewModel.isPlaying)) { context in
                    let currentTime = viewModel.getCurrentPlaybackTime()

                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)

                        // Progress indicator - animates smoothly via TimelineView
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(
                                width: progressWidth(
                                    current: currentTime,
                                    duration: nowPlaying.duration,
                                    in: geometry.size.width
                                ),
                                height: 4
                            )
                            .cornerRadius(2)
                    }
                    .contentShape(Rectangle()) // Make entire area tappable
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let time = calculateTime(
                                    from: value.location.x,
                                    in: geometry.size.width,
                                    duration: nowPlaying.duration
                                )
                                viewModel.seek(to: time)
                            }
                    )
                }
            }
            .frame(height: 20) // Increase hit area for better touch target

            // 2fps updates for time labels (lower frequency is fine for text)
            // Reduces state updates while maintaining smooth visual experience
            TimelineView(.animation(minimumInterval: 0.5, paused: !viewModel.isPlaying)) { context in
                let currentTime = viewModel.getCurrentPlaybackTime()

                HStack {
                    Text(formatTime(currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatTime(nowPlaying.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .onChange(of: viewModel.playbackState) { oldValue, newValue in
            // Reset animation base time when playback state changes
            // This ensures accuracy when play/pause/skip occurs
            viewModel.updateBasePlaybackTime()
        }
        .onAppear {
            // Initialize base time when view appears
            viewModel.updateBasePlaybackTime()
        }
    }

    private func progressWidth(current: TimeInterval, duration: TimeInterval, in totalWidth: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        let progress = current / duration
        return totalWidth * min(max(progress, 0), 1)
    }

    private func calculateTime(from xPosition: CGFloat, in width: CGFloat, duration: TimeInterval) -> TimeInterval {
        let progress = max(0, min(1, xPosition / width))
        return duration * progress
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    let musicService = MusicService(
        authService: MusicAuthService(),
        searchService: MusicSearchService(),
        playbackService: MusicPlaybackService()
    )
    return NowPlayingView(viewModel: NowPlayingViewModel(musicService: musicService))
}
