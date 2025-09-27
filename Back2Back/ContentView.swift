//
//  ContentView.swift
//  Back2Back
//
//  Created by PJ Gray on 9/25/25.
//

import SwiftUI
import MusicKit
import OSLog

struct ContentView: View {
    @StateObject private var musicService = MusicService.shared
    @State private var showNowPlaying = false
    @State private var showOpenAITest = false

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

                // OpenAI Test Button (for development)
                Button(action: { showOpenAITest = true }) {
                    Image(systemName: "bolt.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .sheet(isPresented: $showOpenAITest) {
                    OpenAITestView()
                }
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    private func checkAuthorizationStatus() {
        Task {
            let status = MusicAuthorization.currentStatus
            B2BLog.auth.debug("Checking authorization status on app launch: \(String(describing: status))")
            if status == .notDetermined {
                B2BLog.auth.info("Authorization not determined, requesting...")
                do {
                    try await musicService.requestAuthorization()
                } catch {
                    B2BLog.auth.error("❌ ContentView.checkAuthorizationStatus: \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
