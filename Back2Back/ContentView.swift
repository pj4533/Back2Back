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
    @Environment(\.services) private var services

    @State private var selectedTab = 0

    var body: some View {
        guard let services = services else {
            return AnyView(Text("Loading..."))
        }

        if services.contentViewModel.isAuthorized {
            return AnyView(mainContent
                .toastNotifications())
        } else {
            return AnyView(NavigationStack {
                MusicAuthorizationView()
            }
            .toastNotifications())
        }
    }

    private var mainContent: some View {
        guard let services = services else {
            return AnyView(EmptyView())
        }

        return AnyView(TabView(selection: $selectedTab) {
            NavigationStack {
                SessionView()
            }
            .tabItem {
                Label("Session", systemImage: "music.note.list")
            }
            .tag(0)

            NavigationStack {
                FavoritesListView(viewModel: services.favoritesViewModel)
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
        })
    }
}

#Preview {
    let services = ServiceContainer()
    ContentView()
        .withServices(services)
}
