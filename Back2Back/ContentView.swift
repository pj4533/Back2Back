//
//  ContentView.swift
//  Back2Back
//
//  Created by PJ Gray on 9/25/25.
//  Refactored to use ViewModel only (Issue #56, 2025-10-18)
//

import SwiftUI
import MusicKit
import OSLog

struct ContentView: View {
    let viewModel: ContentViewModel
    let sessionViewModel: SessionViewModel
    let favoritesViewModel: FavoritesViewModel

    @State private var selectedTab = 0

    var body: some View {
        if viewModel.isAuthorized {
            mainContent
                .toastNotifications()
        } else {
            NavigationStack {
                MusicAuthorizationView()
            }
            .toastNotifications()
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SessionView(viewModel: sessionViewModel)
            }
            .tabItem {
                Label("Session", systemImage: "music.note.list")
            }
            .tag(0)

            NavigationStack {
                FavoritesListView(viewModel: favoritesViewModel)
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(1)

            NavigationStack {
                PersonasListView()
            }
            .tabItem {
                Label("Personas", systemImage: "person.3.fill")
            }
            .tag(2)

            NavigationStack {
                ConfigurationView()
            }
            .tabItem {
                Label("Config", systemImage: "gear")
            }
            .tag(3)
        }
    }
}

#Preview {
    let services = ServiceContainer()
    ContentView(
        viewModel: services.contentViewModel,
        sessionViewModel: services.sessionViewModel,
        favoritesViewModel: services.favoritesViewModel
    )
        .withServices(services)
}
