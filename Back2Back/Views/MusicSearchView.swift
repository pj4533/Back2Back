import SwiftUI
import MusicKit

struct MusicSearchView: View {
    @StateObject private var viewModel = MusicSearchViewModel()
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if viewModel.isSearching {
                loadingView
            } else if viewModel.searchResults.isEmpty && !viewModel.searchText.isEmpty {
                emptyStateView
            } else if !viewModel.searchResults.isEmpty {
                searchResultsList
            } else {
                instructionView
            }

            if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            }
        }
        .navigationTitle("Search Music")
        .navigationBarTitleDisplayMode(.large)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search for songs, artists, or albums", text: $viewModel.searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isSearchFieldFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !viewModel.searchText.isEmpty {
                Button(action: viewModel.clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults) { result in
                    SearchResultRow(
                        result: result,
                        onTap: { viewModel.selectSong(result.song) }
                    )
                    Divider()
                        .padding(.leading, 80)
                }
            }
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
        Button(action: onTap) {
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
                AsyncImage(url: artwork.url(width: 60, height: 60)) { image in
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