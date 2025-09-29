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
    private let musicService = MusicService.shared
    @State private var showNowPlaying = false
    @State private var showOpenAITest = false
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if musicService.isAuthorized {
                mainContent
            } else {
                NavigationStack {
                    MusicAuthorizationView()
                }
            }

            if musicService.currentlyPlaying != nil {
                NowPlayingView()
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .onAppear {
            checkAuthorizationStatus()
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SessionView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            // OpenAI Test Button (for development)
                            Button(action: { showOpenAITest = true }) {
                                Image(systemName: "bolt.circle")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .sheet(isPresented: $showOpenAITest) {
                        OpenAITestView()
                    }
            }
            .tabItem {
                Label("Session", systemImage: "music.note.list")
            }
            .tag(0)

            NavigationStack {
                PersonasListView()
            }
            .tabItem {
                Label("Personas", systemImage: "person.3.fill")
            }
            .tag(1)
        }
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
