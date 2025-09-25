//
//  ContentView.swift
//  Back2Back
//
//  Created by PJ Gray on 9/25/25.
//

import SwiftUI
import MusicKit

struct ContentView: View {
    @StateObject private var musicService = MusicService.shared
    @State private var showNowPlaying = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if musicService.isAuthorized {
                    mainContent
                } else {
                    MusicAuthorizationView()
                }

                if musicService.currentlyPlaying != nil {
                    NowPlayingView()
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                }
            }
        }
        .onAppear {
            checkAuthorizationStatus()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView

            MusicSearchView()

            Spacer()
        }
        .navigationBarHidden(true)
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Back2Back")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Let's DJ together")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    private func checkAuthorizationStatus() {
        Task {
            let status = MusicAuthorization.currentStatus
            if status == .notDetermined {
                try? await musicService.requestAuthorization()
            }
        }
    }
}

#Preview {
    ContentView()
}
