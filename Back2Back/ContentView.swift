//
//  ContentView.swift
//  Back2Back
//
//  Created by PJ Gray on 9/25/25.
//

import SwiftUI
import MusicKit
import OSLog
import Observation

struct ContentView: View {
    private let dependencies: AppDependencies
    @Bindable private var musicService: MusicService
    @State private var selectedTab = 0

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self._musicService = Bindable(wrappedValue: dependencies.musicService)
    }

    var body: some View {
        if musicService.isAuthorized {
            mainContent
                .toastNotifications(toastService: dependencies.toastService)
        } else {
            NavigationStack {
                MusicAuthorizationView(viewModel: dependencies.musicAuthViewModel)
            }
            .toastNotifications(toastService: dependencies.toastService)
        }
    }

    private var mainContent: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                SessionView(
                    sessionViewModel: dependencies.sessionViewModel,
                    sessionService: dependencies.sessionService,
                    musicService: dependencies.musicService,
                    favoritesService: dependencies.favoritesService,
                    personaService: dependencies.personaService,
                    statusMessageService: dependencies.statusMessageService,
                    makeMusicSearchViewModel: { MusicSearchViewModel(musicService: dependencies.musicService) },
                    makeNowPlayingViewModel: { NowPlayingViewModel(musicService: dependencies.musicService) }
                )
            }
            .tabItem {
                Label("Session", systemImage: "music.note.list")
            }
            .tag(0)

            NavigationStack {
                FavoritesListView(favoritesService: dependencies.favoritesService)
            }
            .tabItem {
                Label("Favorites", systemImage: "heart.fill")
            }
            .tag(1)

            NavigationStack {
                PersonasListView(viewModel: dependencies.personasViewModel)
            }
            .tabItem {
                Label("Personas", systemImage: "person.3.fill")
            }
            .tag(2)

            NavigationStack {
                ConfigurationView(
                    errorService: dependencies.songErrorLoggerService,
                    personaSongCacheService: dependencies.personaSongCacheService
                )
            }
            .tabItem {
                Label("Config", systemImage: "gear")
            }
            .tag(3)
        }
    }
}

#Preview {
    ContentView(dependencies: AppDependencies())
}
