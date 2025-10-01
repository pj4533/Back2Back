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

            NavigationStack {
                ConfigurationView()
            }
            .tabItem {
                Label("Config", systemImage: "gear")
            }
            .tag(2)
        }
    }
}

#Preview {
    ContentView()
}
