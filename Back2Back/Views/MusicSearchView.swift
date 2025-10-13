import SwiftUI
import MusicKit

struct MusicSearchView: View {
    @Environment(\.services) private var services
    @State private var viewModel: MusicSearchViewModel?
    @FocusState private var isSearchFieldFocused: Bool

    // Optional callback for when a song is selected (for modal usage)
    var onSongSelected: ((Song) -> Void)?

    var body: some View {
        if let viewModel = viewModel {
            VStack(spacing: 0) {
                searchBar(viewModel: viewModel)

                if viewModel.isSearching {
                    loadingView
                } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                    emptyStateView
                } else if !viewModel.searchResults.isEmpty {
                    searchResultsList(viewModel: viewModel)
                } else {
                    instructionView
                }

                if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                }
            }
            .navigationTitle("Search Music")
            .navigationBarTitleDisplayMode(.large)
            .onDisappear {
                // Clean up any pending operations when view disappears
                viewModel.cancelAllOperations()
            }
        } else {
            Text("Loading...")
                .onAppear {
                    if let services = services {
                        self.viewModel = MusicSearchViewModel(musicService: services.musicService)
                    }
                }
        }
    }

    private func searchBar(viewModel: MusicSearchViewModel) -> some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            // Bind directly to ViewModel for single source of truth
            TextField("Search for songs, artists, or albums",
                     text: Binding(get: { viewModel.searchText }, set: { viewModel.searchText = $0 }))
                .onChange(of: viewModel.searchText) { _, newValue in
                    viewModel.updateSearchText(newValue)
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                // Disable smart punctuation for better search experience
                .disableAutocorrection(true)

            if !viewModel.searchText.isEmpty {
                Button(action: {
                    viewModel.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func searchResultsList(viewModel: MusicSearchViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { result in
                    SearchResultRow(
                        result: result,
                        onTap: {
                            if let callback = onSongSelected {
                                // Use the callback if provided (modal mode)
                                callback(result.song)
                            } else {
                                // Use the default behavior (standalone mode)
                                viewModel.selectSong(result.song)
                            }
                        }
                    )
                    .id(result.id)  // Ensure proper view identity

                    Divider()
                        .padding(.leading, 80)
                }
            }
        }
        .onAppear {
            // Preload artwork for visible results
            viewModel.preloadSearchResults()
        }
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView("Searching...")
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding()
            Text("No results found")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Try searching for a different song or artist")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var instructionView: some View {
        VStack {
            Spacer()
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .padding()
            Text("Search for Music")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Start typing to find songs from Apple Music")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(2)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding()
    }
}

struct SearchResultRow: View {
    let result: MusicSearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            // Perform tap action asynchronously to avoid blocking
            Task { @MainActor in
                onTap()
            }
        }) {
            HStack(spacing: 12) {
                artworkImage

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(result.artistName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let albumTitle = result.albumTitle {
                        Text(albumTitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "play.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var artworkImage: some View {
        Group {
            if let artwork = result.artwork {
                // Optimize image loading with smaller placeholder and caching
                AsyncImage(url: artwork.url(width: 60, height: 60),
                          transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                                    .scaleEffect(0.5)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                    }
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}
