import SwiftUI
import MusicKit
import Observation

struct MusicAuthorizationView: View {
    @Bindable private var viewModel: MusicAuthViewModel

    init(viewModel: MusicAuthViewModel) {
        self._viewModel = Bindable(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.house")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .padding()

            Text("Music Access Required")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Back2Back needs access to your Apple Music library to play songs and create the ultimate DJ experience.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Text(viewModel.statusDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Spacer()

            if viewModel.canRequestAuthorization {
                Button(action: viewModel.requestAuthorization) {
                    Label("Grant Access", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(viewModel.isRequestingAuthorization)

                if viewModel.isRequestingAuthorization {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }

            if viewModel.shouldShowSettingsButton {
                VStack(spacing: 10) {
                    Text("Please enable Music access in Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button(action: viewModel.openSettings) {
                        Label("Open Settings", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.secondary.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
            }

            if viewModel.authorizationStatus == .restricted {
                Text("Music access is restricted on this device")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding()
            }
        }
        .padding()
        .onAppear {
            viewModel.checkCurrentAuthorizationStatus()
        }
    }
}

#Preview {
    let musicService = MusicService(
        authService: MusicAuthService(),
        searchService: MusicSearchService(),
        playbackService: MusicPlaybackService()
    )
    return MusicAuthorizationView(viewModel: MusicAuthViewModel(musicService: musicService))
}
