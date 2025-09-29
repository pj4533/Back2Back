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
    @State private var selectedTab = 0

    var body: some View {
        if musicService.isAuthorized {
            mainContent
        } else {
            NavigationStack {
                MusicAuthorizationView()
            }
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SessionView()
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
